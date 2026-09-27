import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/alarm_data.dart';
import 'package:not_clock/screens/alarm_sub/sound_picker.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/services/alarm_scheduler.dart';
import 'package:not_clock/services/storage_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Timers
//
//  Each running timer is handed to the OS through AlarmScheduler, so it rings
//  with the app backgrounded or closed — the same mechanism the alarms use.
//
//  The countdown on screen is NOT driven by subtracting from a counter every
//  tick. It's computed from a stored end time, so a timer that spent ten
//  minutes with the app suspended shows the correct value the moment you come
//  back, instead of being frozen ten minutes behind.
//
//  Running timers are persisted, so killing the app doesn't lose the cards
//  belonging to alarms the OS is still holding.
// ─────────────────────────────────────────────────────────────────────────────

// ─── Timer Data Model ─────────────────────────────────────────────────────────

class _TimerData {
  /// Slot 0–999. Maps to a fixed platform alarm id, so the OS alarm and this
  /// card stay associated across restarts.
  final int index;

  String label;
  Duration totalDuration;

  /// Wall-clock moment this timer reaches zero. Null while paused.
  DateTime? endsAt;

  /// What was left when it was paused. Only meaningful while [endsAt] is null.
  Duration pausedRemaining;

  bool isFinished;

  _TimerData({
    required this.index,
    required this.label,
    required this.totalDuration,
    this.endsAt,
    Duration? pausedRemaining,
    this.isFinished = false,
  }) : pausedRemaining = pausedRemaining ?? totalDuration;

  bool get isRunning => endsAt != null && !isFinished;
  bool get isPaused => endsAt == null && !isFinished;

  Duration get remaining {
    if (isFinished) return Duration.zero;
    if (endsAt == null) return pausedRemaining;
    final left = endsAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0;
    if (isFinished) return 1;
    return 1.0 - (remaining.inMilliseconds / totalDuration.inMilliseconds);
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'label': label,
        'total': totalDuration.inSeconds,
        'endsAt': endsAt?.millisecondsSinceEpoch,
        'paused': pausedRemaining.inSeconds,
        'finished': isFinished,
      };

