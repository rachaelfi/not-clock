import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_alarmkit/flutter_alarmkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:not_clock/config/app_config.dart';
import 'package:not_clock/models/alarm_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AlarmKit backend — iOS 26+ only.
//
//  Apple's AlarmKit is the only way a third-party app gets Stop and Snooze
//  buttons sitting on the lock screen without the user having to long-press
//  a notification to find them. The system owns the alarm, so it also rings
//  through Do Not Disturb and survives the app being force-quit — both things
//  the `alarm` package can't promise on iOS.
//
//  Everything below is a no-op unless this is iOS 26 or newer AND the user has
//  granted alarm authorization. AlarmScheduler checks [available] and falls
//  back to the `alarm` package otherwise, so older iPhones and all Android
//  devices keep working exactly as before.
//
//  ── Two things AlarmKit makes awkward ──────────────────────────────────────
//
//  1. Its ids are opaque UUID strings it hands back, and AlarmMetadata only
//     carries display fields — there's nowhere to stash our own id. So we keep
//     a map from our integer ids to AlarmKit's strings, persisted, because it
//     has to survive the app being killed.
//
//  2. scheduleOneShotAlarm and scheduleRecurrentAlarm don't expose AlarmKit's
//     `postAlert` duration, which is what puts the Snooze button on the alert.
//     Until the plugin exposes it we get Stop only; snooze still works from
//     the in-app firing screen. See the note on [snoozeSupported].
// ─────────────────────────────────────────────────────────────────────────────

class AlarmKitBackend {
  AlarmKitBackend._();

  static final _plugin = FlutterAlarmkit();

  /// AlarmKit landed in iOS 26. Below that every call throws
  /// `UNSUPPORTED_VERSION`.
  static const int _minimumIosMajor = 26;

  static const String _kIdMap = 'alarmkit_id_map';

  static bool _supported = false;
  static bool _authorized = false;
  static bool _initialised = false;

  /// True when alarms should be scheduled through AlarmKit rather than the
  /// `alarm` package.
  static bool get available => _supported && _authorized;

  /// Whether the lock-screen alert can show a Snooze button.
  ///
  /// False today: the plugin doesn't expose AlarmKit's `postAlert` duration on
  /// its scheduling methods. Flip this once that lands (or once we're on a
  /// fork that adds it) and pass the duration in [_uiConfig].
  static bool get snoozeSupported => false;

  /// Our alarm id → AlarmKit's UUID string.
  static final Map<int, String> _idMap = {};

  /// Called when an AlarmKit alarm starts alerting, with our own alarm id.
  /// AlarmScheduler uses this to raise the in-app firing screen on top of the
  /// system alert, so the experience matches the Android path.
  static void Function(int alarmId)? onAlerting;

  /// Called when an alerting alarm stops, by any route — the system Stop
  /// button, the in-app screen, or the alert timing out.
  static void Function(int alarmId)? onStopped;

  static StreamSubscription<AlarmUpdateEvent>? _updates;

  /// Ids currently alerting, so [onStopped] fires exactly once.
  static final Set<int> _alerting = {};

  // ───────────────────────────────────────────────────────────────────────────
  //  Setup
  // ───────────────────────────────────────────────────────────────────────────

  /// Work out whether AlarmKit is usable. Safe to call on any platform.
  ///
  /// Deliberately does NOT prompt for authorization — that would put a system
  /// permission dialog in front of the user on first launch, before they've
  /// done anything that explains why. [ensureAuthorized] handles that at the
  /// moment they first set an alarm.
  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    _supported = await _checkPlatform();
    if (!_supported) return;

    await _loadIdMap();

    // Already granted from a previous launch? Then we're live without asking.
    try {
      _authorized = await _plugin.requestAuthorization();
    } catch (e) {
      debugPrint('AlarmKit: authorization check failed — $e');
      _authorized = false;
    }

