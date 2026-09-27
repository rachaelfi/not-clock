import 'package:not_clock/config/sound_config.dart';

/// Monotonic-ish source of alarm ids.
///
/// The OS scheduler needs a stable integer per alarm, and it has to survive
/// the app being killed — so it lives on the alarm itself and is persisted
/// with it. AlarmScheduler derives its own platform ids from this by
/// multiplying by 10 and adding a slot number, so the value here must stay
/// under 200,000,000 to keep the result inside a 32-bit int.
int _idTieBreaker = 0;

int newAlarmId() {
  // Seconds-since-epoch mod 1,000,000 gives a value that only repeats every
  // ~11.6 days; the two-digit tie-breaker separates alarms created in the
  // same second. Max value is 99,999,999.
  final base = (DateTime.now().millisecondsSinceEpoch ~/ 1000) % 1000000;
  _idTieBreaker = (_idTieBreaker + 1) % 100;
  return base * 100 + _idTieBreaker;
}

class AlarmData {
  /// Stable identity. Used as the key for the OS-level alarm, so editing an
  /// alarm updates the scheduled one instead of leaving an orphan behind.
  int id;

  int hour; // 1-12
  int minute; // 0-59
  bool isAM;
  String label;
  bool enabled;
  List<int> repeatDays; // 0=Sun, 1=Mon, ..., 6=Sat
  String sound;
  String? customSoundPath;
  bool snoozeEnabled;
  int snoozeDurationMinutes;
  bool flashEnabled;

  AlarmData({
    int? id,
    required this.hour,
    required this.minute,
    required this.isAM,
    this.label = 'Alarm',
    this.enabled = true,
    List<int>? repeatDays,
    this.sound = defaultAlarmSound,
    this.customSoundPath,
    this.snoozeEnabled = true,
    this.snoozeDurationMinutes = 9,
    this.flashEnabled = false,
  })  : id = id ?? newAlarmId(),
        repeatDays = repeatDays ?? [];

  String get timeString {
    final m = minute.toString().padLeft(2, '0');
    final period = isAM ? 'AM' : 'PM';
    return '$hour:$m $period';
  }

  String get daysString {
    if (repeatDays.isEmpty) return 'Never';
    if (repeatDays.length == 7) return 'Every day';

    final weekdays = [1, 2, 3, 4, 5];
    final weekend = [0, 6];
    if (repeatDays.length == 5 &&
        weekdays.every((d) => repeatDays.contains(d))) {
      return 'Weekdays';
    }
    if (repeatDays.length == 2 &&
        weekend.every((d) => repeatDays.contains(d))) {
      return 'Weekends';
    }

    const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final sorted = List<int>.from(repeatDays)..sort();
    return sorted.map((d) => dayNames[d]).join(', ');
  }

  int get hour24 {
    int h = hour;
    if (isAM && hour == 12) h = 0;
    if (!isAM && hour != 12) h = hour + 12;
    return h;
  }

  /// The next wall-clock time this alarm should ring, honouring repeat days.
  ///
  /// [from] defaults to now. If [onWeekday] is given (0=Sun … 6=Sat) the
  /// result is the next occurrence on that specific day, which is how the
  /// scheduler lays out one OS alarm per selected day.
  DateTime nextOccurrence({DateTime? from, int? onWeekday}) {
    final now = from ?? DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour24, minute);

    if (onWeekday == null) {
      if (repeatDays.isEmpty) {
        // One-shot: today if it hasn't passed, otherwise tomorrow.
        if (!candidate.isAfter(now)) {
          candidate = candidate.add(const Duration(days: 1));
        }
        return candidate;
      }
      // Repeating with no day pinned: take the soonest selected day.
      final all = repeatDays
          .map((d) => nextOccurrence(from: now, onWeekday: d))
          .toList()
        ..sort();
      return all.first;
    }

    // DateTime.weekday is 1=Mon … 7=Sun; our indices are 0=Sun … 6=Sat.
    final todayIndex = now.weekday == 7 ? 0 : now.weekday;
    var daysAhead = (onWeekday - todayIndex) % 7;
    if (daysAhead < 0) daysAhead += 7;
    candidate = candidate.add(Duration(days: daysAhead));
    // Same weekday but the time already passed today → next week.
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    return candidate;
  }

  Duration timeUntilAlarm() => nextOccurrence().difference(DateTime.now());

  String timeUntilString() {
    final diff = timeUntilAlarm();
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '$m min';
    return '$h h $m min';
  }

  AlarmData copy({bool newIdentity = false}) {
    return AlarmData(
      id: newIdentity ? null : id,
      hour: hour,
      minute: minute,
      isAM: isAM,
      label: label,
      enabled: enabled,
      repeatDays: List<int>.from(repeatDays),
      sound: sound,
      customSoundPath: customSoundPath,
      snoozeEnabled: snoozeEnabled,
      snoozeDurationMinutes: snoozeDurationMinutes,
      flashEnabled: flashEnabled,
    );
  }

  /// Convert alarm to a Map for JSON storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'isAM': isAM,
      'label': label,
      'enabled': enabled,
      'repeatDays': repeatDays,
      'sound': sound,
      'customSoundPath': customSoundPath,
      'snoozeEnabled': snoozeEnabled,
      'snoozeDurationMinutes': snoozeDurationMinutes,
      'flashEnabled': flashEnabled,
    };
  }

  /// Reconstruct an AlarmData from a saved JSON Map.
  /// Uses ?? defaults so old saved data without new fields won't crash.
  factory AlarmData.fromJson(Map<String, dynamic> json) {
    return AlarmData(
      // Alarms saved before ids existed get one assigned on first load; the
      // alarms screen writes the list back out, so it sticks.
      id: json['id'] as int?,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      isAM: json['isAM'] as bool,
      label: json['label'] as String? ?? 'Alarm',
      enabled: json['enabled'] as bool? ?? true,
      repeatDays: (json['repeatDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      // Was 'Radar', which isn't in alarmSounds — an alarm restored from an
      // old save would have shown a sound that couldn't play.
      sound: json['sound'] as String? ?? defaultAlarmSound,
      customSoundPath: json['customSoundPath'] as String?,
      snoozeEnabled: json['snoozeEnabled'] as bool? ?? true,
      snoozeDurationMinutes: json['snoozeDurationMinutes'] as int? ?? 9,
      flashEnabled: json['flashEnabled'] as bool? ?? false,
    );
  }
}

/// Converts a filename like "my_cool_alarm.mp3" into a display name
/// like "My Cool Alarm". Strips the extension and replaces underscores/hyphens.
String soundDisplayName(String filename) {
  final name = filename.replaceAll(
      RegExp(r'\.(mp3|wav|m4a|ogg)$', caseSensitive: false), '');
  final spaced = name.replaceAll(RegExp(r'[_-]'), ' ');
  return spaced.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}