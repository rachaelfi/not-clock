import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/theme_picker_screen.dart';
import 'package:not_clock/screens/app_icon_screen.dart';

class SettingsScreen extends StatelessWidget {
  final AppSettings settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // This screen lives on a pushed route, outside the SettingsProvider
    // rebuild scope, so it listens to the model directly.
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = settings.colors;

        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(colors: c),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _SectionLabel('Personalization', colors: c),
                      _Card(colors: c, children: [
                        _NavRow(
                          colors: c,
                          icon: Icons.palette_outlined,
                          title: 'Theme and colors',
                          subtitle:
                              '${settings.flavor.label} · ${settings.accent.label}',
                          trailing: _AccentDot(color: c.accent),
                          onTap: () => Navigator.push(
                            context,
                            _slideUp(ThemePickerScreen(settings: settings)),
                          ),
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.apps_rounded,
                          title: 'App icon',
                          subtitle: AppIconOption.byId(settings.appIconId).label,
                          onTap: () => Navigator.push(
                            context,
                            _slideUp(AppIconScreen(settings: settings)),
                          ),
                        ),
                        _Divider(colors: c),
                        _ToggleRow(
                          colors: c,
                          icon: Icons.schedule_rounded,
                          title: '24-hour time',
                          subtitle: settings.use24HourFormat
                              ? 'Clocks and pickers show 00–23'
                              : 'Clocks and pickers show AM and PM',
                          value: settings.use24HourFormat,
                          onChanged: (v) => settings.use24HourFormat = v,
                        ),
                      ]),

                      const SizedBox(height: 28),
                      _SectionLabel('Sleep', colors: c),
                      _Card(colors: c, children: [
                        _ToggleRow(
                          colors: c,
                          icon: Icons.nightlight_round,
                          title: 'Night Clock',
                          subtitle:
                              'Show a dimming clock with a night sky after you '
                              'set a sleep alarm',
                          value: settings.nightClockEnabled,
                          onChanged: (v) => settings.nightClockEnabled = v,
                        ),
                      ]),
                      const SizedBox(height: 10),
                      _Note(
                        colors: c,
                        text: 'The sky changes with the clock: stars from 7 PM, '
                            'sunrise from 4 AM, daylight from 6 AM.',
                      ),

                      const SizedBox(height: 28),
                      _SectionLabel('General', colors: c),
                      _Card(colors: c, children: [
                        _NavRow(
                          colors: c,
                          icon: Icons.mail_outline_rounded,
                          title: 'Send feedback',
                          onTap: () => _todo(context, c, 'Send feedback'),
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.ios_share_rounded,
                          title: 'Share app',
                          onTap: () => _todo(context, c, 'Share app'),
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.star_outline_rounded,
                          title: 'Rate app',
                          onTap: () => _todo(context, c, 'Rate app'),
                        ),
                      ]),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          'Not Clock 1.0.0',
                          style: TextStyle(color: c.muted, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _todo(BuildContext context, AppColors c, String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$what is not wired up yet.',
            style: TextStyle(color: c.text)),
        backgroundColor: c.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }
}

// ─── Route transition shared by the sub-screens ──────────────────────────────

Route<T> _slideUp<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
    transitionDuration: const Duration(milliseconds: 320),
  );
}

// ─── Shared building blocks (also used by the picker screens) ────────────────

class _Header extends StatelessWidget {
  final AppColors colors;
  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          BackChip(colors: colors),
          const SizedBox(width: 16),
          Text(
            'Settings',
            style: TextStyle(
              color: colors.text,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rounded back button used across settings screens.
class BackChip extends StatelessWidget {
  final AppColors colors;
  const BackChip({super.key, required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.accentWash(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.arrow_back_ios_new,
            color: colors.accentSoft, size: 18),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: colors.subtext,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final AppColors colors;
  const _Card({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  final AppColors colors;
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 60),
        child: Container(height: 1, color: colors.divider.withValues(alpha: 0.5)),
      );
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final AppColors colors;
  const _RowIcon(this.icon, {required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: colors.accentWash(0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: colors.accentSoft, size: 18),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final AppColors colors;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.colors,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: colors.accentWash(0.08),
      highlightColor: colors.accentWash(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _RowIcon(icon, colors: colors),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: colors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(color: colors.subtext, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[trailing!, const SizedBox(width: 10)],
            Icon(Icons.chevron_right_rounded, color: colors.muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppColors colors;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    required this.colors,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _RowIcon(icon, colors: colors),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          color: colors.subtext, fontSize: 13, height: 1.3)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Colors come from ThemeData.switchTheme in AppPalette.materialTheme,
          // so this stays correct across Flutter versions.
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Note({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(text,
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.4)),
      );
}

class _AccentDot extends StatelessWidget {
  final Color color;
  const _AccentDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

// `openSettingsScreen` and `SettingsGearButton` deliberately stay in main.dart,
// where your other screens already import them from. Defining them here too
// would make those imports ambiguous.