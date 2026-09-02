import 'package:flutter/material.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context, _selected),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios, color: Color(0xFFA29BFE), size: 20),
          ),
        ),
        title: const Text('Repeat',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF12121A),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 7,
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(color: Color(0xFF1E1E2E), height: 1),
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
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    if (isSelected)
                      const Icon(Icons.check, color: Color(0xFF6C5CE7), size: 20),
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