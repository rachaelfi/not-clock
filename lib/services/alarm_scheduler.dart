import 'dart:async';
import 'package:flutter/material.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/services/storage_service.dart';
import 'package:not_clock/services/audio_service.dart';
import 'package:not_clock/screens/alarm_firing_screen.dart';

/// AlarmScheduler runs a background timer that checks every second
/// whether any alarm should fire.
///
/// Behavior:
/// - Sleep alarm has priority over regular alarms at the same time
/// - If a new alarm fires while one is already showing, the old one
///   is auto-dismissed and the new one takes over (iOS Clock behavior)
/// - 3-minute auto-dismiss still applies independently
/// - One-time alarms are disabled after firing
/// - Snooze creates a temporary alarm at current time + snooze duration
/// - If the Night Clock is on screen it handles the sleep alarm itself, so the
///   morning sky isn't hidden behind the firing screen
class AlarmScheduler {
  // Navigator key for pushing firing screen from outside widget tree
  static GlobalKey<NavigatorState>? navigatorKey;

  static Timer? _timer;

  // Track which alarms fired this minute to prevent re-firing
  // Key format: "label_hour24:minute"
  static final Set<String> _firedThisMinute = {};
  static int _lastCheckedMinute = -1;

  // Is the firing screen currently showing?
  static bool _isFiring = false;

  // Callback to dismiss the currently showing firing screen
  static VoidCallback? _currentDismissCallback;

  // Sleep alarm (set by sleep screen, not persisted)
  static AlarmData? _sleepAlarm;

  // Callback to notify sleep screen when its alarm is dismissed
  static VoidCallback? onSleepAlarmDismissed;

  /// Set by the Night Clock while it's on screen.
  ///
  /// When the sleep alarm fires and this is non-null, the scheduler plays the
  /// sound and hands the alarm over instead of pushing [AlarmFiringScreen].
  /// Otherwise the firing screen would cover the sunrise or morning sky the
  /// Night Clock just spent the night building up to — the user would only see
  /// it after dismissing, which defeats the point.
  ///
  /// Regular (non-sleep) alarms still get the firing screen as usual, even
  /// with the Night Clock open.
  static void Function(AlarmData alarm)? nightClockHandler;

