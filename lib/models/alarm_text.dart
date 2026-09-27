import 'package:intl/intl.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/models/alarm_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Translated labels for alarm data.
//
//  These live outside AlarmData on purpose. A model shouldn't need a
//  BuildContext, so AlarmData.daysString and timeUntilString can't reach
//  AppLocalizations and stay English in every language. Anything user-facing
//  should come through here instead.
// ─────────────────────────────────────────────────────────────────────────────

/// Abbreviated weekday name — "Mon", "lun.", "Mo.".
///
/// From intl rather than a hardcoded list, so there are no seven-name arrays
/// to translate and maintain per language. 7 January 2024 was a Sunday, which
/// matches index 0 in [AlarmData.repeatDays].
String shortDayName(int index, String locale) =>
    DateFormat.E(locale).format(DateTime(2024, 1, 7 + index));

/// "Never", "Every day", "Weekdays", "Weekends", or "Mon, Wed, Fri".
String repeatDaysLabel(
  List<int> repeatDays,
  AppLocalizations t,
  String locale,
) {
  if (repeatDays.isEmpty) return t.never;
  if (repeatDays.length == 7) return t.everyDay;

  const weekdayIndices = [1, 2, 3, 4, 5];
  const weekendIndices = [0, 6];

  if (repeatDays.length == 5 &&
      weekdayIndices.every((d) => repeatDays.contains(d))) {
    return t.weekdays;
  }
  if (repeatDays.length == 2 &&
      weekendIndices.every((d) => repeatDays.contains(d))) {
    return t.weekends;
  }

  final sorted = List<int>.from(repeatDays)..sort();
  return sorted.map((d) => shortDayName(d, locale)).join(', ');
}

/// How long until the alarm goes off — "2 h 15 min", or "45 min" under an hour.
String timeUntilLabel(AlarmData alarm, AppLocalizations t) {
  final d = alarm.timeUntilAlarm();
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours == 0) return t.minutesShort(minutes);
  return t.hoursMinutes(hours, minutes);
}