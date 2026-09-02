import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/screens/world_clock.dart';
import 'package:not_clock/screens/alarms.dart';
import 'package:not_clock/screens/sleep.dart';
import 'package:not_clock/screens/stopwatch.dart';
import 'package:not_clock/screens/timers.dart';
import 'package:not_clock/screens/settings_screen.dart';

void main() {
  runApp(const AlarmApp());
}

class AlarmApp extends StatefulWidget {
  const AlarmApp({super.key});

  @override
  State<AlarmApp> createState() => _AlarmAppState();
}

class _AlarmAppState extends State<AlarmApp> {
  final AppSettings _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    // Load saved settings from disk when app starts
    _settings.loadFromDisk();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsProvider(
      settings: _settings,
      child: MaterialApp(
        title: 'Not Clock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0A0A0F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF6C5CE7),
            secondary: Color(0xFFA29BFE),
            surface: Color(0xFF12121A),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

// ─── Inherited widget to provide AppSettings down the tree ────────────────────

class SettingsProvider extends InheritedNotifier<AppSettings> {
  const SettingsProvider({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    return provider!.notifier!;
  }
}

// ─── Helper to open settings from any screen ─────────────────────────────────

void openSettingsScreen(BuildContext context) {
  final settings = SettingsProvider.of(context);
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SettingsScreen(settings: settings),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 350),
    ),
  );
}

// ─── Reusable settings gear button ───────────────────────────────────────────

class SettingsGearButton extends StatelessWidget {
  const SettingsGearButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openSettingsScreen(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.settings_outlined,
            color: Color(0xFFA29BFE), size: 20),
      ),
    );
  }
}

// ─── Main Screen with Bottom Navigation ───────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Default to Sleep tab

  @override
  Widget build(BuildContext context) {
    // Listen so all tabs rebuild on settings change
    SettingsProvider.of(context);

    const screens = <Widget>[
      WorldClockScreen(),
      AlarmsScreen(),
      SleepScreen(),
      StopwatchScreen(),
      TimersScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12121A),
          border: Border(
            top: BorderSide(color: Color(0xFF1E1E2E), width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.language, 'World Clock', 0),
                _buildNavItem(Icons.alarm, 'Alarms', 1),
                _buildNavItem(Icons.bedtime_rounded, 'Sleep', 2),
                _buildNavItem(Icons.timer_outlined, 'Stopwatch', 3),
                _buildNavItem(Icons.hourglass_bottom_rounded, 'Timers', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color =
        isSelected ? const Color(0xFF6C5CE7) : const Color(0xFF4A4A5A);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}