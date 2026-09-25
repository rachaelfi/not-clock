import 'package:flutter/material.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/settings_screen.dart' show BackChip;

/// One offered language.
///
/// [label] is deliberately written in the language itself and never
/// translated — someone who has the app stuck in a language they can't read
/// needs to find their own language by sight.
class _LanguageOption {
  final String code; // empty means follow the system
  final String label;
  const _LanguageOption(this.code, this.label);
}

const _languages = <_LanguageOption>[
  _LanguageOption('en', 'English'),
  _LanguageOption('de', 'Deutsch'),
  _LanguageOption('es', 'Español'),
  _LanguageOption('fr', 'Français'),
  _LanguageOption('ko', '한국어'),
  _LanguageOption('nl', 'Nederlands'),
  _LanguageOption('pt', 'Português'),
];

class LanguageScreen extends StatelessWidget {
  final AppSettings settings;

  const LanguageScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      BackChip(colors: c),
                      const SizedBox(width: 16),
                      Text(t.languageTitle,
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
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _Row(
                              colors: c,
                              title: t.languageSystem,
                              subtitle: t.languageSystemSubtitle,
                              selected: settings.languageCode.isEmpty,
                              onTap: () => settings.languageCode = '',
                            ),
                            for (final lang in _languages) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: Container(
                                  height: 1,
                                  color:
                                      c.divider.withValues(alpha: 0.5),
                                ),
                              ),
                              _Row(
                                colors: c,
                                title: lang.label,
                                selected:
                                    settings.languageCode == lang.code,
                                onTap: () =>
                                    settings.languageCode = lang.code,
                              ),
                            ],
                          ],
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
}

class _Row extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  const _Row({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.colors,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: colors.accentWash(0.08),
      highlightColor: colors.accentWash(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        color: selected ? colors.accentSoft : colors.text,
                        fontSize: 16,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            color: colors.subtext, fontSize: 13)),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: colors.accent, size: 20),
          ],
        ),
      ),
    );
  }
}