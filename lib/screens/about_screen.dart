import 'package:flutter/material.dart';
import 'package:not_clock/config/app_config.dart';
import 'package:not_clock/config/credits.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/app_icon_screen.dart';
import 'package:not_clock/screens/settings_screen.dart' show BackChip;
import 'package:not_clock/services/app_links_service.dart';

class AboutScreen extends StatelessWidget {
  final AppSettings settings;

  const AboutScreen({super.key, required this.settings});

  String get _versionLabel =>
      'Version ${AppConfig.appVersion} (${AppConfig.buildNumber})';

  /// "© 2026 Name" this year, "© 2026–2027 Name" from next year on.
  String get _copyright {
    final now = DateTime.now().year;
    final start = AppConfig.copyrightStartYear;
    final years = now > start ? '$start–$now' : '$start';
    final owner = AppConfig.developerName.isNotEmpty
        ? AppConfig.developerName
        : AppConfig.appName;
    return '© $years $owner';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = settings.colors;
        final icon = AppIconOption.byId(settings.appIconId);

        return Scaffold(
          backgroundColor: c.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      BackChip(colors: c),
                      const SizedBox(width: 16),
                      Text('About',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      // ── Identity ──
                      Center(child: _AppIconTile(option: icon, size: 84)),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(AppConfig.appName,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            )),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.accentWash(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_versionLabel,
                              style: TextStyle(
                                color: c.accentSoft,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(AppConfig.tagline,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: c.subtext, fontSize: 14)),
                      ),

                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(AppConfig.description,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 14.5,
                              height: 1.5,
                            )),
                      ),

                      // ── Links ──
                      const SizedBox(height: 28),
                      _SectionLabel('Links', colors: c),
                      _Card(colors: c, children: [
                        _LinkRow(
                          colors: c,
                          icon: Icons.language_rounded,
                          title: 'Website',
                          external: true,
                          onTap: () => AppLinksService.openUrl(
                              context, AppConfig.websiteUrl,
                              label: 'website'),
                        ),
                        _Divider(colors: c),
                        _LinkRow(
                          colors: c,
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          external: true,
                          onTap: () => AppLinksService.openUrl(
                              context, AppConfig.privacyPolicyUrl,
                              label: 'privacy policy'),
                        ),
                        _Divider(colors: c),
                        _LinkRow(
                          colors: c,
                          icon: Icons.description_outlined,
                          title: 'Terms of Use',
                          external: true,
                          onTap: () => AppLinksService.openUrl(
                              context, AppConfig.termsUrl,
                              label: 'terms of use'),
                        ),
                      ]),

                      // ── Credits ──
                      const SizedBox(height: 28),
                      _SectionLabel('Credits', colors: c),
                      _Card(colors: c, children: [
                        for (var i = 0; i < designCredits.length; i++) ...[
                          if (i > 0) _Divider(colors: c),
                          _CreditRow(
                              colors: c,
                              credit: designCredits[i],
                              icon: Icons.palette_outlined),
                        ],
                      ]),

                      // Appears automatically once soundCredits has entries.
                      if (soundCredits.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionLabel('Sounds', colors: c),
                        _Card(colors: c, children: [
                          for (var i = 0; i < soundCredits.length; i++) ...[
                            if (i > 0) _Divider(colors: c),
                            _CreditRow(
                                colors: c,
                                credit: soundCredits[i],
                                icon: Icons.music_note_outlined),
                          ],
                        ]),
                      ],

                      // ── Legal ──
                      const SizedBox(height: 28),
                      _SectionLabel('Legal', colors: c),
                      _Card(colors: c, children: [
                        _LinkRow(
                          colors: c,
                          icon: Icons.article_outlined,
                          title: 'Open-source licenses',
                          subtitle: 'Libraries this app is built with',
                          onTap: () => showLicensePage(
                            context: context,
                            applicationName: AppConfig.appName,
                            applicationVersion: _versionLabel,
                            applicationLegalese: _copyright,
                            applicationIcon: Padding(
                              padding: const EdgeInsets.all(12),
                              child: _AppIconTile(option: icon, size: 56),
                            ),
                          ),
                        ),
                      ]),

                      // ── Footer ──
                      const SizedBox(height: 32),
                      Center(
                        child: Text(_copyright,
                            style: TextStyle(color: c.muted, fontSize: 12)),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: Text('Made with Flutter',
                            style: TextStyle(color: c.muted, fontSize: 12)),
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
}

// ─── Pieces ──────────────────────────────────────────────────────────────────

/// The same tile as the app icon picker, so About shows whichever icon the
/// user chose.
class _AppIconTile extends StatelessWidget {
  final AppIconOption option;
  final double size;
  const _AppIconTile({required this.option, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [option.start, option.end],
        ),
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: option.start.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(Icons.access_time_rounded,
          color: option.glyph, size: size * 0.44),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _SectionLabel(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(text,
            style: TextStyle(
              color: colors.subtext,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            )),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final AppColors colors;
  const _Card({required this.children, required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  final AppColors colors;
  const _Divider({required this.colors});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 60),
        child: Container(
            height: 1, color: colors.divider.withValues(alpha: 0.5)),
      );
}

class _RowIcon extends StatelessWidget {
  final IconData icon;
  final AppColors colors;
  const _RowIcon(this.icon, {required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: colors.accentWash(0.16),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: colors.accentSoft, size: 18),
      );
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Leaves the app: shows an outward arrow instead of a chevron.
  final bool external;
  final VoidCallback onTap;
  final AppColors colors;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.colors,
    this.subtitle,
    this.external = false,
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
                        style:
                            TextStyle(color: colors.subtext, fontSize: 13)),
                  ],
                ],
              ),
            ),
            Icon(
              external
                  ? Icons.open_in_new_rounded
                  : Icons.chevron_right_rounded,
              color: colors.muted,
              size: external ? 18 : 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  final Credit credit;
  final IconData icon;
  final AppColors colors;

  const _CreditRow({
    required this.credit,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final detail = [
      credit.author,
      if (credit.license != null) credit.license!,
    ].join('  ·  ');

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _RowIcon(icon, colors: colors),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(credit.title,
                    style: TextStyle(
                        color: colors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(detail,
                    style: TextStyle(
                        color: colors.subtext, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          if (credit.url != null)
            Icon(Icons.open_in_new_rounded, color: colors.muted, size: 18),
        ],
      ),
    );

    if (credit.url == null) return row;

    return InkWell(
      onTap: () => AppLinksService.openUrl(context, credit.url!,
          label: credit.title),
      splashColor: colors.accentWash(0.08),
      highlightColor: colors.accentWash(0.05),
      child: row,
    );
  }
}