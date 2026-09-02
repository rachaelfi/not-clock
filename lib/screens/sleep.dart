import 'package:flutter/material.dart';
import 'dart:async';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/app_settings.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen>
    with TickerProviderStateMixin {
  // Alarm time stored in 12h format internally
  int _selectedHour = 7; // 1-12
  int _selectedMinute = 0; // Index into 5-min increments (0-11)
  bool _isAM = true;
  bool _alarmIsSet = false;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  Timer? _updateTimer;

  /// Get current hour in 24h format
  int get _hour24 {
    int h = _selectedHour;
    if (_isAM && _selectedHour == 12) h = 0;
    if (!_isAM && _selectedHour != 12) h = _selectedHour + 12;
    return h;
  }

  /// Set time from a 24h hour value
  void _setFromHour24(int hour24) {
    if (hour24 == 0) {
      _selectedHour = 12;
      _isAM = true;
    } else if (hour24 < 12) {
      _selectedHour = hour24;
      _isAM = true;
    } else if (hour24 == 12) {
      _selectedHour = 12;
      _isAM = false;
    } else {
      _selectedHour = hour24 - 12;
      _isAM = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _hourController =
        FixedExtentScrollController(initialItem: _selectedHour - 1);
    _minuteController =
        FixedExtentScrollController(initialItem: _selectedMinute);
    _amPmController =
        FixedExtentScrollController(initialItem: _isAM ? 0 : 1);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_alarmIsSet) setState(() {});
    });
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    _glowController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Duration _getSleepDuration() {
    final now = DateTime.now();
    int alarmMinute = _selectedMinute * 5;

    var alarmTime =
        DateTime(now.year, now.month, now.day, _hour24, alarmMinute);
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }
    return alarmTime.difference(now);
  }

  String _formatSleepDuration() {
    final duration = _getSleepDuration();
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final roundedMin = (minutes / 5).round() * 5;
    if (roundedMin == 60) {
      return '${hours + 1} h 00 min';
    }
    return '$hours h ${roundedMin.toString().padLeft(2, '0')} min';
  }

  void _setQuickSleepAlarm(double hours) {
    final now = DateTime.now();
    final alarmTime = now.add(Duration(minutes: (hours * 60).round()));
    final is24h = SettingsProvider.of(context).use24HourFormat;

    int hour24 = alarmTime.hour;
    int minuteIndex = (alarmTime.minute / 5).round();
    if (minuteIndex >= 12) minuteIndex = 0;

    setState(() {
      _setFromHour24(hour24);
      _selectedMinute = minuteIndex;
      _alarmIsSet = true;

      if (is24h) {
        _hourController.animateToItem(hour24,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      } else {
        _hourController.animateToItem(_selectedHour - 1,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        _amPmController.animateToItem(_isAM ? 0 : 1,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
      _minuteController.animateToItem(minuteIndex,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    });
  }

  void _toggleAlarm() {
    setState(() {
      _alarmIsSet = !_alarmIsSet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sleep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SettingsGearButton(),
              ],
            ),
            const SizedBox(height: 8),

            // Sleep duration display
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                        const Color(0xFF6C5CE7).withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Color.lerp(
                        const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                        const Color(0xFF6C5CE7).withValues(alpha: 0.5),
                        _alarmIsSet ? _glowAnimation.value : 0.0,
                      )!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.nightlight_round,
                              color: _alarmIsSet
                                  ? const Color(0xFFA29BFE)
                                  : const Color(0xFF4A4A5A),
                              size: 18),
                          const SizedBox(width: 8),
                          Text('sleep duration',
                              style: TextStyle(
                                color: _alarmIsSet
                                    ? const Color(0xFF8A85A0)
                                    : const Color(0xFF4A4A5A),
                                fontSize: 13, fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('~ ${_formatSleepDuration()}',
                          style: TextStyle(
                            color: _alarmIsSet
                                ? Colors.white : const Color(0xFF6A6A7A),
                            fontSize: 28, fontWeight: FontWeight.w300,
                            letterSpacing: 1.0,
                          )),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            Expanded(child: _buildTimePicker(settings)),
            _buildQuickSleepButtons(),
            const SizedBox(height: 16),
            _buildSetAlarmButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(AppSettings settings) {
    final is24h = settings.use24HourFormat;

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 52,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.1),
            border: Border.all(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3), width: 1,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Hour wheel
            SizedBox(
              width: 80,
              height: 220,
              child: is24h ? _build24HourWheel() : _build12HourWheel(),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(':',
                  style: TextStyle(color: Color(0xFF6C5CE7),
                      fontSize: 32, fontWeight: FontWeight.w300)),
            ),
            // Minute wheel (5-min increments, same for both modes)
            SizedBox(
              width: 80,
              height: 220,
              child: _buildMinuteWheel(),
            ),
            // AM/PM wheel (only in 12h mode)
            if (!is24h) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                height: 220,
                child: _buildAmPmWheel(),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _build24HourWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _hourController,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() => _setFromHour24(index));
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 23) return null;
          final isSelected = index == _hour24;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4A4A5A),
                fontSize: isSelected ? 32 : 24,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
              ),
            ),
          );
        },
        childCount: 24,
      ),
    );
  }

  Widget _build12HourWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _hourController,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() => _selectedHour = index + 1);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 11) return null;
          final hour = index + 1;
          final isSelected = hour == _selectedHour;
          return Center(
            child: Text(
              hour.toString(),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4A4A5A),
                fontSize: isSelected ? 32 : 24,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
              ),
            ),
          );
        },
        childCount: 12,
      ),
    );
  }

  Widget _buildMinuteWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _minuteController,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() => _selectedMinute = index);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 11) return null;
          final minute = index * 5;
          final isSelected = index == _selectedMinute;
          return Center(
            child: Text(
              minute.toString().padLeft(2, '0'),
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4A4A5A),
                fontSize: isSelected ? 32 : 24,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w300,
              ),
            ),
          );
        },
        childCount: 12,
      ),
    );
  }

  Widget _buildAmPmWheel() {
    return ListWheelScrollView.useDelegate(
      controller: _amPmController,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (index) {
        setState(() => _isAM = index == 0);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index > 1) return null;
          final label = index == 0 ? 'AM' : 'PM';
          final isSelected = (index == 0) == _isAM;
          return Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFFA29BFE) : const Color(0xFF4A4A5A),
                fontSize: isSelected ? 20 : 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
        childCount: 2,
      ),
    );
  }

  Widget _buildQuickSleepButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick sleep',
            style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
                fontWeight: FontWeight.w500, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(
          children: [
            _quickButton('6h', 6),
            const SizedBox(width: 10),
            _quickButton('7h', 7),
            const SizedBox(width: 10),
            _quickButton('7.5h', 7.5),
            const SizedBox(width: 10),
            _quickButton('8h', 8),
            const SizedBox(width: 10),
            _quickButton('9h', 9),
          ],
        ),
      ],
    );
  }

  Widget _quickButton(String label, double hours) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuickSleepAlarm(hours),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF1A1A24),
            border: Border.all(color: const Color(0xFF2A2A3A), width: 1),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(color: Color(0xFFA29BFE),
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildSetAlarmButton() {
    return GestureDetector(
      onTap: _toggleAlarm,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: _alarmIsSet
              ? const LinearGradient(
                  colors: [Color(0xFF3A3545), Color(0xFF2A2535)])
              : const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF6C5CE7), Color(0xFF5A4BD1)]),
          boxShadow: _alarmIsSet ? [] : [
            BoxShadow(
              color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
              blurRadius: 20, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_alarmIsSet ? Icons.alarm_off : Icons.alarm_add,
                color: _alarmIsSet ? const Color(0xFF8A85A0) : Colors.white,
                size: 22),
            const SizedBox(width: 10),
            Text(_alarmIsSet ? 'Cancel Alarm' : 'Set Sleep Alarm',
                style: TextStyle(
                  color: _alarmIsSet ? const Color(0xFF8A85A0) : Colors.white,
                  fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.3,
                )),
          ],
        ),
      ),
    );
  }
}