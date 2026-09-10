import 'package:flutter/material.dart';
import 'package:not_clock/main.dart';

class RepeatDayPicker extends StatefulWidget {
  final List<int> selectedDays;

  const RepeatDayPicker({super.key, required this.selectedDays});

  @override
  State<RepeatDayPicker> createState() => _RepeatDayPickerState();
}

class _RepeatDayPickerState extends State<RepeatDayPicker> {
  late List<int> _selected;

  static const _dayNames = [
    'Every Sunday',
    'Every Monday',
    'Every Tuesday',
    'Every Wednesday',
    'Every Thursday',
    'Every Friday',
    'Every Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedDays);
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;

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
        title: Text('Repeat',
            style: TextStyle(
                color: c.text, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dayNames[index],
                        style: TextStyle(color: c.text, fontSize: 16)),
                    if (isSelected)
                      Icon(Icons.check, color: c.accent, size: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}