    _updates = _plugin.alarmUpdates().listen(_onUpdate, onError: (Object e) {
      debugPrint('AlarmKit: update stream error — $e');
    });
  }

  static Future<bool> _checkPlatform() async {
    if (kIsWeb || !AppConfig.isIOS) return false;
    try {
      final info = await DeviceInfoPlugin().iosInfo;
      // systemVersion looks like "26.6.1"; we only care about the major.
      final major = int.tryParse(info.systemVersion.split('.').first) ?? 0;
      return major >= _minimumIosMajor;
    } catch (e) {
      debugPrint('AlarmKit: could not read iOS version — $e');
      return false;
    }
  }

  /// Prompt for alarm authorization if we haven't got it yet.
  ///
  /// Call this the first time the user sets an alarm, not at startup — the
  /// prompt makes sense in that context and not before.
  static Future<bool> ensureAuthorized() async {
    if (!_supported) return false;
    if (_authorized) return true;
    try {
      _authorized = await _plugin.requestAuthorization();
    } catch (e) {
      debugPrint('AlarmKit: authorization request failed — $e');
      _authorized = false;
    }
    return _authorized;
  }

  static Future<void> dispose() async {
    await _updates?.cancel();
    _updates = null;
    _initialised = false;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Scheduling
  // ───────────────────────────────────────────────────────────────────────────

  /// Hand [alarm] to AlarmKit, replacing any alarm already scheduled under the
  /// same id.
  ///
  /// Unlike the `alarm` package, AlarmKit understands weekly repeats natively,
  /// so a repeating alarm is one AlarmKit alarm rather than one per weekday.
  static Future<bool> schedule(AlarmData alarm) async {
    if (!available) return false;

    await cancel(alarm.id);

    try {
      final String akId;

      if (alarm.repeatDays.isEmpty) {
        akId = await _plugin.scheduleOneShotAlarm(
          timestamp:
              alarm.nextOccurrence().millisecondsSinceEpoch.toDouble(),
          label: alarm.label,
          soundPath: _soundPath(alarm),
          uiConfig: _uiConfig(),
        );
      } else {
        akId = await _plugin.scheduleRecurrentAlarm(
          weekdays: alarm.repeatDays.map(_weekdayFor).toSet(),
          hour: alarm.hour24,
          minute: alarm.minute,
          label: alarm.label,
          soundPath: _soundPath(alarm),
          uiConfig: _uiConfig(),
        );
      }

      _idMap[alarm.id] = akId;
      await _saveIdMap();
      return true;
    } catch (e) {
      debugPrint('AlarmKit: schedule failed for ${alarm.id} — $e');
      return false;
    }
  }

  /// Remove the alarm entirely — it will not ring.
  static Future<void> cancel(int alarmId) async {
    final akId = _idMap.remove(alarmId);
    if (akId == null) return;
    await _saveIdMap();
    try {
      await _plugin.cancelAlarm(alarmId: akId);
    } catch (e) {
      debugPrint('AlarmKit: cancel failed for $alarmId — $e');
    }
  }

  /// Silence an alarm that is ringing right now, leaving the schedule intact
  /// for a repeating alarm.
  static Future<void> stop(int alarmId) async {
    final akId = _idMap[alarmId];
    if (akId == null) return;
    try {
      await _plugin.stopAlarm(alarmId: akId);
    } catch (e) {
      debugPrint('AlarmKit: stop failed for $alarmId — $e');
    }
  }

  /// Everything we've scheduled, cleared. Used when rebuilding the schedule
  /// from scratch.
  static Future<void> cancelAll() async {
    if (!_supported) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('AlarmKit: cancelAll failed — $e');
    }
    _idMap.clear();
    await _saveIdMap();
  }

  static bool isScheduled(int alarmId) => _idMap.containsKey(alarmId);

  // ───────────────────────────────────────────────────────────────────────────
  //  Events
  // ───────────────────────────────────────────────────────────────────────────

  static void _onUpdate(AlarmUpdateEvent event) {
    final ourId = _ourIdFor(event.alarmId);
    if (ourId == null) return;

    final state = event.alarm?.state;
    debugPrint('### alarmkit: ${event.kind} id=$ourId state=$state');

    if (state == AlarmState.alerting) {
      if (_alerting.add(ourId)) onAlerting?.call(ourId);
      return;
    }

    // Anything else — stopped, removed, back to scheduled — ends the ring.
    if (_alerting.remove(ourId)) onStopped?.call(ourId);
  }

  static int? _ourIdFor(String akId) {
    for (final entry in _idMap.entries) {
      if (entry.value == akId) return entry.key;
    }
    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Helpers
  // ───────────────────────────────────────────────────────────────────────────

  /// AlarmKit only accepts `.caf`, `.aiff` or `.wav` under 30 seconds, so it
  /// reads from the converted folder rather than the MP3s the rest of the app
  /// uses. Same basename, so there's still one list of sounds.
  static String? _soundPath(AlarmData alarm) {
    final sound = alarm.sound;
    if (sound.isEmpty || sound == 'None') return null;
    final base = sound.replaceAll(RegExp(r'\.\w+$'), '');
    return 'assets/sounds/alarms_caf/$base.caf';
  }

  static AlarmUIConfig _uiConfig() {
    // Labels come from AlarmScheduler so they're already translated.
    return AlarmUIConfig(
      stopButton: AlarmButtonConfig(
        text: stopLabel,
        icon: 'stop.circle',
      ),
    );
  }

  /// Set from AlarmScheduler, which reads them from AppLocalizations.
  static String stopLabel = 'Stop';
  static String snoozeLabel = 'Snooze';

  /// Our repeat indices are 0=Sun … 6=Sat.
  static Weekday _weekdayFor(int index) {
    switch (index) {
      case 0:
        return Weekday.sunday;
      case 1:
        return Weekday.monday;
      case 2:
        return Weekday.tuesday;
      case 3:
        return Weekday.wednesday;
      case 4:
        return Weekday.thursday;
      case 5:
        return Weekday.friday;
      default:
        return Weekday.saturday;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Id map persistence
  // ───────────────────────────────────────────────────────────────────────────

  static Future<void> _loadIdMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kIdMap);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _idMap
        ..clear()
        ..addAll(decoded.map((k, v) => MapEntry(int.parse(k), v as String)));
    } catch (e) {
      debugPrint('AlarmKit: could not load id map — $e');
    }
  }

  static Future<void> _saveIdMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kIdMap,
        jsonEncode(_idMap.map((k, v) => MapEntry(k.toString(), v))),
      );
    } catch (e) {
      debugPrint('AlarmKit: could not save id map — $e');
    }
  }
}