  factory _TimerData.fromJson(Map<String, dynamic> json) {
    final endsAtMs = json['endsAt'] as int?;
    return _TimerData(
      index: json['index'] as int,
      label: json['label'] as String? ?? '',
      totalDuration: Duration(seconds: json['total'] as int? ?? 0),
      endsAt:
          endsAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(endsAtMs),
      pausedRemaining: Duration(seconds: json['paused'] as int? ?? 0),
      isFinished: json['finished'] as bool? ?? false,
    );
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

class _TimersScreenState extends State<TimersScreen>
    with WidgetsBindingObserver {
  static const String _kRunningTimers = 'timers_running';

  /// A finished timer rings until someone stops it. Cap it while the app is
  /// alive so a forgotten timer doesn't ring indefinitely. With the app
  /// suspended nothing here runs, and it's the notification's Stop button —
  /// or a swipe on Android — that silences it.
  static const Duration _maxRingTime = Duration(seconds: 90);

  final List<_TimerData> _timers = [];
  final List<Duration> _recentTimers = [];

  /// Auto-stop timers for anything currently ringing, keyed by slot index.
  final Map<int, Timer> _ringCutoffs = {};

  /// One ticker repaints every card. Each card computes its own remaining
  /// time from its end time, so this only drives the display.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AlarmScheduler.timerHandler = _onTimerFired;
    _loadRecents();
    _loadRunningTimers();
    _ticker = Timer.periodic(
        const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AlarmScheduler.timerHandler = null;
    _ticker?.cancel();
    for (final t in _ringCutoffs.values) {
      t.cancel();
    }
    // Deliberately NOT stopping the platform alarms here. A timer outlives
    // this screen now — that's the whole point of scheduling it with the OS.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background: recompute everything from wall-clock
    // time so cards that finished while we were suspended show as done.
    if (state == AppLifecycleState.resumed) _tick();
  }

  // ─── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadRecents() async {
    final saved = await StorageService.loadRecentTimers();
    if (saved.isNotEmpty && mounted) {
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

  /// Running timers use SharedPreferences directly rather than
  /// StorageService — they're this screen's private state, and adding a
  /// method to the shared service for one caller isn't worth it.
  Future<void> _saveRunningTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kRunningTimers,
        jsonEncode(_timers.map((t) => t.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _loadRunningTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kRunningTimers);
      if (raw == null) return;

      final decoded = (jsonDecode(raw) as List)
          .map((e) => _TimerData.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      setState(() => _timers.addAll(decoded));
      _tick(); // mark anything that ran out while the app was gone
    } catch (_) {}
  }

  // ─── Slot allocation ───────────────────────────────────────────────────────

  /// Lowest index not already taken. The platform alarm id is derived from
  /// this, so reusing a live one would overwrite someone else's timer.
  int _nextFreeIndex() {
    final used = _timers.map((t) => t.index).toSet();
    for (int i = 0; i < 1000; i++) {
      if (!used.contains(i)) return i;
    }
    return 0; // 1000 concurrent timers; something has gone very wrong
  }

  // ─── Ticking ───────────────────────────────────────────────────────────────

  void _tick() {
    if (!mounted) return;

    // Nothing running means the inline picker is on screen. Rebuilding it five
    // times a second is both wasteful and destructive — the picker's wheels
    // reset on every rebuild, which is why it sat locked at 5 minutes.
    if (_timers.isEmpty) return;

    var changed = false;
    for (final data in _timers) {
      if (data.isRunning && data.remaining == Duration.zero) {
        data.isFinished = true;
        data.endsAt = null;
        _startRingCutoff(data.index);
        changed = true;
      }
    }

    setState(() {}); // repaint the countdowns
    if (changed) _saveRunningTimers();
  }

  /// The platform told us a timer went off. Usually the ticker has already
  /// noticed, but this catches the case where the app was resumed by the
  /// notification itself.
  _TimerData? _timerAt(int index) {
    for (final t in _timers) {
      if (t.index == index) return t;
    }
    return null;
  }

  void _onTimerFired(int index) {
    if (!mounted) return;

    // Held in a final local: Dart won't carry a null check into a closure for
    // a variable that gets reassigned, so setState below would still see this
    // as nullable if it were a loop variable.
    final data = _timerAt(index);

    if (data == null) {
      // Card is gone but the OS still has the alarm — silence it.
      AlarmScheduler.stopTimer(index);
      return;
    }

    setState(() {
      data.isFinished = true;
      data.endsAt = null;
    });
    _startRingCutoff(index);
    _saveRunningTimers();
  }

  void _startRingCutoff(int index) {
    _ringCutoffs[index]?.cancel();
    _ringCutoffs[index] = Timer(_maxRingTime, () {
      AlarmScheduler.stopTimer(index);
      _ringCutoffs.remove(index);
    });
  }

  void _clearRingCutoff(int index) {
    _ringCutoffs.remove(index)?.cancel();
  }

  // ─── Timer lifecycle ───────────────────────────────────────────────────────

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

  Future<void> _startTimerFromDuration(Duration duration) async {
    if (duration <= Duration.zero) return;

    final data = _TimerData(
      index: _nextFreeIndex(),
      label: formatDurationShort(duration),
      totalDuration: duration,
      endsAt: DateTime.now().add(duration),
    );

    _addToRecents(duration);
    setState(() => _timers.insert(0, data));

    await _schedule(data);
    await _saveRunningTimers();
  }

  /// Hand a running timer to the OS.
  Future<void> _schedule(_TimerData data) async {
    final endsAt = data.endsAt;
    if (endsAt == null) return;
    await AlarmScheduler.scheduleTimer(
      index: data.index,
      at: endsAt,
      label: data.label,
      sound: SettingsProvider.read(context).timerSound,
    );
  }

  Future<void> _pauseTimer(_TimerData data) async {
    setState(() {
      data.pausedRemaining = data.remaining;
      data.endsAt = null;
    });
    await AlarmScheduler.stopTimer(data.index);
    await _saveRunningTimers();
  }

  Future<void> _resumeTimer(_TimerData data) async {
    setState(() {
      data.endsAt = DateTime.now().add(data.pausedRemaining);
      data.isFinished = false;
    });
    await _schedule(data);
    await _saveRunningTimers();
  }

  Future<void> _cancelTimer(_TimerData data) async {
    _clearRingCutoff(data.index);
    setState(() => _timers.remove(data));
    await AlarmScheduler.stopTimer(data.index);
    await _saveRunningTimers();
  }

  Future<void> _restartTimer(_TimerData data) async {
    _clearRingCutoff(data.index);
    // Stop the ring before rescheduling — the platform refuses a set() and a
    // stop() racing on the same id.
    await AlarmScheduler.stopTimer(data.index);
    if (!mounted) return;
    setState(() {
      data.isFinished = false;
      data.pausedRemaining = data.totalDuration;
      data.endsAt = DateTime.now().add(data.totalDuration);
    });
    await _schedule(data);
    await _saveRunningTimers();
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

    if (result != null) await _startTimerFromDuration(result);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

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
              value: data.progress.clamp(0.0, 1.0),
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

  // No didUpdateWidget reset here on purpose.
  //
  // It used to snap the wheels back to 0:05:00 whenever the parent rebuilt,
  // which was rare before and is constant now that a ticker drives the screen.
  // It isn't needed either: this view only exists while no timers are running,
  // so starting one destroys it and finishing the last one builds a fresh
  // State with the defaults already set.

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