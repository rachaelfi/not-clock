import 'dart:async';
import 'package:flutter/material.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/services/audio_service.dart';

/// Full-screen alarm firing overlay.
///
/// Shows when an alarm or sleep alarm fires. Displays:
/// - Current time and alarm label
/// - Flashing screen effect (if flashEnabled)
/// - Snooze button (if snooze is enabled on the alarm)
/// - Dismiss button to stop the alarm
///
/// The sound loops until dismissed, snoozed, or the 3-minute
/// auto-stop in AudioService kicks in.
class AlarmFiringScreen extends StatefulWidget {
  final AlarmData alarm;
  final bool isFromSleep;
  final VoidCallback onDismiss;
  final void Function(int snoozeDuration) onSnooze;

  const AlarmFiringScreen({
    super.key,
    required this.alarm,
    required this.isFromSleep,
    required this.onDismiss,
    required this.onSnooze,
  });

  @override
  State<AlarmFiringScreen> createState() => _AlarmFiringScreenState();
}

class _AlarmFiringScreenState extends State<AlarmFiringScreen>
    with TickerProviderStateMixin {
  // Flash animation controller
  late AnimationController _flashController;
  late Animation<double> _flashAnimation;

  // Clock update timer (to show live time)
  Timer? _clockTimer;

  // Auto-dismiss after 3 minutes (matches audio auto-stop)
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();

    // Start playing the alarm sound
    if (widget.alarm.sound != 'None') {
      AudioService.playAlarmSound(widget.alarm.sound);
    }

    // Set up flash animation (0.0 = dark, 1.0 = bright white flash)
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _flashAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    // Start flashing if enabled
    if (widget.alarm.flashEnabled) {
      _flashController.repeat(reverse: true);
    }

    // Update clock display every second
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Auto-dismiss after 3 minutes
    _autoDismissTimer = Timer(const Duration(minutes: 3), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    _clockTimer?.cancel();
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    AudioService.stop(); // Stop the alarm sound
    Navigator.pop(context); // Pop FIRST so the screen always closes on one tap
    widget.onDismiss(); // Then run cleanup
  }

  void _snooze() {
    AudioService.stop(); // Stop the alarm sound
    Navigator.pop(context);
    widget.onSnooze(widget.alarm.snoozeDurationMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    final c = settings.colors;
    final now = DateTime.now();
    // Respects the 24-hour setting, which the old hardcoded formatter didn't.
    final currentTimeString = settings.formatTime(now.hour, now.minute);

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          // ── Flash overlay (white screen that pulses) ──
          if (widget.alarm.flashEnabled)
            AnimatedBuilder(
              animation: _flashAnimation,
              builder: (context, child) {
                return Container(
                  color: Colors.white
                      .withValues(alpha: _flashAnimation.value * 0.85),
                );
              },
            ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Alarm icon with pulse
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.accentWash(0.2),
                        border: Border.all(color: c.accentWash(0.4), width: 2),
                      ),
                      child: Icon(
                        widget.isFromSleep
                            ? Icons.bedtime_rounded
                            : Icons.alarm,
                        color: c.accentSoft,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // // Label
                    // Text(
                    //   widget.alarm.label,
                    //   style: TextStyle(
                    //     color: c.subtext,
                    //     fontSize: 18,
                    //     fontWeight: FontWeight.w400,
                    //     letterSpacing: 0.5,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),

                    const SizedBox(height: 12),

                    // Current time (big)
                    Text(
                      currentTimeString,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // "Alarm" or "Sleep Alarm" subtitle
                    Text(
                      widget.isFromSleep ? 'Good Morning' : widget.alarm.label,
                      style: TextStyle(
                        color: c.accentSoft.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),

                    // Flash indicator
                    if (widget.alarm.flashEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on, color: c.warning, size: 14),
                          const SizedBox(width: 4),
                          Text('Flash active',
                              style: TextStyle(
                                color: c.warning.withValues(alpha: 0.7),
                                fontSize: 12,
                              )),
                        ],
                      ),
                    ],

                    const Spacer(flex: 3),

                    // ── Snooze button (only if snooze is enabled) ──
                    if (widget.alarm.snoozeEnabled)
                      GestureDetector(
                        onTap: _snooze,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: c.card,
                            border:
                                Border.all(color: c.accentWash(0.3), width: 1),
                          ),
                          child: Column(
                            children: [
                              Text('Snooze',
                                  style: TextStyle(
                                    color: c.accentSoft,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.alarm.snoozeDurationMinutes} minutes',
                                style: TextStyle(
                                  color: c.accentSoft.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.alarm.snoozeEnabled)
                      const SizedBox(height: 16),

                    // ── Dismiss button ──
                    GestureDetector(
                      onTap: _dismiss,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: c.dangerGradient,
                          boxShadow: c.dangerGlow,
                        ),
                        child: Center(
                          child: Text('Dismiss',
                              style: TextStyle(
                                color: c.onDanger,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              )),
                        ),
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}