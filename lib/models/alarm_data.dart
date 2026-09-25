import 'package:not_clock/config/sound_config.dart';
class AlarmData {
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
  }) : repeatDays = repeatDays ?? [];

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

  Duration timeUntilAlarm() {
    final now = DateTime.now();
    var alarmTime =
        DateTime(now.year, now.month, now.day, hour24, minute);
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }
    return alarmTime.difference(now);
  }

  String timeUntilString() {
    final diff = timeUntilAlarm();
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '${m} min';
    return '$h h $m min';
  }

  AlarmData copy() {
    return AlarmData(
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
  /// Every field is stored so we can fully reconstruct the alarm.
  Map<String, dynamic> toJson() {
    return {
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
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      isAM: json['isAM'] as bool,
      label: json['label'] as String? ?? 'Alarm',
      enabled: json['enabled'] as bool? ?? true,
      repeatDays: (json['repeatDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      sound: json['sound'] as String? ?? 'Radar',
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
  // Remove extension
  final name = filename.replaceAll(RegExp(r'\.(mp3|wav|m4a|ogg)$', caseSensitive: false), '');
  // Replace underscores and hyphens with spaces
  final spaced = name.replaceAll(RegExp(r'[_-]'), ' ');
  // Capitalize each word
  return spaced.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}
