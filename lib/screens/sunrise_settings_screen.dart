import 'package:flutter/material.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/config/sunrise_presets.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/settings_screen.dart' show BackChip;

/// Wake-up window length and sunrise colour preset. Both save as you pick
/// them — no confirm step, same as the theme picker.
///
/// Preset names and their descriptions stay in English, matching how the
/// Catppuccin palette names are handled in the theme picker.
class SunriseSettingsScreen extends StatelessWidget {
  final AppSettings settings;

  const SunriseSettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final c = settings.colors;
        final t = AppLocalizations.of(context);
        final preset = SunrisePreset.byId(settings.sunrisePresetId);

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
                      Expanded(
                        child: Text(t.sunriseTitle,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            )),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      // ── Live preview of the chosen ramp ──
                      Container(
                        height: 110,
                        decoration: BoxDecoration(
                          gradient: preset.previewGradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.bottomLeft,
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          t.beforeAlarm(settings.sunriseWindowMinutes),
                          style: const TextStyle(
                            // The right-hand end of every preset is near-white,
                            // so dark text with a light shadow always reads.
                            color: Color(0xFF12212E),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                color: Color(0x80FFFFFF),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),
                      _Label(t.wakeUpWindow, colors: c),
                      const SizedBox(height: 4),
                      Text(
                        t.wakeUpWindowHint,
                        style: TextStyle(
                            color: c.muted, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: sunriseWindowOptions.map((minutes) {
                          final selected =
                              settings.sunriseWindowMinutes == minutes;
                          return GestureDetector(
                            onTap: () =>
                                settings.sunriseWindowMinutes = minutes,
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 11),
                              decoration: BoxDecoration(
                                color: selected
                                    ? c.accentWash(0.22)
                                    : c.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? c.accent
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                t.minutesShort(minutes),
                                style: TextStyle(
                                  color: selected ? c.accentSoft : c.subtext,
                                  fontSize: 14,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 30),
                      _Label(t.sectionColors, colors: c),
                      const SizedBox(height: 12),
                      ...SunrisePreset.all.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PresetTile(
                              preset: p,
                              selected: p.id == settings.sunrisePresetId,
                              colors: c,
                              onTap: () =>
                                  settings.sunrisePresetId = p.id,
                            ),
                          )),

                      const SizedBox(height: 16),
                      Text(
                        t.sunriseFooterNote,
                        style: TextStyle(
                            color: c.muted, fontSize: 12, height: 1.45),
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

class _Label extends StatelessWidget {
  final String text;
  final AppColors colors;
  const _Label(this.text, {required this.colors});

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: colors.subtext,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      );
}

class _PresetTile extends StatelessWidget {
  final SunrisePreset preset;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? colors.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 44,
              decoration: BoxDecoration(
                gradient: preset.previewGradient,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preset names and descriptions stay in English — see the
                  // class doc on SunriseSettingsScreen.
                  Text(preset.name,
                      style: TextStyle(
                          color: colors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(preset.description,
                      style: TextStyle(
                          color: colors.subtext,
                          fontSize: 12.5,
                          height: 1.3)),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded,
                  color: colors.accent, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}