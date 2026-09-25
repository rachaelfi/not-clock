import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/main.dart';

class RepeatDayPicker extends StatefulWidget {
  final List<int> selectedDays;

  const RepeatDayPicker({super.key, required this.selectedDays});

  @override
  State<RepeatDayPicker> createState() => _RepeatDayPickerState();
}

class _RepeatDayPickerState extends State<RepeatDayPicker> {
  late List<int> _selected;

  /// Weekday names come from DateFormat rather than a hardcoded list, so they
  /// arrive already translated and capitalised the way each language does it —
  /// "Monday" in English, "lunes" in Spanish, "Montag" in German.
  ///
  /// The rows show the bare day name under a "Repeat every" header instead of
  /// "Every Monday" per row. Gluing "Every" onto a weekday needs the right
  /// article and gender in most of these languages — "Todos los domingos" but
  /// "Toda segunda-feira" — and a header sidesteps that entirely.
  ///
  /// 7 January 2024 was a Sunday, which matches index 0 in `repeatDays`.
  String _dayName(int index, String locale) {
    final day = DateTime(2024, 1, 7 + index);
    return DateFormat.EEEE(locale).format(day);
  }

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _selected),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios, color: c.accentSoft, size: 20),
          ),
        ),
        title: Text(t.repeat,
            style: TextStyle(
                color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(t.repeatEvery,
                style: TextStyle(
                  color: c.subtext,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                )),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 7,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Divider(color: c.divider, height: 1),
              ),
              itemBuilder: (context, index) {
                final isSelected = _selected.contains(index);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selected.remove(index);
                      } else {
                        _selected.add(index);
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(_dayName(index, locale),
                              style: TextStyle(color: c.text, fontSize: 16)),
                        ),
                        if (isSelected)
                          Icon(Icons.check, color: c.accent, size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}