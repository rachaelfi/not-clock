import 'package:flutter/material.dart';
import 'dart:async';
import 'package:not_clock/main.dart';
import 'package:not_clock/services/storage_service.dart';

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
    // Load saved recent timers from disk
    _loadRecents();
  }

  /// Load recent timer durations from disk.
  /// Stored as seconds, converted back to Duration.
  Future<void> _loadRecents() async {
    final saved = await StorageService.loadRecentTimers();
    if (saved.isNotEmpty) {
      setState(() {
        _recentTimers.addAll(
          saved.map((secs) => Duration(seconds: secs)),
        );
      });
    }
  }

  /// Save recents to disk. Converts Duration to seconds for storage.
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

  String _formatDurationShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0) parts.add('${s}s');
    return parts.join(' ');
  }

  void _addToRecents(Duration duration) {
    _recentTimers.remove(duration);
    _recentTimers.insert(0, duration);
    if (_recentTimers.length > 10) _recentTimers.removeLast();
    _saveRecents(); // Persist to disk
  }

  void _startTimerFromDuration(Duration duration) {
    _timerCounter++;
    final timerData = _TimerData(
      id: 'timer_$_timerCounter',
      label: _formatDurationShort(duration),
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
  }

  void _restartTimer(_TimerData data) {
    data.timer?.cancel();
    setState(() {
      data.remaining = data.totalDuration;
      data.isFinished = false;
    });
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If no timers and no recents, show the picker inline
    final showInlinePicker = _timers.isEmpty;

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
                const Text('Timers',
                    style: TextStyle(color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    if (!showInlinePicker)
                      GestureDetector(
                        onTap: _openAddTimerModal,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add,
                              color: Color(0xFFA29BFE), size: 24),
                        ),
                      ),
                    if (!showInlinePicker) const SizedBox(width: 10),
                    const SettingsGearButton(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content
            Expanded(
              child: showInlinePicker
                  ? _InlinePickerView(
                      recentTimers: _recentTimers,
                      onStart: (d) => _startTimerFromDuration(d),
                      onDeleteRecent: (i) {
                          setState(() => _recentTimers.removeAt(i));
                          _saveRecents(); // Persist deletion
                        },
                    )
                  : _buildTimersAndRecents(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Active timers + recents in one scrollable list ──
  Widget _buildTimersAndRecents() {
    return ListView(
      children: [
        // Active timers
        for (int i = 0; i < _timers.length; i++) ...[
          _buildTimerCard(_timers[i]),
          if (i < _timers.length - 1) const SizedBox(height: 12),
        ],

        // Recents section
        if (_recentTimers.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('RECENTS',
              style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
                  fontWeight: FontWeight.w500, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          for (int i = 0; i < _recentTimers.length; i++) ...[
            _buildRecentTile(_recentTimers[i], i),
            if (i < _recentTimers.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Divider(color: Color(0xFF1E1E2E), height: 1),
              ),
          ],
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRecentTile(Duration duration, int index) {
    return Dismissible(
      key: ValueKey('recent_main_${duration.inSeconds}_$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child:
            const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B), size: 22),
      ),
      onDismissed: (_) {
        setState(() => _recentTimers.removeAt(index));
        _saveRecents(); // Persist deletion
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDurationShort(duration),
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w300),
              ),
            ),
            GestureDetector(
              onTap: () => _startTimerFromDuration(duration),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                  border: Border.all(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Color(0xFFA29BFE), size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard(_TimerData data) {
    final Color progressColor;
    if (data.isFinished) {
      progressColor = const Color(0xFFFF6B6B);
    } else if (data.remaining.inSeconds <= 10 &&
        data.remaining.inSeconds > 0) {
      progressColor = const Color(0xFFFFD93D);
    } else {
      progressColor = const Color(0xFF6C5CE7);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: data.isFinished
              ? const Color(0xFFFF6B6B).withValues(alpha: 0.3)
              : const Color(0xFF1E1E2E),
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
                  style:
                      const TextStyle(color: Color(0xFF6A6A7A), fontSize: 13)),
              if (data.isFinished)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('DONE',
                      style: TextStyle(
                          color: Color(0xFFFF6B6B),
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
              color: data.isFinished ? const Color(0xFFFF6B6B) : Colors.white,
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
              backgroundColor: const Color(0xFF2A2A3A),
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
                      color: const Color(0xFF1A1A24),
                      border: Border.all(color: const Color(0xFF2A2A3A)),
                    ),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Color(0xFF8A85A0),
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
                      color: data.isFinished
                          ? const Color(0xFF6C5CE7).withValues(alpha: 0.15)
                          : data.isRunning
                              ? const Color(0xFFFFD93D).withValues(alpha: 0.1)
                              : const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                      border: Border.all(
                        color: data.isFinished
                            ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                            : data.isRunning
                                ? const Color(0xFFFFD93D)
                                    .withValues(alpha: 0.3)
                                : const Color(0xFF6C5CE7)
                                    .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        data.isFinished
                            ? 'Restart'
                            : data.isRunning
                                ? 'Pause'
                                : 'Resume',
                        style: TextStyle(
                          color: data.isFinished
                              ? const Color(0xFFA29BFE)
                              : data.isRunning
                                  ? const Color(0xFFFFD93D)
                                  : const Color(0xFFA29BFE),
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

  // Reset wheels every time this widget is rebuilt (tab switch)
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

  String _formatDurationShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0) parts.add('${s}s');
    return parts.join(' ');
  }

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
    return ListView(
      children: [
        const SizedBox(height: 20),

        // Time picker wheels
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
                  _buildWheel(_hoursController, 24, _hours,
                      (i) => setState(() => _hours = i), 'h'),
                  const SizedBox(width: 8),
                  _buildWheel(_minutesController, 60, _minutes,
                      (i) => setState(() => _minutes = i), 'm'),
                  const SizedBox(width: 8),
                  _buildWheel(_secondsController, 60, _seconds,
                      (i) => setState(() => _seconds = i), 's'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Quick presets
        const Text('Quick timers',
            style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
                fontWeight: FontWeight.w500, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Row(
          children: [
            _quickPreset('1m', const Duration(minutes: 1)),
            const SizedBox(width: 8),
            _quickPreset('3m', const Duration(minutes: 3)),
            const SizedBox(width: 8),
            _quickPreset('5m', const Duration(minutes: 5)),
            const SizedBox(width: 8),
            _quickPreset('10m', const Duration(minutes: 10)),
            const SizedBox(width: 8),
            _quickPreset('15m', const Duration(minutes: 15)),
            const SizedBox(width: 8),
            _quickPreset('30m', const Duration(minutes: 30)),
          ],
        ),

        const SizedBox(height: 28),

        // Start button
        GestureDetector(
          onTap: _pickerIsZero
              ? null
              : () => widget.onStart(_pickerDuration),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _pickerIsZero
                  ? const LinearGradient(
                      colors: [Color(0xFF2A2A3A), Color(0xFF2A2A3A)])
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C5CE7), Color(0xFF5A4BD1)]),
              boxShadow: _pickerIsZero
                  ? []
                  : [
                      BoxShadow(
                        color:
                            const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded,
                    color: _pickerIsZero
                        ? const Color(0xFF4A4A5A)
                        : Colors.white,
                    size: 24),
                const SizedBox(width: 8),
                Text('Start Timer',
                    style: TextStyle(
                      color: _pickerIsZero
                          ? const Color(0xFF4A4A5A)
                          : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),

        // Recents
        if (widget.recentTimers.isNotEmpty) ...[
          const SizedBox(height: 32),
          const Text('RECENTS',
              style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
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
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFFF6B6B), size: 22),
              ),
              onDismissed: (_) => widget.onDeleteRecent(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDurationShort(widget.recentTimers[i]),
                        style: const TextStyle(color: Colors.white,
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
                          color: const Color(0xFF6C5CE7)
                              .withValues(alpha: 0.2),
                          border: Border.all(
                            color: const Color(0xFF6C5CE7)
                                .withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Color(0xFFA29BFE), size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < widget.recentTimers.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Divider(color: Color(0xFF1E1E2E), height: 1),
              ),
          ],
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildWheel(
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
                      color: sel ? Colors.white : const Color(0xFF4A4A5A),
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
            style: const TextStyle(color: Color(0xFF6A6A7A), fontSize: 14,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _quickPreset(String label, Duration duration) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuickTimer(duration),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A1A24),
            border: Border.all(color: const Color(0xFF2A2A3A), width: 1),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(color: Color(0xFFA29BFE),
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

  String _formatDurationShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final parts = <String>[];
    if (h > 0) parts.add('${h}h');
    if (m > 0) parts.add('${m}m');
    if (s > 0) parts.add('${s}s');
    return parts.join(' ');
  }

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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF3A3A4A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF8A85A0),
                          fontSize: 16, fontWeight: FontWeight.w400)),
                ),
                const Text('Add Timer',
                    style: TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: _pickerIsZero
                      ? null
                      : () => Navigator.pop(context, _pickerDuration),
                  child: Text('Start',
                      style: TextStyle(
                        color: _pickerIsZero
                            ? const Color(0xFF4A4A5A)
                            : const Color(0xFF6C5CE7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Picker wheels
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
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFF6C5CE7)
                              .withValues(alpha: 0.1),
                          border: Border.all(
                            color: const Color(0xFF6C5CE7)
                                .withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildWheel(_hoursController, 24, _hours,
                              (i) => setState(() => _hours = i), 'h'),
                          const SizedBox(width: 8),
                          _buildWheel(_minutesController, 60, _minutes,
                              (i) => setState(() => _minutes = i), 'm'),
                          const SizedBox(width: 8),
                          _buildWheel(_secondsController, 60, _seconds,
                              (i) => setState(() => _seconds = i), 's'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Quick presets
                const Text('Quick timers',
                    style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
                        fontWeight: FontWeight.w500, letterSpacing: 1.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _quickPreset('1m', const Duration(minutes: 1)),
                    const SizedBox(width: 8),
                    _quickPreset('3m', const Duration(minutes: 3)),
                    const SizedBox(width: 8),
                    _quickPreset('5m', const Duration(minutes: 5)),
                    const SizedBox(width: 8),
                    _quickPreset('10m', const Duration(minutes: 10)),
                    const SizedBox(width: 8),
                    _quickPreset('15m', const Duration(minutes: 15)),
                    const SizedBox(width: 8),
                    _quickPreset('30m', const Duration(minutes: 30)),
                  ],
                ),

                // Recents in modal
                if (widget.recentTimers.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  const Text('RECENTS',
                      style: TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
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
                                _formatDurationShort(
                                    widget.recentTimers[i]),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w300),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6C5CE7)
                                    .withValues(alpha: 0.2),
                                border: Border.all(
                                  color: const Color(0xFF6C5CE7)
                                      .withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Color(0xFFA29BFE), size: 22),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (i < widget.recentTimers.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child:
                            Divider(color: Color(0xFF1E1E2E), height: 1),
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
                      color: sel ? Colors.white : const Color(0xFF4A4A5A),
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
            style: const TextStyle(color: Color(0xFF6A6A7A), fontSize: 14,
                fontWeight: FontWeight.w400)),
      ],
    );
  }

  Widget _quickPreset(String label, Duration duration) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _setQuickTimer(duration),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: const Color(0xFF1A1A24),
            border: Border.all(color: const Color(0xFF2A2A3A), width: 1),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(color: Color(0xFFA29BFE),
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}