import 'dart:async';
import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/screens/alarm_firing_screen.dart';
import 'package:not_clock/services/storage_service.dart';

/// Schedules alarms with the operating system so they ring when the app is
/// backgrounded, closed, or the phone is locked.
///
/// The old version ran a `Timer.periodic` inside the app, which only worked
/// while the app was in the foreground. This one hands every alarm to the
/// `alarm` package, which uses AlarmManager plus a foreground service on
/// Android and a keep-alive audio session on iOS.
///
/// ── How ids work ──────────────────────────────────────────────────────────
/// The OS needs one scheduled alarm per ring time, and it has no concept of
/// "repeats on Mon/Wed/Fri". So each [AlarmData] fans out into several
/// platform alarms, all derived from [AlarmData.id]:
///
///   platform id = alarm.id * 10 + slot
///
///     slot 0..6  the next occurrence on that weekday (0=Sun … 6=Sat)
///     slot 7     the single occurrence of a non-repeating alarm
///     slot 8     a snooze
///
/// Dividing a platform id by 10 gets back to the alarm it belongs to.
///
/// ── What the OS knows ─────────────────────────────────────────────────────
/// Everything needed to show the firing screen travels in the alarm's
/// `payload` as JSON. That matters because the alarm may ring after the app
/// has been killed: the payload is all the cold-started app has to go on.
class AlarmScheduler {
  AlarmScheduler._();

  // ── Slots ────────────────────────────────────────────────────────────────
  static const int _slotOnce = 7;
  static const int _slotSnooze = 8;

  /// Reserved id for the sleep alarm. Above the range [newAlarmId] produces
  /// (max 99,999,999) so it can never collide with a user alarm.
  static const int sleepAlarmId = 100000000;

  static const String _kSleepAlarm = 'scheduler_sleep_alarm';

  // ── Wiring set up by the app ─────────────────────────────────────────────

  /// Used to push the firing screen from outside the widget tree.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// When the night clock is open it draws its own wake-up UI, so it takes
  /// over instead of the firing screen being pushed on top of it.
  static void Function(AlarmData alarm)? nightClockHandler;

  /// Lets the sleep screen reset itself once its alarm is done.
  static VoidCallback? onSleepAlarmDismissed;

  /// Notification text. Set these from AppLocalizations in main.dart so the
  /// lock-screen notification matches the app's language — the notification
  /// is built when the alarm is *scheduled*, not when it rings, so changing
  /// the language should call [syncAll] to rewrite them.
  static String notificationTitle = 'Alarm';
  static String notificationStopLabel = 'Stop';
  static String notificationSnoozeLabel = 'Snooze';

  // ── Internal state ───────────────────────────────────────────────────────

  static AlarmData? _sleepAlarm;
  // Deliberately untyped. Depending on the resolved `alarm` version,
  // Alarm.ringing emits either an AlarmSet (a bundle of concurrently ringing
  // alarms) or a bare AlarmSettings, and AlarmSet isn't always exported from
  // the package's top-level library. _onRinging handles both shapes.
  static StreamSubscription<dynamic>? _ringSub;
  static _LifecycleWatcher? _lifecycle;
  static bool _started = false;

  /// The platform id of the alarm ringing right now. [completeDismiss] and
  /// [completeSnooze] use it so callers don't have to thread it through.
  static int? currentRingingOsId;

  static bool _isFiring = false;

  // ── Id helpers ───────────────────────────────────────────────────────────

  static int _osId(int baseId, int slot) => baseId * 10 + slot;
  static int _baseIdOf(int osId) => osId ~/ 10;
  static int _slotOf(int osId) => osId % 10;

  // ─────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  /// Call once from `main()`, before `runApp`.
  ///
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await AlarmScheduler.init(navigatorKey);
  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    navigatorKey = navKey;
    if (_started) return;
    _started = true;

    await Alarm.init();
    await _requestPermissions();

    _sleepAlarm = await _loadSleepAlarm();

    // Fires when an alarm starts ringing — including when the OS cold-started
    // the app to deliver it.
    _ringSub = Alarm.ringing.listen(_onRinging);

    // Re-sync whenever the app comes back to the foreground: the user may
    // have dismissed an alarm from the notification, or the device may have
    // rebooted and dropped a stale alarm.
    _lifecycle = _LifecycleWatcher(onResume: syncAll);
    WidgetsBinding.instance.addObserver(_lifecycle!);