  /// Start the scheduler. Call once from main.dart.
  static void start(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _check();
    });
  }

  /// Stop the scheduler
  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Register/unregister the sleep alarm
  static void setSleepAlarm(AlarmData? alarm) {
    _sleepAlarm = alarm;
  }

  /// Dismiss the currently firing alarm to make way for a new one.
  /// Stops sound and pops the firing screen.
  static void _dismissCurrentAlarm() {
    _currentDismissCallback?.call();
    _currentDismissCallback = null;
    _isFiring = false;
  }

  /// Main check loop — runs every second
  static Future<void> _check() async {
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;

    // Clear the "already fired" set when the minute changes
    if (currentMinute != _lastCheckedMinute) {
      _firedThisMinute.clear();
      _lastCheckedMinute = currentMinute;
    }

    // Find which alarm should fire this tick.
    // Sleep alarm has priority — check it first.
    AlarmData? alarmToFire;
    bool isFromSleep = false;

    // Check sleep alarm first (higher priority at same time)
    if (_sleepAlarm != null && _shouldFire(_sleepAlarm!, now)) {
      alarmToFire = _sleepAlarm!;
      isFromSleep = true;
    }

    // Check regular alarms (only if sleep alarm isn't firing)
    if (alarmToFire == null) {
      try {
        final savedAlarms = await StorageService.loadAlarms();
        for (final json in savedAlarms) {
          final alarm = AlarmData.fromJson(json);
          if (_shouldFire(alarm, now)) {
            alarmToFire = alarm;
            isFromSleep = false;
            break; // Take the first matching alarm
          }
        }
      } catch (_) {
        // Storage read failed — skip this check
      }
    }

    // Nothing to fire this tick
    if (alarmToFire == null) return;

    // If another alarm is already showing, dismiss it first.
    // The new alarm takes over — just like iOS Clock behavior.
    if (_isFiring) {
      _dismissCurrentAlarm();
    }

    _fireAlarm(alarmToFire, isFromSleep: isFromSleep);
  }

  /// Determine if an alarm should fire right now
  static bool _shouldFire(AlarmData alarm, DateTime now) {
    if (!alarm.enabled) return false;
    if (alarm.hour24 != now.hour || alarm.minute != now.minute) return false;

    // Already fired this minute?
    final key = '${alarm.label}_${alarm.hour24}:${alarm.minute}';
    if (_firedThisMinute.contains(key)) return false;

    // Check repeat days
    if (alarm.repeatDays.isNotEmpty) {
      final todayIndex = now.weekday == 7 ? 0 : now.weekday;
      if (!alarm.repeatDays.contains(todayIndex)) return false;
    }

    return true;
  }

  /// Fire an alarm — play sound and show the firing screen
  static void _fireAlarm(AlarmData alarm, {required bool isFromSleep}) {
    // Mark as fired so we don't re-fire this minute
    final key = '${alarm.label}_${alarm.hour24}:${alarm.minute}';
    _firedThisMinute.add(key);
    _isFiring = true;

    // ── Night Clock path ──
    // It's already on screen showing the morning sky, so let it present the
    // alarm rather than covering it.
    if (isFromSleep && nightClockHandler != null) {
      if (alarm.sound != 'None') {
        AudioService.playAlarmSound(alarm.sound);
      }
      // A newer alarm taking over just needs the sound stopped — there's no
      // route to pop, since nothing was pushed.
      _currentDismissCallback = AudioService.stop;
      nightClockHandler!(alarm);
      return;
    }

    // Store dismiss callback so a new alarm can auto-dismiss this one
    _currentDismissCallback = () {
      AudioService.stop();
      navigatorKey?.currentState?.pop();
    };

    // Push the firing screen
    final navigator = navigatorKey?.currentState;
    if (navigator == null) return;

    navigator.push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            AlarmFiringScreen(
          alarm: alarm,
          isFromSleep: isFromSleep,
          onDismiss: () => completeDismiss(alarm, isFromSleep: isFromSleep),
          onSnooze: (snoozeDuration) => completeSnooze(
            alarm,
            snoozeDuration,
            isFromSleep: isFromSleep,
          ),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Outcomes ──────────────────────────────────────────────────────────────
  //
  // Public so the Night Clock can report the same outcomes the firing screen
  // does. Neither of these touches the UI — the caller owns its own screen.

  /// The alarm was dismissed. Disables one-time alarms, clears the sleep alarm.
  static void completeDismiss(AlarmData alarm, {required bool isFromSleep}) {
    _isFiring = false;
    _currentDismissCallback = null;

    // Disable one-time alarms after firing
    if (alarm.repeatDays.isEmpty && !isFromSleep) {
      _disableAlarm(alarm);
    }

    // Clear sleep alarm after firing
    if (isFromSleep) {
      _sleepAlarm = null;
      onSleepAlarmDismissed?.call();
      onSleepAlarmDismissed = null;
    }
  }

  /// The alarm was snoozed. Re-arms it [minutes] from now.
  ///
  /// Returns the time it will next fire, which the Night Clock uses to reset
  /// its countdown and run the sunrise again for the snooze window.
  static DateTime completeSnooze(
    AlarmData alarm,
    int minutes, {
    required bool isFromSleep,
  }) {
    _isFiring = false;
    _currentDismissCallback = null;

    // Create a snooze alarm at current time + snooze duration
    final snoozeTime = DateTime.now().add(Duration(minutes: minutes));
    final snoozeAlarm = alarm.copy();
    int h = snoozeTime.hour;
    snoozeAlarm.isAM = h < 12;
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    snoozeAlarm.hour = h;
    snoozeAlarm.minute = snoozeTime.minute;
    snoozeAlarm.label = '${alarm.label} (Snooze)';
    snoozeAlarm.repeatDays = [];
    snoozeAlarm.enabled = true;

    if (isFromSleep) {
      _sleepAlarm = snoozeAlarm;
    } else {
      _saveSnoozeAlarm(snoozeAlarm);
    }

    // Seconds are dropped, matching how _shouldFire compares to the minute.
    return DateTime(
      snoozeTime.year,
      snoozeTime.month,
      snoozeTime.day,
      snoozeTime.hour,
      snoozeTime.minute,
    );
  }

  /// Disable a one-time alarm after it fires
  static Future<void> _disableAlarm(AlarmData alarm) async {
    try {
      final saved = await StorageService.loadAlarms();
      for (int i = 0; i < saved.length; i++) {
        final a = AlarmData.fromJson(saved[i]);
        if (a.hour24 == alarm.hour24 &&
            a.minute == alarm.minute &&
            a.label == alarm.label) {
          a.enabled = false;
          saved[i] = a.toJson();
          break;
        }
      }
      await StorageService.saveAlarms(saved);
    } catch (_) {}
  }

  /// Save a snooze alarm to the existing alarm list
  static Future<void> _saveSnoozeAlarm(AlarmData snooze) async {
    try {
      final saved = await StorageService.loadAlarms();
      saved.add(snooze.toJson());
      await StorageService.saveAlarms(saved);
    } catch (_) {}
  }
}