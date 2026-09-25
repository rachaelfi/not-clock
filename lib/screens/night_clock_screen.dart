import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/config/sunrise_presets.dart';
import 'package:not_clock/services/brightness_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Night Clock
//
//  While the alarm is pending the sky is always night, whatever the hour — you
//  set a sleep alarm to go to sleep, so daylight would be wrong even at 2 PM.
//
//  Once the alarm fires, the sky becomes whatever the clock calls for:
//    19:00 – 03:59  starry night
//    04:00 – 07:59  sunrise
//    08:00 – 18:59  blue sky
//
//  If the sunrise simulator is on, the last 5–30 minutes before the alarm
//  override all of that: the screen walks through the chosen colour preset and
//  ramps the backlight from near-dark to full, hitting white as the alarm
//  sounds.
//
//  Text and controls pick white or near-black by sampling the sky at their own
//  vertical position, so they stay readable through all of it.
// ─────────────────────────────────────────────────────────────────────────────

enum SkyPhase { night, sunrise, day }

/// Which sky the clock time alone implies. Only consulted once the alarm has
/// fired — before that the screen is night, or the sunrise simulation.
SkyPhase skyPhaseFor(DateTime t) {
  final h = t.hour;
  if (h >= 19 || h < 4) return SkyPhase.night; // 7 PM – 3:59 AM
  if (h < 8) return SkyPhase.sunrise;          // 4 AM – 7:59 AM
  return SkyPhase.day;                         // 8 AM – 6:59 PM
}

const _skyGradients = <SkyPhase, List<Color>>{
  SkyPhase.night: [
    Color(0xFF05060F),
    Color(0xFF0B1026),
    Color(0xFF151B3D),
    Color(0xFF1E1638),
  ],
  SkyPhase.sunrise: [
    Color(0xFF17285C),
    Color(0xFF5A4A82),
    Color(0xFFC9707A),
    Color(0xFFF0A868),
    Color(0xFFF9D9A8),
  ],
  SkyPhase.day: [
    Color(0xFF2F7FD1),
    Color(0xFF64AEE4),
    Color(0xFFA8D8F0),
    Color(0xFFD7EDF9),
  ],
};

/// Sunrise-only mode's pending sky — plain and dark, no starfield.
const _plainNightSky = <Color>[
  Color(0xFF05060F),
  Color(0xFF08090F),
  Color(0xFF0B0C12),
];

/// The colour of [stops] at vertical fraction [t] (0 = top, 1 = bottom).
Color _colorAtDepth(List<Color> stops, double t) {
  final scaled = t.clamp(0.0, 1.0) * (stops.length - 1);
  final i = scaled.floor().clamp(0, stops.length - 2);
  return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
}

/// Near-black on a pale sky, white on a dark one.
Color _inkOn(Color sky) =>
    sky.computeLuminance() > 0.45 ? const Color(0xFF12212E) : Colors.white;

/// A shadow that lifts [ink] off whatever is behind it.
List<Shadow> _shadowFor(Color ink) => [
      Shadow(
        color: ink == Colors.white
            ? const Color(0x66000000)
            : const Color(0x59FFFFFF),
        blurRadius: 14,
        offset: const Offset(0, 2),
      ),
    ];

class NightClockScreen extends StatefulWidget {
  final AppSettings settings;

  /// When the sleep alarm is due. Once this passes, the greeting appears.
  final DateTime? alarmTime;

  /// Called when the user taps Stop. The sleep screen cancels the alarm here.
  final VoidCallback? onStop;

  /// Called when the user picks a new time from the night clock itself.
  final ValueChanged<DateTime>? onAlarmChanged;

  /// Whether to draw the star field while the alarm is pending. False when the Night Clock setting is off
  /// and this screen exists only to run the sunrise — then the pending sky stays plain black.
  final bool showStars;

  const NightClockScreen({
    super.key,
    required this.settings,
    this.alarmTime,
    this.onStop,
    this.onAlarmChanged,
    this.showStars = true,
  });

