import 'package:flutter/material.dart';
import 'dart:async';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/screens/alarm_sub/sound_picker.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/services/storage_service.dart';
import 'package:not_clock/services/timer_sound_service.dart';

// ─── Timer Data Model ─────────────────────────────────────────────────────────

class _TimerData {
  final String id;
  String label;
  Duration totalDuration;
  Duration remaining;
  bool isRunning;
  bool isPaused;
  bool isFinished;
  Timer? timer;

  _TimerData({
    required this.id,
    required this.label,
    required this.totalDuration,
  })  : remaining = totalDuration,
        isRunning = false,
        isPaused = false,
        isFinished = false;

  double get progress {
    if (totalDuration.inSeconds == 0) return 0;
    return 1.0 - (remaining.inMilliseconds / totalDuration.inMilliseconds);
  }
}

/// "1h 30m 15s" — unit letters are numeric shorthand and read the same in
/// every language the app supports, so they stay as-is.
String formatDurationShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final parts = <String>[];
  if (h > 0) parts.add('${h}h');
  if (m > 0) parts.add('${m}m');
  if (s > 0) parts.add('${s}s');
  return parts.join(' ');
}

/// Row that opens the timer sound picker. Shared by the inline picker and the
/// Add Timer sheet so the control sits in the same place either way.
class TimerSoundRow extends StatelessWidget {
  const TimerSoundRow({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);
    final c = settings.colors;
    final t = AppLocalizations.of(context);
    final sound = settings.timerSound;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => SoundPickerScreen(
              selectedSound: sound,
              soundType: 'timers',
            ),
          ),
        );
        if (result != null) settings.timerSound = result;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: c.card,
          border: Border.all(color: c.divider, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              sound == 'None' ? Icons.volume_off : Icons.music_note,
              color: c.accentSoft,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(t.timerSound,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.text, fontSize: 15)),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                sound == 'None' ? t.none : soundDisplayName(sound),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c.subtext, fontSize: 14),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: c.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Main Timers Screen ───────────────────────────────────────────────────────

class TimersScreen extends StatefulWidget {
  const TimersScreen({super.key});

  @override
  State<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends State<TimersScreen> {
  final List<_TimerData> _timers = [];
  final List<Duration> _recentTimers = [];
  int _timerCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final saved = await StorageService.loadRecentTimers();
    if (saved.isNotEmpty) {
      setState(() {
        _recentTimers.addAll(saved.map((secs) => Duration(seconds: secs)));
      });
    }
  }

