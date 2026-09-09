import 'package:flutter/material.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/screens/alarm_sub/repeat_day_picker.dart';
import 'package:not_clock/screens/alarm_sub/sound_picker.dart';

class AlarmEditScreen extends StatefulWidget {
  final AlarmData alarm;
  final bool isNew;

  const AlarmEditScreen({super.key, required this.alarm, required this.isNew});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late AlarmData _alarm;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _alarm = widget.alarm;
    _hourController = FixedExtentScrollController(initialItem: _alarm.hour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _alarm.minute);
    _amPmController = FixedExtentScrollController(initialItem: _alarm.isAM ? 0 : 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controllersInitialized) {
      _controllersInitialized = true;
      final settings = SettingsProvider.of(context);
      if (settings.use24HourFormat) {
        _hourController.dispose();
        _hourController = FixedExtentScrollController(initialItem: _alarm.hour24);
      }
    }
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _alarm);
  void _cancel() => Navigator.pop(context);

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Alarm',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('Are you sure you want to delete this alarm?',
            style: TextStyle(color: Color(0xFF8A85A0), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA29BFE))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, 'delete');
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );
  }

  /// Convert 24-hour value back to internal 12h + isAM format
  void _setHour24(int hour24) {
    setState(() {
      if (hour24 == 0) {
        _alarm.hour = 12;
        _alarm.isAM = true;
      } else if (hour24 < 12) {
        _alarm.hour = hour24;
        _alarm.isAM = true;
      } else if (hour24 == 12) {
        _alarm.hour = 12;
        _alarm.isAM = false;
      } else {
        _alarm.hour = hour24 - 12;
        _alarm.isAM = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    final is24h = settings.use24HourFormat;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _cancel,
                    child: const Text('Cancel',
                        style: TextStyle(color: Color(0xFFA29BFE),
                            fontSize: 17, fontWeight: FontWeight.w400)),
                  ),
                  Text(widget.isNew ? 'Add Alarm' : 'Edit Alarm',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: _save,
                    child: const Text('Save',
                        style: TextStyle(color: Color(0xFF6C5CE7),
                            fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ── Time Picker ──
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: const Color(0xFF12121A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Selection indicator bar
                          Container(
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
                              border: Border.all(
                                color: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Hour wheel
                              SizedBox(
                                width: 70,
                                height: 250,
                                child: is24h
                                    ? _build24HourWheel()
                                    : _build12HourWheel(),
                              ),
                              const Text(':',
                                  style: TextStyle(color: Color(0xFF6C5CE7),
                                      fontSize: 28, fontWeight: FontWeight.w300)),
                              // Minute wheel
                              SizedBox(
                                width: 70,
                                height: 250,
                                child: _buildMinuteWheel(),
                              ),
                              // AM/PM wheel (only in 12h mode)
                              if (!is24h) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 56,
                                  height: 250,
                                  child: _buildAmPmWheel(),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Settings List ──
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF12121A),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          // Repeat
                          SettingsRow(label: 'Repeat', value: _alarm.daysString,
                              onTap: () => _openRepeatPicker()),
                          _divider(),
                          // Label
                          SettingsRow(label: 'Label', value: _alarm.label,
                              onTap: () => _openLabelEditor()),
                          _divider(),
                          // Sound — shows display name from filename
                          SettingsRow(
                            label: 'Sound',
                            value: _alarm.sound == 'None'
                                ? 'None'
                                : soundDisplayName(_alarm.sound),
                            onTap: () => _openSoundPicker(),
                          ),
                          _divider(),
                          // Flash Alarm toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Flash Alarm',
                                          style: TextStyle(color: Colors.white, fontSize: 16)),
                                      Text('Flash screen when alarm fires',
                                          style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _alarm.flashEnabled,
                                  onChanged: (val) {
                                    setState(() => _alarm.flashEnabled = val);
                                  },
                                  activeColor: const Color(0xFF6C5CE7),
                                  inactiveTrackColor: const Color(0xFF2A2A3A),
                                ),
                              ],
                            ),
                          ),
                          _divider(),
                          // Snooze toggle
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Snooze',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                                Switch(
                                  value: _alarm.snoozeEnabled,
                                  onChanged: (val) {
                                    setState(() => _alarm.snoozeEnabled = val);
                                  },
                                  activeColor: const Color(0xFF6C5CE7),
                                  inactiveTrackColor: const Color(0xFF2A2A3A),
                                ),
                              ],
                            ),
                          ),
                          if (_alarm.snoozeEnabled) ...[
                            _divider(),
                            SettingsRow(
                              label: 'Snooze Duration',
                              value: '${_alarm.snoozeDurationMinutes} min',
                              onTap: () => _openSnoozeDurationPicker(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Delete button (only for existing alarms)
                    if (!widget.isNew)
                      GestureDetector(
                        onTap: _delete,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12121A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text('Delete Alarm',
                                style: TextStyle(color: Color(0xFFFF6B6B),
                                    fontSize: 17, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Wheel Builders ──

  Widget _build24HourWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _hourController,
      itemExtent: 50,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => _setHour24(i),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 23) return null;
          final sel = index == _alarm.hour24;
          return Center(
            child: Text(index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF4A4A5A),
                  fontSize: sel ? 28 : 22,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w300,
                )),
          );
        },
        childCount: 24,
      ),
    );
  }

  Widget _build12HourWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _hourController,
      itemExtent: 50,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => _alarm.hour = i + 1),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 11) return null;
          final h = index + 1;
          final sel = h == _alarm.hour;
          return Center(
            child: Text(h.toString(),
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF4A4A5A),
                  fontSize: sel ? 28 : 22,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w300,
                )),
          );
        },
        childCount: 12,
      ),
    );
  }

  Widget _buildMinuteWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _minuteController,
      itemExtent: 50,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => _alarm.minute = i),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 59) return null;
          final sel = index == _alarm.minute;
          return Center(
            child: Text(index.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: sel ? Colors.white : const Color(0xFF4A4A5A),
                  fontSize: sel ? 28 : 22,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w300,
                )),
          );
        },
        childCount: 60,
      ),
    );
  }

  Widget _buildAmPmWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _amPmController,
      itemExtent: 50,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) => setState(() => _alarm.isAM = i == 0),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 1) return null;
          final label = index == 0 ? 'AM' : 'PM';
          final sel = (index == 0) == _alarm.isAM;
          return Center(
            child: Text(label,
                style: TextStyle(
                  color: sel ? const Color(0xFFA29BFE) : const Color(0xFF4A4A5A),
                  fontSize: sel ? 18 : 15,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                )),
          );
        },
        childCount: 2,
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.only(left: 16),
      child: Divider(color: Color(0xFF1E1E2E), height: 1, thickness: 1),
    );
  }

  // ── Sub-screen openers ──

  void _openRepeatPicker() async {
    final result = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => RepeatDayPicker(selectedDays: List.from(_alarm.repeatDays)),
      ),
    );
    if (result != null) setState(() => _alarm.repeatDays = result);
  }

  void _openLabelEditor() async {
    final controller = TextEditingController(text: _alarm.label);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Label', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          cursorColor: const Color(0xFF6C5CE7),
          decoration: InputDecoration(
            hintText: 'Alarm',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: const Color(0xFF6C5CE7).withValues(alpha: 0.3)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF6C5CE7)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A85A0)))),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Done', style: TextStyle(color: Color(0xFF6C5CE7)))),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _alarm.label = result);
    }
  }

  void _openSoundPicker() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => SoundPickerScreen(
          selectedSound: _alarm.sound,
          soundType: 'alarms', // Use alarm sounds list
        ),
      ),
    );
    if (result != null) setState(() => _alarm.sound = result);
  }

  void _openSnoozeDurationPicker() {
    final options = [1, 2, 3, 5, 9, 10, 15, 20, 30];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFF3A3A4A),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Snooze Duration',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                ...options.map((mins) {
                  final isSelected = mins == _alarm.snoozeDurationMinutes;
                  return ListTile(
                    title: Text('$mins minutes',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFA29BFE) : Colors.white,
                          fontSize: 16,
                        )),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF6C5CE7), size: 20)
                        : null,
                    onTap: () {
                      setState(() => _alarm.snoozeDurationMinutes = mins);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Reusable Settings Row ────────────────────────────────────────────────────

class SettingsRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const SettingsRow({super.key, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
            Row(
              children: [
                Text(value, style: const TextStyle(color: Color(0xFF6A6A7A), fontSize: 16)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, color: Color(0xFF3A3A4A), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}