  @override
  State<NightClockScreen> createState() => _NightClockScreenState();
}

class _NightClockScreenState extends State<NightClockScreen>
    with TickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final AnimationController _shooting;
  late final AnimationController _drift;

  Timer? _clockTimer;
  Timer? _dimTimer;
  Timer? _shootingScheduler;

  DateTime _now = DateTime.now();
  DateTime? _alarmTime;
  bool _dimmed = false;
  bool _alarmFired = false;

  final _rng = math.Random();
  late final List<_Star> _stars;
  late final List<_Cloud> _clouds;
  _ShootingStar? _shot;

  static const _dimAfter = Duration(seconds: 12);

  // Where the clock block and the Stop button sit vertically, used to sample
  // the sky for contrast.
  static const _clockDepth = 0.34;
  static const _buttonDepth = 0.92;

  /// Stars until the alarm goes off, whatever the hour. Once it fires, the sky
  /// switches to whatever the actual time calls for.
  SkyPhase get _phase => _alarmFired ? skyPhaseFor(_now) : SkyPhase.night;

  // ─── Sunrise simulation ────────────────────────────────────────────────────

  SunrisePreset get _preset =>
      SunrisePreset.byId(widget.settings.sunrisePresetId);

  /// How far through the wake-up window we are: 0 at the start, 1 at alarm
  /// time. Null when the sunrise isn't running — switched off, no alarm set,
  /// still outside the window, or the alarm has already fired.
  double? get _sunriseProgress {
    if (!widget.settings.sunriseEnabled) return null;
    if (_alarmTime == null || _alarmFired) return null;

    final window =
        Duration(minutes: widget.settings.sunriseWindowMinutes);
    final start = _alarmTime!.subtract(window);
    if (_now.isBefore(start)) return null;

    final total = window.inMilliseconds;
    if (total <= 0) return null;
    return (_now.difference(start).inMilliseconds / total).clamp(0.0, 1.0);
  }

  bool get _sunriseActive => _sunriseProgress != null;

  /// The sky currently on screen, top to bottom.
  ///
  /// During the sunrise this is built from the preset: near-black at the top
  /// early on, opening up to the full colour as the window progresses, so the
  /// light grows from a glow at the horizon into the whole screen.
    List<Color> get _skyStops {
    final p = _sunriseProgress;
    if (p != null) {
      final glow = _preset.colorAt(p);
      final top = Color.lerp(Colors.black, glow, 0.12 + 0.88 * p)!;
      final middle = Color.lerp(top, glow, 0.55)!;
      return [top, middle, glow];
    }

    // Nothing to look at before the light starts, so don't borrow the
    // starfield's sky when there's no starfield.
    if (!widget.showStars && !_alarmFired) return _plainNightSky;

    return _skyGradients[_phase]!;
  }

  /// Backlight level for the current point in the sunrise.
  ///
  /// Eased rather than linear: a straight ramp spends too long at a level
  /// that's already bright enough to wake you early. easeInCubic keeps it dim
  /// for most of the window and does the real work near the end.
  double _brightnessFor(double progress) =>
      0.02 + 0.98 * Curves.easeInCubic.transform(progress);

  @override
  void initState() {
    super.initState();

    _alarmTime = widget.alarmTime;

    // Fixed seed so the sky doesn't reshuffle on every rebuild.
    final seeded = math.Random(20260909);
    _stars = List.generate(150, (_) => _Star.random(seeded));
    _clouds = List.generate(6, (_) => _Cloud.random(seeded));

    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _shooting = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();

    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    _scheduleShootingStar();
    _restartDimTimer();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // If you add `wakelock_plus` to pubspec, keep the display on here:
    //   WakelockPlus.enable();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _dimTimer?.cancel();
    _shootingScheduler?.cancel();
    _twinkle.dispose();
    _shooting.dispose();
    _drift.dispose();
    // Always hand the backlight back, or the phone stays at whatever level
    // the sunrise left it on.
    BrightnessService.restore();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // WakelockPlus.disable();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final fired = _alarmTime != null && !now.isBefore(_alarmTime!);

    setState(() {
      _now = now;
      if (fired && !_alarmFired) {
        _alarmFired = true;
        _dimmed = false; // don't sleep through the greeting
        _dimTimer?.cancel();
      }
    });

    // Drive the backlight. Writes below a 1% change are dropped inside the
    // service, so most ticks cost nothing.
    final p = _sunriseProgress;
    if (p != null) {
      if (_dimmed) setState(() => _dimmed = false);
      BrightnessService.set(_brightnessFor(p));
    } else if (_alarmFired) {
      BrightnessService.restore();
    }
  }

  void _restartDimTimer() {
    _dimTimer?.cancel();
    // Never dim mid-sunrise — the whole point is the screen getting brighter.
    if (_alarmFired || _sunriseActive) return;
    _dimTimer = Timer(_dimAfter, () {
      if (mounted) setState(() => _dimmed = true);
    });
  }

  void _wake() {
    if (_dimmed) setState(() => _dimmed = false);
    _restartDimTimer();
  }

  /// Stop cancels the sleep alarm as well as closing the screen, so the user
  /// has to press Set Sleep Alarm again to bring the night clock back.
  void _stop() {
    BrightnessService.restore();
    widget.onStop?.call();
    Navigator.of(context).pop();
  }

  /// Fire a streak every 9–22 seconds, but only under an actual night sky.
  void _scheduleShootingStar() {
    final delay = Duration(milliseconds: 9000 + _rng.nextInt(13000));
    _shootingScheduler = Timer(delay, () {
      if (!mounted) return;
      if (widget.showStars && _phase == SkyPhase.night && !_sunriseActive) {
        setState(() => _shot = _ShootingStar.random(_rng));
        _shooting.forward(from: 0);
      }
      _scheduleShootingStar();
    });
  }

  Future<void> _editAlarm() async {
    _dimTimer?.cancel(); // don't dim out from under the picker

    final base = _alarmTime ?? DateTime.now().add(const Duration(hours: 8));
    final result = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          _AlarmTimeSheet(settings: widget.settings, initial: base),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _alarmTime = result;
        // A new alarm in the future clears an already-fired greeting.
        _alarmFired = !DateTime.now().isBefore(result);
      });
      widget.onAlarmChanged?.call(result);
    }

    _wake();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _phase;
    final size = MediaQuery.sizeOf(context);
    final sunrise = _sunriseProgress;
    final stops = _skyStops;

    final clockInk = _inkOn(_colorAtDepth(stops, _clockDepth));
    final buttonInk = _inkOn(_colorAtDepth(stops, _buttonDepth));

    // Stars linger into the first part of the sunrise, then fade as the light
    // builds — the way real ones do.
    final starOpacity = sunrise == null
        ? 1.0
        : (1.0 - sunrise * 2.2).clamp(0.0, 1.0);
        final showStars = widget.showStars && phase == SkyPhase.night && starOpacity > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _wake,
        onPanDown: (_) => _wake(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Sky. Cross-fades on phase change; follows the sunrise second
            //    by second while that's running.
            AnimatedContainer(
              duration: Duration(milliseconds: sunrise == null ? 1200 : 900),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: stops,
                ),
              ),
            ),

            // 2. Sunrise glow rising from the horizon.
            if (sunrise != null)
              CustomPaint(
                size: size,
                painter: _SunriseGlowPainter(
                  progress: sunrise,
                  color: _preset.colorAt(sunrise),
                ),
              ),

            // 3. Stars + shooting star.
            if (showStars)
              AnimatedBuilder(
                animation: Listenable.merge([_twinkle, _shooting]),
                builder: (context, _) => Opacity(
                  opacity: starOpacity,
                  child: CustomPaint(
                    size: size,
                    painter: _StarPainter(
                      stars: _stars,
                      twinkle: _twinkle.value,
                      shot: _shot,
                      shotProgress:
                          _shooting.isAnimating ? _shooting.value : null,
                    ),
                  ),
                ),
              ),

            // 4. Sun and drifting clouds, after the alarm on a daytime sky.
            if (phase != SkyPhase.night && sunrise == null)
              AnimatedBuilder(
                animation: _drift,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _DaytimePainter(
                    clouds: _clouds,
                    drift: _drift.value,
                    phase: phase,
                  ),
                ),
              ),

            // 5. Clock, alarm row, Stop button.
            SafeArea(
              child: AnimatedOpacity(
                opacity: _dimmed ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 700),
                child: _ClockFace(
                  now: _now,
                  use24Hour: widget.settings.use24HourFormat,
                  alarmTime: _alarmTime,
                  alarmFired: _alarmFired,
                  clockInk: clockInk,
                  buttonInk: buttonInk,
                  onStop: _stop,
                  onEditAlarm: _editAlarm,
                ),
              ),
            ),

            // 6. Dimming veil. A sliver of sky stays visible so the phone
            //    doesn't look switched off.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _dimmed ? 0.94 : 0.0,
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
                child: Container(color: Colors.black),
              ),
            ),

            // 7. A faint clock that survives the dim. Always white — the veil
            //    is black whatever the sky was.
            if (_dimmed)
              IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _dimmed ? 0.16 : 0.0,
                    duration: const Duration(milliseconds: 1400),
                    child: Text(
                      _formatTime(_now, widget.settings.use24HourFormat),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w200,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sunrise glow ────────────────────────────────────────────────────────────

/// A soft pool of light at the bottom of the screen that grows through the
/// wake-up window, so the sunrise reads as light arriving rather than the
/// whole screen simply changing colour.
class _SunriseGlowPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SunriseGlowPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * (1.02 - 0.18 * progress));
    final radius = size.width * (0.35 + 0.95 * progress);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.55 * (0.35 + 0.65 * progress)),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_SunriseGlowPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Clock face ──────────────────────────────────────────────────────────────

