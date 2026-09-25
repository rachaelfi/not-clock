import 'package:flutter/material.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/screens/alarm_edit_screen.dart';
import 'package:not_clock/services/storage_service.dart';
import 'package:not_clock/theme/app_theme.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  // Start with empty list — will be populated from disk in initState
  final List<AlarmData> _alarms = [];

  @override
  void initState() {
    super.initState();
    // Load saved alarms when screen is first created
    _loadAlarms();
  }

  /// Load alarms from disk. Each alarm was saved as a JSON map.
  Future<void> _loadAlarms() async {
    final saved = await StorageService.loadAlarms();
    if (saved.isNotEmpty) {
      setState(() {
        _alarms.addAll(saved.map((json) => AlarmData.fromJson(json)));
      });
    }
  }

  /// Save the current alarm list to disk.
  /// Called after every add, edit, delete, or toggle.
  Future<void> _saveAlarms() async {
    await StorageService.saveAlarms(
      _alarms.map((a) => a.toJson()).toList(),
    );
  }

  void _showTimeUntilSnackbar(AlarmData alarm) {
    final c = SettingsProvider.read(context).colors;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.alarm_on, color: c.accentSoft, size: 20),
            const SizedBox(width: 12),
            Text(
              // NOTE: timeUntilString() still builds an English string inside
              // AlarmData. See the note at the bottom of this file.
              t.alarmIn(alarm.timeUntilString()),
              style: TextStyle(color: c.text, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: c.card,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _sortAlarms() {
    _alarms.sort((a, b) => a.hour24 * 60 + a.minute - (b.hour24 * 60 + b.minute));
  }

  void _addAlarm() async {
    final newAlarm = AlarmData(
      hour: 7,
      minute: 0,
      isAM: true,
      label: AppLocalizations.of(context).alarmDefaultLabel,
      enabled: true,
    );

    final result = await Navigator.push<AlarmData>(
      context,
      _buildSlideRoute<AlarmData>(AlarmEditScreen(alarm: newAlarm, isNew: true)),
    );

    if (result != null) {
      setState(() {
        _alarms.add(result);
        _sortAlarms();
      });
      _saveAlarms(); // Persist to disk
      if (mounted) _showTimeUntilSnackbar(result);
    }
  }

  void _editAlarm(int index) async {
    final alarm = _alarms[index];
    final result = await Navigator.push<dynamic>(
      context,
      _buildSlideRoute(AlarmEditScreen(alarm: alarm.copy(), isNew: false)),
    );

    if (result == null) return;

    setState(() {
      if (result == 'delete') {
        _alarms.removeAt(index);
      } else if (result is AlarmData) {
        _alarms[index] = result;
        _sortAlarms();
      }
    });
    _saveAlarms(); // Persist to disk
  }

  PageRouteBuilder<T> _buildSlideRoute<T>(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    final c = settings.colors;
    final t = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.alarmsTitle,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _addAlarm,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.accentWash(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.add, color: c.accentSoft, size: 24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const SettingsGearButton(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _alarms.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.alarm_off, size: 64, color: c.muted),
                          const SizedBox(height: 16),
                          Text(
                            t.noAlarms,
                            style: TextStyle(color: c.subtext, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _alarms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final alarm = _alarms[index];
                        return GestureDetector(
                          onTap: () => _editAlarm(index),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.divider, width: 1),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        settings.formatTime(
                                            alarm.hour24, alarm.minute),
                                        style: TextStyle(
                                          color: alarm.enabled
                                              ? c.text
                                              : c.muted,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${alarm.label}  ·  ${alarm.daysString}',
                                        style: TextStyle(
                                          color: alarm.enabled
                                              ? c.subtext
                                              : c.muted,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Colors come from ThemeData.switchTheme, set in
                                // AppPalette.materialTheme.
                                Switch(
                                  value: alarm.enabled,
                                  onChanged: (val) {
                                    setState(() {
                                      alarm.enabled = val;
                                    });
                                    _saveAlarms(); // Persist toggle state
                                    if (val) {
                                      _showTimeUntilSnackbar(alarm);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Still English: AlarmData.daysString and AlarmData.timeUntilString
//
//  Both build sentences inside the model — "Mon, Wed, Fri", "Every day",
//  "2 hours 15 minutes" — so they can't see AppLocalizations and stay English
//  in Spanish. Fixing that means moving the formatting out of AlarmData into a
//  helper that takes AppLocalizations, since a model shouldn't need a
//  BuildContext. Worth doing, but it's its own change.
// ─────────────────────────────────────────────────────────────────────────────