    await syncAll();
  }

  static Future<void> dispose() async {
    await _ringSub?.cancel();
    _ringSub = null;
    if (_lifecycle != null) {
      WidgetsBinding.instance.removeObserver(_lifecycle!);
      _lifecycle = null;
    }
    _started = false;
  }

  /// Notification permission is required on Android 13+ and iOS; exact-alarm
  /// permission on Android 12+. Without them alarms are silently downgraded
  /// to inexact, which can drift by minutes.
  static Future<void> _requestPermissions() async {
    try {
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (Alarm.android && await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    } catch (_) {
      // Permission plugin unavailable (web, tests) — scheduling still runs.
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Scheduling
  // ─────────────────────────────────────────────────────────────────────────

  /// Rebuild the OS schedule from saved alarms plus the sleep alarm.
  ///
  /// Safe to call often — it diffs against what's already scheduled and only
  /// touches what changed. In-flight snoozes are left alone.
  static Future<void> syncAll() async {
    final now = DateTime.now();

    // 1. What *should* be scheduled.
    final desired = <int, _Planned>{};

    for (final json in await _safeLoadAlarms()) {
      final alarm = AlarmData.fromJson(json);
      _planFor(alarm, isFromSleep: false, now: now, into: desired);
    }
    final sleep = _sleepAlarm;
    if (sleep != null) {
      _planFor(sleep, isFromSleep: true, now: now, into: desired);
    }

    // 2. What *is* scheduled.
    final existing = await Alarm.getAlarms();

    for (final current in existing) {
      final want = desired[current.id];

      // A live snooze is never in `desired`. Keep it.
      if (_slotOf(current.id) == _slotSnooze && current.dateTime.isAfter(now)) {
        continue;
      }

      if (want == null) {
        await Alarm.stop(current.id);
        continue;
      }

      // Already correct — leave it be.
      if (current.dateTime == want.at) {
        desired.remove(current.id);
        continue;
      }

      // Scheduled earlier than planned and still in the future: the platform
      // moved it (the user hit Snooze on the Android notification). Respect
      // that rather than yanking it back to the original time.
      if (current.dateTime.isAfter(now) && current.dateTime.isBefore(want.at)) {
        desired.remove(current.id);
        continue;
      }

      await Alarm.stop(current.id);
    }

    // 3. Set whatever is left.
    for (final entry in desired.entries) {
      await _set(entry.key, entry.value);
    }
  }

  /// Schedule (or reschedule) one alarm without touching the others.
  static Future<void> scheduleAlarm(AlarmData alarm,
      {bool isFromSleep = false}) async {
    await cancelAlarm(alarm, keepSnooze: false);
    if (!alarm.enabled) return;

    final plan = <int, _Planned>{};
    _planFor(alarm, isFromSleep: isFromSleep, now: DateTime.now(), into: plan);
    for (final entry in plan.entries) {
      await _set(entry.key, entry.value);
    }
  }

  /// Remove every OS alarm belonging to [alarm].
  static Future<void> cancelAlarm(AlarmData alarm,
      {bool keepSnooze = false}) async {
    for (int slot = 0; slot <= _slotSnooze; slot++) {
      if (keepSnooze && slot == _slotSnooze) continue;
      await Alarm.stop(_osId(alarm.id, slot));
    }
  }

  /// Set, replace, or clear the sleep alarm. Pass null to clear it.
  static Future<void> setSleepAlarm(AlarmData? alarm) async {
    final previous = _sleepAlarm;
    if (previous != null) {
      await cancelAlarm(previous);
    }

    if (alarm == null) {
      _sleepAlarm = null;
      await _saveSleepAlarm(null);
      return;
    }

    // Force the reserved id so the sleep alarm always owns the same slots,
    // no matter which AlarmData instance the sleep screen hands us.
    alarm.id = sleepAlarmId;
    _sleepAlarm = alarm;
    await _saveSleepAlarm(alarm);
    await scheduleAlarm(alarm, isFromSleep: true);
  }

  static AlarmData? get sleepAlarm => _sleepAlarm;

  /// Work out every platform alarm [alarm] needs and add them to [into].
  static void _planFor(
    AlarmData alarm, {
    required bool isFromSleep,
    required DateTime now,
    required Map<int, _Planned> into,
  }) {
    if (!alarm.enabled) return;

    if (alarm.repeatDays.isEmpty) {
      into[_osId(alarm.id, _slotOnce)] = _Planned(
        at: alarm.nextOccurrence(from: now),
        alarm: alarm,
        isFromSleep: isFromSleep,
      );
      return;
    }

    for (final day in alarm.repeatDays) {
      if (day < 0 || day > 6) continue;
      into[_osId(alarm.id, day)] = _Planned(
        at: alarm.nextOccurrence(from: now, onWeekday: day),
        alarm: alarm,
        isFromSleep: isFromSleep,
      );
    }
  }

  static Future<void> _set(int osId, _Planned plan) async {
    final alarm = plan.alarm;

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: osId,
        dateTime: plan.at,
        assetAudioPath: _assetPathFor(alarm),
        loopAudio: true,
        vibrate: true,
        // Android: draw over the lock screen with the full firing UI.
        androidFullScreenIntent: true,
        // iOS: warn the user if they swipe the app away, because a killed
        // app can miss its alarm.
        warningNotificationOnKill: Alarm.iOS,
        androidStopAlarmOnTermination: false,
        // The notification's Snooze button is Android-only in this package.
        androidSnoozeDuration: alarm.snoozeEnabled
            ? Duration(minutes: alarm.snoozeDurationMinutes)
            : null,
        // Don't ring an alarm the phone was off for; the user woke up hours
        // ago. Boot-restored alarms older than this are dropped.
        androidStaleAfter: const Duration(minutes: 30),
        // Not const: VolumeSettings' assert doesn't evaluate in a constant
        // expression, so the analyzer rejects a const invocation here.
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 8),
          volumeEnforced: false,
        ),
        notificationSettings: NotificationSettings(
          title: notificationTitle,
          body: alarm.label,
          stopButton: notificationStopLabel,
          androidSnoozeButton:
              alarm.snoozeEnabled ? notificationSnoozeLabel : null,
          // Swiping the notification away should not silence the alarm —
          // the user has to make a deliberate choice.
          androidStopAlarmOnDismiss: false,
        ),
        payload: jsonEncode({
          'alarm': alarm.toJson(),
          'sleep': plan.isFromSleep,
        }),
      ),
    );
  }

  /// Where the alarm's audio lives. A null path means the platform rings with
  /// vibration and the notification only, which is what "None" should do.
  static String? _assetPathFor(AlarmData alarm) {
    final custom = alarm.customSoundPath;
    if (custom != null && custom.isNotEmpty) return custom;
    if (alarm.sound.isEmpty || alarm.sound == 'None') return null;
    return 'assets/sounds/alarms/${alarm.sound}';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Ringing
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _onRinging(dynamic event) async {
    final ringing = _unwrap(event);

    if (ringing.isEmpty) {
      _isFiring = false;
      currentRingingOsId = null;
      return;
    }
    if (_isFiring) return;

    final settings = ringing.first;
    final decoded = await _decode(settings);
    if (decoded == null) return;

    _isFiring = true;
    currentRingingOsId = settings.id;

    final alarm = decoded.alarm;
    final isFromSleep = decoded.isFromSleep;

    // The night clock is already showing a full-screen wake-up view; let it
    // handle the alarm rather than stacking the firing screen over its sky.
    final handler = nightClockHandler;
    if (isFromSleep && handler != null) {
      handler(alarm);
      return;
    }

    // On a cold start — the phone booting the app *because* an alarm is
    // ringing — init() subscribes before runApp, and Alarm.ringing replays
    // the current alarm immediately. There's no widget tree yet, and no
    // second emission coming, so bailing here would leave the alarm ringing
    // with no UI. Wait for the navigator instead.
    final navigator = await _awaitNavigator();
    if (navigator == null) {
      _isFiring = false;
      return;
    }

    await navigator.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => AlarmFiringScreen(
          alarm: alarm,
          isFromSleep: isFromSleep,
          onDismiss: () => completeDismiss(alarm, isFromSleep: isFromSleep),
          onSnooze: (minutes) =>
              completeSnooze(alarm, minutes, isFromSleep: isFromSleep),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    _isFiring = false;
  }

  /// Poll for the navigator until the widget tree exists.
  ///
  /// Gives up after ~10 seconds. If it does, the platform is still ringing
  /// and the notification is on screen, so the user can stop or snooze from
  /// there — they just don't get the in-app screen.
  static Future<NavigatorState?> _awaitNavigator() async {
    for (int i = 0; i < 100; i++) {
      final navigator = navigatorKey?.currentState;
      if (navigator != null) return navigator;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  /// Normalise whatever `Alarm.ringing` emitted into a list of AlarmSettings.
  ///
  /// Newer versions of the package emit an `AlarmSet` holding every alarm
  /// ringing at once; older ones emit a single `AlarmSettings`.
  static List<AlarmSettings> _unwrap(dynamic event) {
    if (event == null) return const [];
    if (event is AlarmSettings) return [event];
    if (event is List) return event.cast<AlarmSettings>();
    try {
      return (event.alarms as List).cast<AlarmSettings>();
    } catch (_) {
      return const [];
    }
  }

  /// Rebuild the alarm from the platform payload, falling back to storage.
  static Future<_Decoded?> _decode(AlarmSettings settings) async {
    final payload = settings.payload;
    if (payload != null && payload.isNotEmpty) {
      try {
        final map = jsonDecode(payload) as Map<String, dynamic>;
        return _Decoded(
          alarm: AlarmData.fromJson(map['alarm'] as Map<String, dynamic>),
          isFromSleep: map['sleep'] == true,
        );
      } catch (_) {
        // Fall through to the storage lookup.
      }
    }

    final baseId = _baseIdOf(settings.id);
    if (baseId == sleepAlarmId) {
      final sleep = _sleepAlarm ?? await _loadSleepAlarm();
      if (sleep != null) return _Decoded(alarm: sleep, isFromSleep: true);
    }
    for (final json in await _safeLoadAlarms()) {
      final alarm = AlarmData.fromJson(json);
      if (alarm.id == baseId) {
        return _Decoded(alarm: alarm, isFromSleep: false);
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Dismiss / snooze
  // ─────────────────────────────────────────────────────────────────────────

  /// Stop the ringing alarm for good.
  ///
  /// A one-shot alarm is switched off, a repeating one is rescheduled for its
  /// next occurrence, and the sleep alarm is cleared.
  static Future<void> completeDismiss(AlarmData alarm,
      {required bool isFromSleep}) async {
    final osId = currentRingingOsId;
    currentRingingOsId = null;
    _isFiring = false;

    if (osId != null) await Alarm.stop(osId);
    // Kill any snooze left over from an earlier press in the same wake-up.
    await Alarm.stop(_osId(alarm.id, _slotSnooze));

    if (isFromSleep) {
      _sleepAlarm = null;
      await _saveSleepAlarm(null);
      await cancelAlarm(alarm);
      onSleepAlarmDismissed?.call();
      onSleepAlarmDismissed = null;
      return;
    }

    if (alarm.repeatDays.isEmpty) {
      alarm.enabled = false;
      await _persistAlarm(alarm);
      await cancelAlarm(alarm);
    } else {
      // Re-lay the weekday slots so the one that just rang points at next week.
      await scheduleAlarm(alarm);
    }
  }

  /// Stop ringing and set the alarm to go off again in [minutes].
  ///
  /// Returns the time it will ring, so the night clock can show a countdown.
  static Future<DateTime> completeSnooze(AlarmData alarm, int minutes,
      {required bool isFromSleep}) async {
    final osId = currentRingingOsId;
    currentRingingOsId = null;
    _isFiring = false;

    if (osId != null) await Alarm.stop(osId);

    final at = DateTime.now().add(Duration(minutes: minutes));
    await _set(
      _osId(alarm.id, _slotSnooze),
      _Planned(at: at, alarm: alarm, isFromSleep: isFromSleep),
    );
    return at;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Storage
  // ─────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _safeLoadAlarms() async {
    try {
      return await StorageService.loadAlarms();
    } catch (_) {
      return [];
    }
  }

  /// Write [alarm] back into the saved list, matching on id.
  static Future<void> _persistAlarm(AlarmData alarm) async {
    try {
      final saved = await StorageService.loadAlarms();
      for (int i = 0; i < saved.length; i++) {
        if ((saved[i]['id'] as int?) == alarm.id) {
          saved[i] = alarm.toJson();
          await StorageService.saveAlarms(saved);
          return;
        }
      }
    } catch (_) {}
  }

  static Future<void> _saveSleepAlarm(AlarmData? alarm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (alarm == null) {
        await prefs.remove(_kSleepAlarm);
      } else {
        await prefs.setString(_kSleepAlarm, jsonEncode(alarm.toJson()));
      }
    } catch (_) {}
  }

  static Future<AlarmData?> _loadSleepAlarm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSleepAlarm);
      if (raw == null) return null;
      final alarm = AlarmData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      alarm.id = sleepAlarmId;
      return alarm;
    } catch (_) {
      return null;
    }
  }
}

class _Planned {
  final DateTime at;
  final AlarmData alarm;
  final bool isFromSleep;
  const _Planned({
    required this.at,
    required this.alarm,
    required this.isFromSleep,
  });
}

class _Decoded {
  final AlarmData alarm;
  final bool isFromSleep;
  const _Decoded({required this.alarm, required this.isFromSleep});
}

class _LifecycleWatcher with WidgetsBindingObserver {
  final Future<void> Function() onResume;
  _LifecycleWatcher({required this.onResume});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}