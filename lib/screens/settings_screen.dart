import 'package:flutter/material.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/config/app_config.dart';
import 'package:not_clock/config/sunrise_presets.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/theme_picker_screen.dart';
import 'package:not_clock/screens/app_icon_screen.dart';
import 'package:not_clock/screens/sunrise_settings_screen.dart';
import 'package:not_clock/screens/about_screen.dart';
import 'package:not_clock/screens/language_screen.dart';
import 'package:not_clock/services/app_links_service.dart';

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
        final t = AppLocalizations.of(context);

        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(colors: c, title: t.settingsTitle),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      _SectionLabel(t.sectionPersonalization, colors: c),
                      _Card(colors: c, children: [
                        _NavRow(
                          colors: c,
                          icon: Icons.palette_outlined,
                          title: t.themeAndColors,
                          // Flavour and accent names stay untranslated —
                          // Catppuccin's palette names are proper nouns.
                          subtitle:
                              '${settings.flavor.label} · ${settings.accent.label}',
                          trailing: _AccentDot(color: c.accent),
                          onTap: (_) => Navigator.push(
                            context,
                            _slideUp(ThemePickerScreen(settings: settings)),
                          ),
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.apps_rounded,
                          title: t.appIcon,
                          subtitle: AppIconOption.byId(settings.appIconId).label,
                          onTap: (_) => Navigator.push(
                            context,
                            _slideUp(AppIconScreen(settings: settings)),
                          ),
                        ),
                        _Divider(colors: c),
                        _ToggleRow(
                          colors: c,
                          icon: Icons.schedule_rounded,
                          title: t.twentyFourHourTime,
                          subtitle: settings.use24HourFormat
                              ? t.twentyFourHourOn
                              : t.twentyFourHourOff,
                          value: settings.use24HourFormat,
                          onChanged: (v) => settings.use24HourFormat = v,
                        ),
                      ]),

                      const SizedBox(height: 28),
                      _SectionLabel(t.sectionSleep, colors: c),
                      _Card(colors: c, children: [
                        _ToggleRow(
                          colors: c,
                          icon: Icons.nightlight_round,
                          title: t.nightClock,
                          subtitle: t.nightClockSubtitle,
                          value: settings.nightClockEnabled,
                          onChanged: (v) => settings.nightClockEnabled = v,
                        ),
                        _Divider(colors: c),
                        _ToggleRow(
                          colors: c,
                          icon: Icons.wb_twilight_rounded,
                          title: t.sunriseSimulator,
                          subtitle: t.sunriseSimulatorSubtitle,
                          value: settings.sunriseEnabled,
                          onChanged: (v) => settings.sunriseEnabled = v,
                        ),
                        if (settings.sunriseEnabled) ...[
                          _Divider(colors: c),
                          _NavRow(
                            colors: c,
                            icon: Icons.gradient_rounded,
                            title: t.sunriseSettings,
                            subtitle: t.sunriseSummary(
                              settings.sunriseWindowMinutes,
                              SunrisePreset.byId(settings.sunrisePresetId).name,
                            ),
                            onTap: (_) => Navigator.push(
                              context,
                              _slideUp(
                                  SunriseSettingsScreen(settings: settings)),
                            ),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 10),
                      _Note(colors: c, text: t.nightClockNote),

                      const SizedBox(height: 28),
                      _SectionLabel(t.sectionGeneral, colors: c),
                      _Card(colors: c, children: [
                        _NavRow(
                          colors: c,
                          icon: Icons.translate_rounded,
                          title: t.language,
                          subtitle: _languageLabel(settings, t),
                          onTap: (_) => Navigator.push(
                            context,
                            _slideUp(LanguageScreen(settings: settings)),
                          ),
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.mail_outline_rounded,
                          title: t.sendFeedback,
                          subtitle: t.sendFeedbackSubtitle,
                          onTap: AppLinksService.sendFeedback,
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.ios_share_rounded,
                          title: t.shareApp,
                          subtitle: t.shareAppSubtitle,
                          // rowContext, not the screen's — the iPad share
                          // popover anchors to the row that was tapped.
                          onTap: AppLinksService.shareApp,
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.star_outline_rounded,
                          title: t.rateApp,
                          subtitle: AppConfig.isIOS
                              ? t.rateAppSubtitleIos
                              : AppConfig.isAndroid
                                  ? t.rateAppSubtitleAndroid
                                  : t.rateAppSubtitleOther,
                          onTap: AppLinksService.rateApp,
                        ),
                        _Divider(colors: c),
                        _NavRow(
                          colors: c,
                          icon: Icons.info_outline_rounded,
                          title: t.about,
                          subtitle: t.versionShort(AppConfig.appVersion),
                          onTap: (_) => Navigator.push(
                            context,
                            _slideUp(AboutScreen(settings: settings)),
                          ),
                        ),
                      ]),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          t.appFooter(AppConfig.appName, AppConfig.appVersion),
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

  /// Language names are shown in their own language, never translated.
  String _languageLabel(AppSettings s, AppLocalizations t) {
    switch (s.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      default:
        return t.languageSystem;
    }
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

// `openSettingsScreen` and `SettingsGearButton` deliberately stay in main.dart,
// where your other screens already import them from. Defining them here too
// would make those imports ambiguous.

// ─── Shared building blocks (also used by the picker screens) ────────────────

class _Header extends StatelessWidget {
  final AppColors colors;
  final String title;
  const _Header({required this.colors, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          BackChip(colors: colors),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.text,
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
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

  /// Receives the row's own BuildContext. Needed for anything that has to
  /// anchor to the row itself, like the iPad share popover.
  final void Function(BuildContext rowContext) onTap;
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
      onTap: () => onTap(context),
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