  Future<void> _saveRecents() async {
    await StorageService.saveRecentTimers(
      _recentTimers.map((d) => d.inSeconds).toList(),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  void _addToRecents(Duration duration) {
    _recentTimers.remove(duration);
    _recentTimers.insert(0, duration);
    if (_recentTimers.length > 10) _recentTimers.removeLast();
    _saveRecents();
  }

  /// True while any timer on screen is sitting at zero. The sound belongs to
  /// the group, not to one card, so it only stops once none are left ringing.
  bool get _anyFinished => _timers.any((t) => t.isFinished);

  void _stopSoundIfNothingRinging() {
    if (!_anyFinished) TimerSoundService.stop();
  }

  void _startTimerFromDuration(Duration duration) {
    _timerCounter++;
    final timerData = _TimerData(
      id: 'timer_$_timerCounter',
      label: formatDurationShort(duration),
      totalDuration: duration,
    );

    _addToRecents(duration);
    _runTimer(timerData);

    setState(() {
      _timers.insert(0, timerData);
    });
  }

  void _runTimer(_TimerData data) {
    data.isRunning = true;
    data.isPaused = false;
    data.timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        final newRemaining =
            data.remaining - const Duration(milliseconds: 100);
        if (newRemaining <= Duration.zero) {
          data.remaining = Duration.zero;
          data.isRunning = false;
          data.isFinished = true;
          data.timer?.cancel();
          // Loops until cancelled, or 90 seconds, whichever comes first.
          TimerSoundService.play(
              SettingsProvider.read(context).timerSound);
        } else {
          data.remaining = newRemaining;
        }
      });
    });
  }

  void _pauseTimer(_TimerData data) {
    data.timer?.cancel();
    setState(() {
      data.isRunning = false;
      data.isPaused = true;
    });
  }

  void _resumeTimer(_TimerData data) {
    _runTimer(data);
    setState(() {});
  }

  void _cancelTimer(_TimerData data) {
    data.timer?.cancel();
    setState(() {
      _timers.remove(data);
    });
    _stopSoundIfNothingRinging();
  }

  void _restartTimer(_TimerData data) {
    data.timer?.cancel();
    setState(() {
      data.remaining = data.totalDuration;
      data.isFinished = false;
    });
    _stopSoundIfNothingRinging();
    _runTimer(data);
  }

  void _openAddTimerModal() async {
    final result = await showModalBottomSheet<Duration>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddTimerModal(recentTimers: _recentTimers),
    );

    if (result != null) {
      _startTimerFromDuration(result);
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.timer?.cancel();
    }
    // Leaving the tab shouldn't leave a timer ringing with nothing on screen
    // to silence it.
    TimerSoundService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;
    final t = AppLocalizations.of(context);
    final showInlinePicker = _timers.isEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(t.timersTitle,
                      style: TextStyle(color: c.text, fontSize: 32,
                          fontWeight: FontWeight.w700)),
                ),
                Row(
                  children: [
                    if (!showInlinePicker)
                      GestureDetector(
                        onTap: _openAddTimerModal,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: c.accentWash(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.add, color: c.accentSoft, size: 24),
                        ),
                      ),
                    if (!showInlinePicker) const SizedBox(width: 10),
                    const SettingsGearButton(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            Expanded(
              child: showInlinePicker
                  ? _InlinePickerView(
                      recentTimers: _recentTimers,
                      onStart: (d) => _startTimerFromDuration(d),
                      onDeleteRecent: (i) {
                        setState(() => _recentTimers.removeAt(i));
                        _saveRecents();
                      },
                    )
                  : _buildTimersAndRecents(c, t),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimersAndRecents(AppColors c, AppLocalizations t) {
    return ListView(
      children: [
        for (int i = 0; i < _timers.length; i++) ...[
          _buildTimerCard(c, t, _timers[i]),
          if (i < _timers.length - 1) const SizedBox(height: 12),
        ],

        if (_recentTimers.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(t.recents,
              style: TextStyle(color: c.subtext, fontSize: 12,
                  fontWeight: FontWeight.w500, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          for (int i = 0; i < _recentTimers.length; i++) ...[
            _buildRecentTile(c, _recentTimers[i], i),
            if (i < _recentTimers.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Divider(color: c.divider, height: 1),
              ),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecentTile(AppColors c, Duration duration, int index) {
    return Dismissible(
      key: ValueKey('recent_main_${duration.inSeconds}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: c.danger, size: 22),
      ),
      onDismissed: (_) {
        setState(() => _recentTimers.removeAt(index));
        _saveRecents();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatDurationShort(duration),
                style: TextStyle(
                    color: c.text, fontSize: 18, fontWeight: FontWeight.w300),
              ),
            ),
            GestureDetector(
              onTap: () => _startTimerFromDuration(duration),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentWash(0.2),
                  border: Border.all(color: c.accentWash(0.3), width: 1.5),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: c.accentSoft, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard(AppColors c, AppLocalizations t, _TimerData data) {
    final Color progressColor;
    if (data.isFinished) {
      progressColor = c.danger;
    } else if (data.remaining.inSeconds <= 10 &&
        data.remaining.inSeconds > 0) {
      progressColor = c.warning;
    } else {
      progressColor = c.accent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isFinished
              ? c.danger.withValues(alpha: 0.3)
              : c.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data.label,
                  style: TextStyle(color: c.subtext, fontSize: 13)),
              if (data.isFinished)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(t.timerDone,
                      style: TextStyle(
                          color: c.danger,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDuration(data.remaining),
            style: TextStyle(
              color: data.isFinished ? c.danger : c.text,
              fontSize: 40,
              fontWeight: FontWeight.w200,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: data.progress,
              backgroundColor: c.divider,
              color: progressColor,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _cancelTimer(data),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: c.cardAlt,
                      border: Border.all(color: c.divider),
                    ),
                    child: Center(
                      child: Text(t.cancel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: c.subtext,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (data.isFinished) {
                      _restartTimer(data);
                    } else if (data.isRunning) {
                      _pauseTimer(data);
                    } else {
                      _resumeTimer(data);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: data.isRunning
                          ? c.warning.withValues(alpha: 0.1)
                          : c.accentWash(0.15),
                      border: Border.all(
                        color: data.isRunning
                            ? c.warning.withValues(alpha: 0.3)
                            : c.accentWash(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        data.isFinished
                            ? t.restart
                            : data.isRunning
                                ? t.pause
                                : t.resume,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: data.isRunning ? c.warning : c.accentSoft,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Inline Picker (shown when no timers are running) ─────────────────────────

class _InlinePickerView extends StatefulWidget {
  final List<Duration> recentTimers;
  final ValueChanged<Duration> onStart;
  final ValueChanged<int> onDeleteRecent;

  const _InlinePickerView({
    required this.recentTimers,
    required this.onStart,
    required this.onDeleteRecent,
  });

  @override
  State<_InlinePickerView> createState() => _InlinePickerViewState();
}

class _InlinePickerViewState extends State<_InlinePickerView> {
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _hoursController = FixedExtentScrollController(initialItem: 0);
    _minutesController = FixedExtentScrollController(initialItem: 5);
    _secondsController = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void didUpdateWidget(covariant _InlinePickerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _resetPicker();
  }

  void _resetPicker() {
    _hours = 0;
    _minutes = 5;
    _seconds = 0;
    if (_hoursController.hasClients) _hoursController.jumpToItem(0);
    if (_minutesController.hasClients) _minutesController.jumpToItem(5);
    if (_secondsController.hasClients) _secondsController.jumpToItem(0);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Duration get _pickerDuration =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  bool get _pickerIsZero => _pickerDuration == Duration.zero;

  void _setQuickTimer(Duration duration) {
    setState(() {
      _hours = duration.inHours;
      _minutes = duration.inMinutes.remainder(60);
      _seconds = duration.inSeconds.remainder(60);
      _hoursController.animateToItem(_hours,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _minutesController.animateToItem(_minutes,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _secondsController.animateToItem(_seconds,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;
    final t = AppLocalizations.of(context);

    return ListView(
      children: [
        const SizedBox(height: 20),

        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: c.accentWash(0.1),
                  border: Border.all(color: c.accentWash(0.25), width: 1),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildWheel(c, _hoursController, 24, _hours,
                      (i) => setState(() => _hours = i), 'h'),
                  const SizedBox(width: 8),
                  _buildWheel(c, _minutesController, 60, _minutes,
                      (i) => setState(() => _minutes = i), 'm'),
                  const SizedBox(width: 8),
                  _buildWheel(c, _secondsController, 60, _seconds,
                      (i) => setState(() => _seconds = i), 's'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        Text(t.quickTimers,
            style: TextStyle(color: c.subtext, fontSize: 12,
                fontWeight: FontWeight.w500, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(
          children: [
            _quickPreset(c, '1m', const Duration(minutes: 1)),
            const SizedBox(width: 8),
            _quickPreset(c, '3m', const Duration(minutes: 3)),
            const SizedBox(width: 8),
            _quickPreset(c, '5m', const Duration(minutes: 5)),
            const SizedBox(width: 8),
            _quickPreset(c, '10m', const Duration(minutes: 10)),
            const SizedBox(width: 8),
            _quickPreset(c, '15m', const Duration(minutes: 15)),
            const SizedBox(width: 8),
            _quickPreset(c, '30m', const Duration(minutes: 30)),
          ],
        ),

        // ── Timer sound ──
        const SizedBox(height: 14),
        const TimerSoundRow(),

        const SizedBox(height: 28),

        GestureDetector(
          onTap: _pickerIsZero ? null : () => widget.onStart(_pickerDuration),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _pickerIsZero
                  ? LinearGradient(colors: [c.divider, c.divider])
                  : c.accentGradient,
              boxShadow: _pickerIsZero ? [] : c.accentGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded,
                    color: _pickerIsZero ? c.muted : c.onAccent,
                    size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(t.startTimer,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _pickerIsZero ? c.muted : c.onAccent,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ),

        if (widget.recentTimers.isNotEmpty) ...[
          const SizedBox(height: 32),
          Text(t.recents,
              style: TextStyle(color: c.subtext, fontSize: 12,
                  fontWeight: FontWeight.w500, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          for (int i = 0; i < widget.recentTimers.length; i++) ...[
            Dismissible(
              key: ValueKey(
                  'inline_recent_${widget.recentTimers[i].inSeconds}_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: c.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.delete_outline, color: c.danger, size: 22),
              ),
              onDismissed: (_) => widget.onDeleteRecent(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatDurationShort(widget.recentTimers[i]),
                        style: TextStyle(color: c.text,
                            fontSize: 18, fontWeight: FontWeight.w300),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => widget.onStart(widget.recentTimers[i]),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.accentWash(0.2),
                          border:
                              Border.all(color: c.accentWash(0.3), width: 1.5),
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            color: c.accentSoft, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < widget.recentTimers.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Divider(color: c.divider, height: 1),
              ),
          ],
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWheel(
    AppColors c,
    FixedExtentScrollController controller,
    int count,
    int selectedValue,
    ValueChanged<int> onChanged,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 200,
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 48,
            perspective: 0.003,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= count) return null;
                final sel = index == selectedValue;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: sel ? c.text : c.muted,
                      fontSize: sel ? 28 : 20,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w300,
                    ),
                  ),
                );
              },
              childCount: count,
            ),
          ),
        ),
        Text(label,
            style: TextStyle(color: c.subtext, fontSize: 14,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _quickPreset(AppColors c, String label, Duration duration) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuickTimer(duration),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: c.card,
            border: Border.all(color: c.divider, width: 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(color: c.accentSoft,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

// ─── Add Timer Modal (bottom sheet) ───────────────────────────────────────────

class _AddTimerModal extends StatefulWidget {
  final List<Duration> recentTimers;

  const _AddTimerModal({required this.recentTimers});

  @override
  State<_AddTimerModal> createState() => _AddTimerModalState();
}

class _AddTimerModalState extends State<_AddTimerModal> {
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  late FixedExtentScrollController _secondsController;
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _hoursController = FixedExtentScrollController(initialItem: 0);
    _minutesController = FixedExtentScrollController(initialItem: 5);
    _secondsController = FixedExtentScrollController(initialItem: 0);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Duration get _pickerDuration =>
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

  bool get _pickerIsZero => _pickerDuration == Duration.zero;

  void _setQuickTimer(Duration duration) {
    setState(() {
      _hours = duration.inHours;
      _minutes = duration.inMinutes.remainder(60);
      _seconds = duration.inSeconds.remainder(60);
      _hoursController.animateToItem(_hours,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _minutesController.animateToItem(_minutes,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      _secondsController.animateToItem(_seconds,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = SettingsProvider.of(context).colors;
    final t = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.muted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(t.cancel,
                      style: TextStyle(color: c.subtext,
                          fontSize: 16, fontWeight: FontWeight.w400)),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(t.addTimer,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.text, fontSize: 17,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                GestureDetector(
                  onTap: _pickerIsZero
                      ? null
                      : () => Navigator.pop(context, _pickerDuration),
                  child: Text(t.start,
                      style: TextStyle(
                        color: _pickerIsZero ? c.muted : c.accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                SizedBox(
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: c.accentWash(0.1),
                          border: Border.all(
                              color: c.accentWash(0.25), width: 1),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildWheel(c, _hoursController, 24, _hours,
                              (i) => setState(() => _hours = i), 'h'),
                          const SizedBox(width: 8),
                          _buildWheel(c, _minutesController, 60, _minutes,
                              (i) => setState(() => _minutes = i), 'm'),
                          const SizedBox(width: 8),
                          _buildWheel(c, _secondsController, 60, _seconds,
                              (i) => setState(() => _seconds = i), 's'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Text(t.quickTimers,
                    style: TextStyle(color: c.subtext, fontSize: 12,
                        fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickPreset(c, '1m', const Duration(minutes: 1)),
                    const SizedBox(width: 8),
                    _quickPreset(c, '3m', const Duration(minutes: 3)),
                    const SizedBox(width: 8),
                    _quickPreset(c, '5m', const Duration(minutes: 5)),
                    const SizedBox(width: 8),
                    _quickPreset(c, '10m', const Duration(minutes: 10)),
                    const SizedBox(width: 8),
                    _quickPreset(c, '15m', const Duration(minutes: 15)),
                    const SizedBox(width: 8),
                    _quickPreset(c, '30m', const Duration(minutes: 30)),
                  ],
                ),

                // ── Timer sound ──
                const SizedBox(height: 14),
                const TimerSoundRow(),

                if (widget.recentTimers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  Text(t.recents,
                      style: TextStyle(color: c.subtext, fontSize: 12,
                          fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  for (int i = 0; i < widget.recentTimers.length; i++) ...[
                    GestureDetector(
                      onTap: () =>
                          Navigator.pop(context, widget.recentTimers[i]),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                formatDurationShort(widget.recentTimers[i]),
                                style: TextStyle(
                                    color: c.text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w300),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.accentWash(0.2),
                                border: Border.all(
                                    color: c.accentWash(0.3), width: 1.5),
                              ),
                              child: Icon(Icons.play_arrow_rounded,
                                  color: c.accentSoft, size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < widget.recentTimers.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Divider(color: c.divider, height: 1),
                      ),
                  ],
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWheel(
    AppColors c,
    FixedExtentScrollController controller,
    int count,
    int selectedValue,
    ValueChanged<int> onChanged,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 200,
          child: ListWheelScrollView.useDelegate(
            controller: controller,
            itemExtent: 48,
            perspective: 0.003,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: onChanged,
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                if (index < 0 || index >= count) return null;
                final sel = index == selectedValue;
                return Center(
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      color: sel ? c.text : c.muted,
                      fontSize: sel ? 28 : 20,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w300,
                    ),
                  ),
                );
              },
              childCount: count,
            ),
          ),
        ),
        Text(label,
            style: TextStyle(color: c.subtext, fontSize: 14,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _quickPreset(AppColors c, String label, Duration duration) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuickTimer(duration),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: c.card,
            border: Border.all(color: c.divider, width: 1),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(color: c.accentSoft,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}