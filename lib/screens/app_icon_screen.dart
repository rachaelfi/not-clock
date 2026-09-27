import 'package:flutter/material.dart';
import 'package:not_clock/l10n/app_localizations.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/theme/app_theme.dart';
import 'package:not_clock/screens/settings_screen.dart' show BackChip;

/// One selectable home-screen icon.
///
/// [id] must match the alternate-icon name you register natively:
///   • iOS     — `CFBundleAlternateIcons` keys in Info.plist
///   • Android — `<activity-alias>` entries in AndroidManifest.xml
class AppIconOption {
  final String id;
  final String label;
  final Color start;
  final Color end;
  final Color glyph;

  const AppIconOption({
    required this.id,
    required this.label,
    required this.start,
    required this.end,
    required this.glyph,
  });

  static const all = <AppIconOption>[
    AppIconOption(
      id: 'default',
      label: 'Midnight',
      start: Color(0xFF6C5CE7),
      end: Color(0xFF2A2140),
      glyph: Colors.white,
    ),
    AppIconOption(
      id: 'mocha',
      label: 'Mocha',
      start: Color(0xFFCBA6F7),
      end: Color(0xFF1E1E2E),
      glyph: Color(0xFF1E1E2E),
    ),
    AppIconOption(
      id: 'macchiato',
      label: 'Macchiato',
      start: Color(0xFF8AADF4),
      end: Color(0xFF24273A),
      glyph: Color(0xFF181926),
    ),
    AppIconOption(
      id: 'frappe',
      label: 'Frappé',
      start: Color(0xFF81C8BE),
      end: Color(0xFF303446),
      glyph: Color(0xFF232634),
    ),
    AppIconOption(
      id: 'latte',
      label: 'Latte',
      start: Color(0xFFEFF1F5),
      end: Color(0xFFACB0BE),
      glyph: Color(0xFF8839EF),
    ),
    AppIconOption(
      id: 'peach',
      label: 'Peach',
      start: Color(0xFFFAB387),
      end: Color(0xFF8C4A1E),
      glyph: Color(0xFF2A1508),
    ),
  ];

  static AppIconOption byId(String id) =>
      all.firstWhere((o) => o.id == id, orElse: () => all.first);
}

/// Swaps the home-screen icon.
///
/// Persisting the choice works today; actually changing the launcher icon
/// needs native assets, so this is deliberately a no-op until those exist.
/// To finish it: add `flutter_dynamic_icon_plus` to pubspec, register each
/// [AppIconOption.id] in Info.plist and AndroidManifest.xml, then call the
/// plugin from [apply].
class AppIconService {
  static Future<bool> apply(String id) async {
    // await FlutterDynamicIconPlus.setAlternateIconName(
    //   iconName: id == 'default' ? null : id,
    // );
    return false;
  }
}

class AppIconScreen extends StatelessWidget {
  final AppSettings settings;

  const AppIconScreen({super.key, required this.settings});

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
                      Expanded(
                        child: Text(t.appIcon,
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
                  // The footer note now scrolls with the grid instead of being
                  // pinned below it. Pinned, it stole a fixed slice of height,
                  // and on a short window the grid's own rows overflowed —
                  // that was the px overflow on this screen.
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 18,
                      // Tile = square icon + label. 0.82 left the label with
                      // less room than it needed once the text wrapped, so the
                      // Column inside each tile overflowed a few pixels.
                      childAspectRatio: 0.74,
                    ),
                    itemCount: AppIconOption.all.length,
                    itemBuilder: (context, i) {
                      final option = AppIconOption.all[i];
                      return _IconTile(
                        option: option,
                        selected: settings.appIconId == option.id,
                        colors: c,
                        onTap: () {
                          settings.appIconId = option.id;
                          AppIconService.apply(option.id);
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Text(
                    t.appIconNote,
                    style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
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

class _IconTile extends StatelessWidget {
  final AppIconOption option;
  final bool selected;
  final AppColors colors;
  final VoidCallback onTap;

  const _IconTile({
    required this.option,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Flexible rather than a bare AspectRatio: if the tile ends up
          // shorter than the square wants to be, the icon shrinks instead of
          // the Column overflowing.
          Flexible(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? colors.accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [option.start, option.end],
                    ),
                    borderRadius: BorderRadius.circular(19),
                  ),
                  child: Icon(Icons.access_time_rounded,
                      color: option.glyph, size: 34),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Two lines, ellipsised. "Macchiato" at 12.5pt is already close to
          // the column width on a narrow phone, and German and Korean labels
          // for future icons could be longer still.
          Text(
            option.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? colors.text : colors.subtext,
              fontSize: 12.5,
              height: 1.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}