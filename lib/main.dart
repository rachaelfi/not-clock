import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/world_clock.dart';
import 'package:not_clock/screens/alarms.dart';
import 'package:not_clock/screens/sleep.dart';
import 'package:not_clock/screens/stopwatch.dart';
import 'package:not_clock/screens/timers.dart';
import 'package:not_clock/screens/settings_screen.dart';
import 'package:not_clock/services/alarm_scheduler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:not_clock/l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlarmApp());
}

/// Global navigator key — allows the alarm scheduler to push screens
/// (like the firing screen) from outside the widget tree.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
    // Start the alarm scheduler — it checks every second if an alarm should fire
    AlarmScheduler.start(navigatorKey);
  }

  @override
  void dispose() {
    AlarmScheduler.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsProvider(
      settings: _settings,
      // ListenableBuilder sits INSIDE the provider so MaterialApp itself is
      // rebuilt when the theme changes. Without it, ThemeData keeps the colors
      // it was first built with and stock widgets (dialogs, switches, text
      // cursors) stay purple no matter what the user picks.
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) {
          return MaterialApp(
            title: 'Not Clock',
            debugShowCheckedModeBanner: false,
            // The navigator key lets AlarmScheduler push the firing screen
            navigatorKey: navigatorKey,
            theme: AppPalette.materialTheme(_settings.colors),
            locale: _settings.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const MainScreen(),
          );
        },
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

  /// Subscribes the calling widget to settings changes.
  static AppSettings of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    return provider!.notifier!;
  }

  /// Same lookup, but does NOT subscribe. Use inside onTap callbacks and
  /// initState, where creating a dependency is either useless or an error.
  static AppSettings read(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<SettingsProvider>();
    return provider!.notifier!;
  }

  /// Shorthand for the resolved palette.
  static AppColors colorsOf(BuildContext context) => of(context).colors;
}

// ─── Helper to open settings from any screen ─────────────────────────────────

void openSettingsScreen(BuildContext context) {
  final settings = SettingsProvider.read(context);
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
    final c = SettingsProvider.of(context).colors;
    return GestureDetector(
      onTap: () => openSettingsScreen(context),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.accentWash(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.settings_outlined, color: c.accentSoft, size: 20),
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
    final c = SettingsProvider.of(context).colors;

    const screens = <Widget>[
      WorldClockScreen(),
      AlarmsScreen(),
      SleepScreen(),
      StopwatchScreen(),
      TimersScreen(),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(
            top: BorderSide(color: c.divider, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(c, Icons.language, 'World Clock', 0),
                _buildNavItem(c, Icons.alarm, 'Alarms', 1),
                _buildNavItem(c, Icons.bedtime_rounded, 'Sleep', 2),
                _buildNavItem(c, Icons.timer_outlined, 'Stopwatch', 3),
                _buildNavItem(c, Icons.hourglass_bottom_rounded, 'Timers', 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(AppColors c, IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? c.accent : c.muted;

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