class _ClockFace extends StatelessWidget {
  final DateTime now;
  final bool use24Hour;
  final DateTime? alarmTime;
  final bool alarmFired;
  final Color clockInk;
  final Color buttonInk;
  final VoidCallback onStop;
  final VoidCallback onEditAlarm;

  const _ClockFace({
    required this.now,
    required this.use24Hour,
    required this.alarmTime,
    required this.alarmFired,
    required this.clockInk,
    required this.buttonInk,
    required this.onStop,
    required this.onEditAlarm,
  });

  @override
  Widget build(BuildContext context) {
    final clockShadow = _shadowFor(clockInk);

    return Column(
      children: [
        const Spacer(flex: 3),
        Text(
          _formatTime(now, use24Hour),
          style: TextStyle(
            color: clockInk,
            fontSize: 82,
            fontWeight: FontWeight.w200,
            letterSpacing: -3,
            height: 1.0,
            shadows: clockShadow,
          ),
        ),
        const SizedBox(height: 10),
        if (alarmFired)
          Text(
            'Good morning!',
            style: TextStyle(
              color: clockInk,
              fontSize: 26,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
              shadows: clockShadow,
            ),
          )
        else
          Text(
            _dateLine(now),
            style: TextStyle(
              color: clockInk.withValues(alpha: 0.75),
              fontSize: 16,
              fontWeight: FontWeight.w400,
              shadows: clockShadow,
            ),
          ),

        // Tappable alarm row — opens the half-height picker.
        if (!alarmFired) ...[
          const SizedBox(height: 26),
          GestureDetector(
            onTap: onEditAlarm,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: clockInk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: clockInk.withValues(alpha: 0.28), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm,
                      size: 16, color: clockInk.withValues(alpha: 0.85)),
                  const SizedBox(width: 8),
                  Text(
                    alarmTime == null
                        ? 'Set alarm'
                        : _formatTime(alarmTime!, use24Hour),
                    style: TextStyle(
                      color: clockInk.withValues(alpha: 0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_outlined,
                      size: 14, color: clockInk.withValues(alpha: 0.6)),
                ],
              ),
            ),
          ),
        ],

        const Spacer(flex: 4),

        Padding(
          padding: const EdgeInsets.only(bottom: 44),
          child: GestureDetector(
            onTap: onStop,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 46, vertical: 14),
              decoration: BoxDecoration(
                color: buttonInk.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                    color: buttonInk.withValues(alpha: 0.45), width: 1.4),
              ),
              child: Text(
                'Stop',
                style: TextStyle(
                  color: buttonInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  shadows: _shadowFor(buttonInk),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Half-height alarm picker ────────────────────────────────────────────────

/// Bottom sheet covering the lower half of the screen, with Cancel and Done.
/// Minutes step by 5 to match the sleep screen's wheel.
class _AlarmTimeSheet extends StatefulWidget {
  final AppSettings settings;
  final DateTime initial;

  const _AlarmTimeSheet({required this.settings, required this.initial});

  @override
  State<_AlarmTimeSheet> createState() => _AlarmTimeSheetState();
}

class _AlarmTimeSheetState extends State<_AlarmTimeSheet> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _amPmController;

  late int _hour; // 1–12, or 0–23 in 24-hour mode
  late int _minuteIndex; // 0–11, five minutes apart
  late bool _isAM;

  bool get _is24h => widget.settings.use24HourFormat;

  int get _hour24 {
    if (_is24h) return _hour;
    var h = _hour;
    if (_isAM && _hour == 12) h = 0;
    if (!_isAM && _hour != 12) h = _hour + 12;
    return h;
  }

  @override
  void initState() {
    super.initState();

    final h24 = widget.initial.hour;
    _isAM = h24 < 12;
    if (_is24h) {
      _hour = h24;
    } else {
      _hour = h24 % 12 == 0 ? 12 : h24 % 12;
    }
    _minuteIndex = (widget.initial.minute ~/ 5).clamp(0, 11);

    _hourController = FixedExtentScrollController(
        initialItem: _is24h ? _hour : _hour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minuteIndex);
    _amPmController = FixedExtentScrollController(initialItem: _isAM ? 0 : 1);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _amPmController.dispose();
    super.dispose();
  }

  /// Resolve to the next occurrence of the chosen time.
  DateTime get _result {
    final now = DateTime.now();
    var t = DateTime(
        now.year, now.month, now.day, _hour24, _minuteIndex * 5);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  String get _durationHint {
    final d = _result.difference(DateTime.now());
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h h ${m.toString().padLeft(2, '0')} min from now';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.settings.colors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Text('Cancel',
                        style: TextStyle(
                            color: c.subtext,
                            fontSize: 16,
                            fontWeight: FontWeight.w400)),
                  ),
                  Text('Wake up at',
                      style: TextStyle(
                          color: c.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, _result),
                    behavior: HitTestBehavior.opaque,
                    child: Text('Done',
                        style: TextStyle(
                            color: c.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: c.accentWash(0.1),
                      border:
                          Border.all(color: c.accentWash(0.3), width: 1),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 76,
                        height: 190,
                        child: _is24h ? _hourWheel24() : _hourWheel12(),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(':',
                            style: TextStyle(
                                color: c.accent,
                                fontSize: 30,
                                fontWeight: FontWeight.w300)),
                      ),
                      SizedBox(
                          width: 76, height: 190, child: _minuteWheel()),
                      if (!_is24h) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                            width: 58, height: 190, child: _amPmWheel()),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(_durationHint,
                  style: TextStyle(color: c.subtext, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheelText(String label, bool selected, {bool accent = false}) {
    final c = widget.settings.colors;
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: selected ? (accent ? c.accentSoft : c.text) : c.muted,
          fontSize: selected ? (accent ? 20 : 30) : (accent ? 16 : 23),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w300,
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
    required Widget Function(int index) itemBuilder,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.5,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= count) return null;
          return itemBuilder(index);
        },
        childCount: count,
      ),
    );
  }

  Widget _hourWheel24() => _wheel(
        controller: _hourController,
        count: 24,
        onChanged: (i) => setState(() => _hour = i),
        itemBuilder: (i) =>
            _wheelText(i.toString().padLeft(2, '0'), i == _hour),
      );

  Widget _hourWheel12() => _wheel(
        controller: _hourController,
        count: 12,
        onChanged: (i) => setState(() => _hour = i + 1),
        itemBuilder: (i) => _wheelText('${i + 1}', i + 1 == _hour),
      );

  Widget _minuteWheel() => _wheel(
        controller: _minuteController,
        count: 12,
        onChanged: (i) => setState(() => _minuteIndex = i),
        itemBuilder: (i) => _wheelText(
            (i * 5).toString().padLeft(2, '0'), i == _minuteIndex),
      );

  Widget _amPmWheel() => _wheel(
        controller: _amPmController,
        count: 2,
        onChanged: (i) => setState(() => _isAM = i == 0),
        itemBuilder: (i) => _wheelText(
            i == 0 ? 'AM' : 'PM', (i == 0) == _isAM,
            accent: true),
      );
}

// ─── Formatting ──────────────────────────────────────────────────────────────

String _formatTime(DateTime t, bool use24Hour) {
  if (use24Hour) {
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'AM' : 'PM';
  return '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
}

String _dateLine(DateTime t) {
  const days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${days[t.weekday - 1]}, ${months[t.month - 1]} ${t.day}';
}

// ─── Star field ──────────────────────────────────────────────────────────────

class _Star {
  final double x, y, radius, phase, speed;
  const _Star(this.x, this.y, this.radius, this.phase, this.speed);

  factory _Star.random(math.Random r) => _Star(
        r.nextDouble(),
        r.nextDouble() * 0.85,
        0.5 + r.nextDouble() * 1.5,
        r.nextDouble(),
        0.6 + r.nextDouble() * 1.6,
      );
}

class _ShootingStar {
  final double startX, startY, angle, length;
  const _ShootingStar(this.startX, this.startY, this.angle, this.length);

  factory _ShootingStar.random(math.Random r) => _ShootingStar(
        0.05 + r.nextDouble() * 0.55,
        0.04 + r.nextDouble() * 0.32,
        0.35 + r.nextDouble() * 0.35, // radians, down and to the right
        0.34 + r.nextDouble() * 0.26,
      );
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double twinkle;
  final _ShootingStar? shot;
  final double? shotProgress;

  _StarPainter({
    required this.stars,
    required this.twinkle,
    this.shot,
    this.shotProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final s in stars) {
      // Each star breathes on its own offset so the field shimmers unevenly.
      final t = (twinkle * s.speed + s.phase) % 1.0;
      final brightness = 0.28 + 0.72 * (0.5 + 0.5 * math.sin(t * 2 * math.pi));
      paint.color = Colors.white.withValues(alpha: brightness);

      final center = Offset(s.x * size.width, s.y * size.height);
      canvas.drawCircle(center, s.radius, paint);

      // The biggest stars get a soft halo.
      if (s.radius > 1.6) {
        canvas.drawCircle(
          center,
          s.radius * 2.8,
          Paint()
            ..color = Colors.white.withValues(alpha: brightness * 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    if (shot != null && shotProgress != null) {
      _paintShootingStar(canvas, size, shot!, shotProgress!);
    }
  }

  void _paintShootingStar(
      Canvas canvas, Size size, _ShootingStar s, double p) {
    // Fade in over the first fifth, out over the last third.
    final fade = p < 0.2 ? p / 0.2 : (p > 0.65 ? (1 - p) / 0.35 : 1.0);
    if (fade <= 0) return;

    final travel = s.length * size.width * 1.6;
    final dx = math.cos(s.angle) * travel;
    final dy = math.sin(s.angle) * travel;

    final origin = Offset(s.startX * size.width, s.startY * size.height);
    final head = origin + Offset(dx * p, dy * p);
    final tailLength = s.length * size.width * 0.55;
    final tail = head -
        Offset(math.cos(s.angle) * tailLength, math.sin(s.angle) * tailLength);

    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.9 * fade),
          ],
        ).createShader(Rect.fromPoints(tail, head)),
    );

    canvas.drawCircle(
      head,
      2.4,
      Paint()
        ..color = Colors.white.withValues(alpha: fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) =>
      old.twinkle != twinkle ||
      old.shotProgress != shotProgress ||
      old.shot != shot;
}

// ─── Sun and clouds ──────────────────────────────────────────────────────────

class _Cloud {
  final double x, y, scale, speed, opacity;
  const _Cloud(this.x, this.y, this.scale, this.speed, this.opacity);

  factory _Cloud.random(math.Random r) => _Cloud(
        r.nextDouble(),
        0.08 + r.nextDouble() * 0.5,
        0.55 + r.nextDouble() * 0.9,
        0.25 + r.nextDouble() * 0.75,
        0.5 + r.nextDouble() * 0.4,
      );
}

class _DaytimePainter extends CustomPainter {
  final List<_Cloud> clouds;
  final double drift;
  final SkyPhase phase;

  _DaytimePainter({
    required this.clouds,
    required this.drift,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintSun(canvas, size);

    for (final c in clouds) {
      // Wrap around the screen with a margin so clouds enter and exit cleanly.
      const span = 1.4;
      final x = ((c.x + drift * c.speed) % span - 0.2) * size.width;
      _paintCloud(
        canvas,
        Offset(x, c.y * size.height),
        c.scale * size.width * 0.16,
        c.opacity * (phase == SkyPhase.sunrise ? 0.7 : 1.0),
      );
    }
  }

  void _paintSun(Canvas canvas, Size size) {
    // Sitting low at sunrise, high at midday.
    final center = phase == SkyPhase.sunrise
        ? Offset(size.width * 0.5, size.height * 0.78)
        : Offset(size.width * 0.78, size.height * 0.16);

    final radius = size.width * (phase == SkyPhase.sunrise ? 0.17 : 0.09);
    final core = phase == SkyPhase.sunrise
        ? const Color(0xFFFFD9A0)
        : const Color(0xFFFFF4C4);

    canvas.drawCircle(
      center,
      radius * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            core.withValues(alpha: 0.55),
            core.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.6)),
    );

    canvas.drawCircle(center, radius, Paint()..color = core);
  }

  void _paintCloud(Canvas canvas, Offset at, double scale, double opacity) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity * 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Overlapping circles read as a soft cumulus without any asset.
    final blobs = <(double, double, double)>[
      (-0.55, 0.12, 0.42),
      (-0.18, -0.12, 0.55),
      (0.22, 0.02, 0.48),
      (0.58, 0.16, 0.34),
    ];

    for (final (dx, dy, r) in blobs) {
      canvas.drawCircle(
        at + Offset(dx * scale, dy * scale),
        r * scale,
        paint,
      );
    }

    // Flatten the underside so it sits like a cloud, not a cluster of dots.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: at + Offset(0, scale * 0.24),
          width: scale * 1.5,
          height: scale * 0.34,
        ),
        Radius.circular(scale * 0.17),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DaytimePainter old) =>
      old.drift != drift || old.phase != phase;
}

// ─── Entry point used by the sleep screen ────────────────────────────────────

/// Opens the night clock full-screen. Returns when the user taps Stop.
Future<void> openNightClock(
  BuildContext context, {
  DateTime? alarmTime,
  VoidCallback? onStop,
  ValueChanged<DateTime>? onAlarmChanged,
  bool showStars = true,
}) {
  final settings = SettingsProvider.read(context);
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, __, ___) => NightClockScreen(
        settings: settings,
        alarmTime: alarmTime,
        onStop: onStop,
        onAlarmChanged: onAlarmChanged,
        showStars: showStars,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ),
  );
}