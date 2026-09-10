import 'package:flutter/material.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/settings_screen.dart' show BackChip;

/// Picking a flavor or accent writes it straight to [AppSettings], so the
/// preview, the screen behind it, and the saved value all move together.
class ThemePickerScreen extends StatelessWidget {
  final AppSettings settings;

  const ThemePickerScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Row(
                    children: [
                      BackChip(colors: c),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Theme and colors',
                          style: TextStyle(
                            color: c.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: settings.resetTheme,
                        style: TextButton.styleFrom(
                            foregroundColor: c.accentSoft,
                            padding: const EdgeInsets.symmetric(horizontal: 8)),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    children: [
                      _Preview(colors: c),
                      const SizedBox(height: 28),
                      _Label('Background', colors: c),
                      const SizedBox(height: 12),
                      ...ThemeFlavor.values.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _FlavorTile(
                              flavor: f,
                              accent: settings.accent,
                              selected: settings.flavor == f,
                              colors: c,
                              onTap: () => settings.flavor = f,
                            ),
                          )),
                      const SizedBox(height: 22),
                      _Label('Accent', colors: c),
                      const SizedBox(height: 4),
                      Text(
                        'Used for buttons, headers, and anything currently purple.',
                        style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      _AccentGrid(
                        flavor: settings.flavor,
                        selected: settings.accent,
                        colors: c,
                        onPick: (a) => settings.accent = a,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Saved as you go — no need to confirm.',
                        style: TextStyle(color: c.muted, fontSize: 12),
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

// ─── Live preview ────────────────────────────────────────────────────────────

/// A miniature of the app's own furniture: a heading, a big time, a primary
/// button, a toggle. If it looks right here it looks right everywhere.
class _Preview extends StatelessWidget {
  final AppColors colors;
  const _Preview({required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Sleep',
                  style: TextStyle(
                      color: c.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.accentWash(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.settings_outlined,
                    color: c.accentSoft, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Sleep duration ~ 7 h 45 min',
              style: TextStyle(color: c.subtext, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text('6:30',
              style: TextStyle(
                color: c.text,
                fontSize: 44,
                fontWeight: FontWeight.w300,
                letterSpacing: -1.5,
                height: 1.05,
              )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              gradient: c.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: c.accentGlow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.alarm_add, color: c.onAccent, size: 18),
                const SizedBox(width: 8),
                Text('Set Sleep Alarm',
                    style: TextStyle(
                        color: c.onAccent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.nightlight_round, color: c.accentSoft, size: 17),
                const SizedBox(width: 10),
                Text('Night Clock',
                    style: TextStyle(color: c.text, fontSize: 14)),
                const Spacer(),
                Container(
                  width: 38,
                  height: 22,
                  padding: const EdgeInsets.all(3),
                  alignment: Alignment.centerRight,
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                        color: c.onAccent, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Flavor tile ─────────────────────────────────────────────────────────────

class _FlavorTile extends StatelessWidget {
  final ThemeFlavor flavor;
  final AccentColor accent;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _FlavorTile({
    required this.flavor,
    required this.accent,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final swatch = AppPalette.resolve(flavor, accent);

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
            // Three-band chip: background, card, accent.
            Container(
              width: 46,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: swatch.divider, width: 1),
              ),
              child: Column(
                children: [
                  Expanded(flex: 3, child: Container(color: swatch.background)),
                  Expanded(flex: 2, child: Container(color: swatch.card)),
                  Expanded(flex: 2, child: Container(color: swatch.accent)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(flavor.label,
                      style: TextStyle(
                          color: colors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(flavor.blurb,
                      style: TextStyle(color: colors.subtext, fontSize: 12.5)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: colors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}

// ─── Accent grid ─────────────────────────────────────────────────────────────

class _AccentGrid extends StatelessWidget {
  final ThemeFlavor flavor;
  final AccentColor selected;
  final AppColors colors;
  final ValueChanged<AccentColor> onPick;

  const _AccentGrid({
    required this.flavor,
    required this.selected,
    required this.colors,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AccentColor.values.map((a) {
            final color = AppPalette.accentValue(flavor, a);
            final isSelected = a == selected;
            return GestureDetector(
              onTap: () => onPick(a),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? colors.text : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(Icons.check_rounded,
                        size: 20,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(selected.label,
            style: TextStyle(
                color: colors.text,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}