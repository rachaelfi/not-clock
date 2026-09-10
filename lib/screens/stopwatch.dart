import 'package:flutter/material.dart';
import 'dart:async';
import 'package:not_clock/main.dart';
import 'package:not_clock/theme/app_theme.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<Duration> _laps = [];
  Duration? _bestLap;
  Duration? _worstLap;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startStop() {
    if (_stopwatch.isRunning) {
      _stopwatch.stop();
      _timer?.cancel();
    } else {
      _stopwatch.start();
      _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
    setState(() {});
  }

  void _reset() {
    _stopwatch.stop();
    _stopwatch.reset();
    _timer?.cancel();
    setState(() {
      _laps.clear();
      _bestLap = null;
      _worstLap = null;
    });
  }

  void _lap() {
    if (!_stopwatch.isRunning) return;

    final lapTime = _laps.isEmpty
        ? _stopwatch.elapsed
        : _stopwatch.elapsed - _laps.fold(Duration.zero, (a, b) => a + b);

    setState(() {
      _laps.insert(0, lapTime);
      _recalcBestWorst();
    });
  }

  void _recalcBestWorst() {
    if (_laps.length < 2) {
      _bestLap = null;
      _worstLap = null;
      return;
    }
    _bestLap = _laps.reduce((a, b) => a < b ? a : b);
    _worstLap = _laps.reduce((a, b) => a > b ? a : b);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds.$centiseconds';
    }
    return '$minutes:$seconds.$centiseconds';
  }

  String _formatLapDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final centiseconds =
        (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString();
      return '$hours:$minutes:$seconds.$centiseconds';
    }
    return '$minutes:$seconds.$centiseconds';
  }

  /// Current lap time (time since last recorded lap)
  Duration get _currentLapTime {
    if (_laps.isEmpty) return _stopwatch.elapsed;
    return _stopwatch.elapsed - _laps.fold(Duration.zero, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;
    final elapsed = _stopwatch.elapsed;
    final isRunning = _stopwatch.isRunning;
    final hasStarted = elapsed > Duration.zero;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stopwatch',
                    style: TextStyle(color: c.text, fontSize: 32,
                        fontWeight: FontWeight.w700)),
                const SettingsGearButton(),
              ],
            ),

            const SizedBox(height: 32),

            // Main time display
            Center(
              child: Column(
                children: [
                  Text(
                    _formatDuration(elapsed),
                    style: TextStyle(
                      color: isRunning ? c.text : c.text.withValues(alpha: 0.8),
                      fontSize: elapsed.inHours > 0 ? 48 : 56,
                      fontWeight: FontWeight.w200,
                      letterSpacing: 2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  // Current lap indicator
                  if (_laps.isNotEmpty && (isRunning || hasStarted))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Lap ${_laps.length + 1}  ${_formatLapDuration(_currentLapTime)}',
                        style: TextStyle(
                          color: c.accentSoft,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Control buttons
            Row(
              children: [
                if (hasStarted)
                  _buildControlButton(
                    c: c,
                    label: isRunning ? 'Lap' : 'Reset',
                    onTap: isRunning ? _lap : _reset,
                    isPrimary: false,
                  ),
                if (hasStarted) const SizedBox(width: 12),
                _buildControlButton(
                  c: c,
                  label: isRunning ? 'Stop' : (hasStarted ? 'Resume' : 'Start'),
                  onTap: _startStop,
                  isPrimary: true,
                  isStop: isRunning,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Laps list
            if (_laps.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('LAPS',
                    style: TextStyle(color: c.subtext, fontSize: 12,
                        fontWeight: FontWeight.w500, letterSpacing: 1.2)),
              ),
              Expanded(child: _buildLapsList(c)),
            ] else
              const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required AppColors c,
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    bool isStop = false,
  }) {
    Color bgColor;
    Color textColor;
    Color borderColor;

    if (isStop) {
      bgColor = c.danger.withValues(alpha: 0.15);
      textColor = c.danger;
      borderColor = c.danger.withValues(alpha: 0.3);
    } else if (isPrimary) {
      bgColor = c.accentWash(0.2);
      textColor = c.accentSoft;
      borderColor = c.accentWash(0.3);
    } else {
      bgColor = c.card;
      textColor = c.subtext;
      borderColor = c.divider;
    }

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bgColor,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(color: textColor, fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _buildLapsList(AppColors c) {
    return ListView.separated(
      itemCount: _laps.length,
      separatorBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Divider(color: c.divider, height: 1),
      ),
      itemBuilder: (context, index) {
        final lapNumber = _laps.length - index;
        final lapTime = _laps[index];

        // Determine color: green for best, red for worst, normal otherwise
        Color timeColor = c.text;
        String? badge;
        if (_bestLap != null && lapTime == _bestLap) {
          timeColor = c.success;
          badge = 'BEST';
        } else if (_worstLap != null && lapTime == _worstLap) {
          timeColor = c.danger;
          badge = 'WORST';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text('Lap $lapNumber',
                    style: TextStyle(color: c.subtext, fontSize: 14)),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: timeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(badge,
                      style: TextStyle(color: timeColor, fontSize: 9,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
              const Spacer(),
              Text(_formatLapDuration(lapTime),
                  style: TextStyle(
                    color: timeColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
            ],
          ),
        );
      },
    );
  }
}