import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Catppuccin flavors + the app's original "Midnight" look.
//
//  A theme is two independent choices:
//    1. A flavor  → the background / surface / text ramp
//    2. An accent → the single hue used for buttons, headers, active states
//
//  Resolve them together with `AppPalette.resolve(flavor, accent)` to get an
//  `AppColors`, which is what every screen should read from.
// ─────────────────────────────────────────────────────────────────────────────

enum ThemeFlavor { midnight, mocha, macchiato, frappe, latte }

enum AccentColor {
  rosewater,
  flamingo,
  pink,
  mauve,
  red,
  maroon,
  peach,
  yellow,
  green,
  teal,
  sky,
  sapphire,
  blue,
  lavender,
}

extension ThemeFlavorInfo on ThemeFlavor {
  String get label => switch (this) {
        ThemeFlavor.midnight => 'Midnight',
        ThemeFlavor.mocha => 'Mocha',
        ThemeFlavor.macchiato => 'Macchiato',
        ThemeFlavor.frappe => 'Frappé',
        ThemeFlavor.latte => 'Latte',
      };

  String get blurb => switch (this) {
        ThemeFlavor.midnight => 'Near-black, the original',
        ThemeFlavor.mocha => 'Deepest Catppuccin dark',
        ThemeFlavor.macchiato => 'Dark with a blue cast',
        ThemeFlavor.frappe => 'Softer, mid-dark',
        ThemeFlavor.latte => 'Light',
      };

  bool get isLight => this == ThemeFlavor.latte;
}

extension AccentColorInfo on AccentColor {
  String get label => switch (this) {
        AccentColor.rosewater => 'Rosewater',
        AccentColor.flamingo => 'Flamingo',
        AccentColor.pink => 'Pink',
        AccentColor.mauve => 'Mauve',
        AccentColor.red => 'Red',
        AccentColor.maroon => 'Maroon',
        AccentColor.peach => 'Peach',
        AccentColor.yellow => 'Yellow',
        AccentColor.green => 'Green',
        AccentColor.teal => 'Teal',
        AccentColor.sky => 'Sky',
        AccentColor.sapphire => 'Sapphire',
        AccentColor.blue => 'Blue',
        AccentColor.lavender => 'Lavender',
      };
}

// ─── Raw flavor definitions ──────────────────────────────────────────────────

class _Flavor {
  final Color base, mantle, crust;
  final Color surface0, surface1, surface2;
  final Color overlay0, overlay1, overlay2;
  final Color subtext0, subtext1, text;
  final Map<AccentColor, Color> accents;

  const _Flavor({
    required this.base,
    required this.mantle,
    required this.crust,
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.overlay0,
    required this.overlay1,
    required this.overlay2,
    required this.subtext0,
    required this.subtext1,
    required this.text,
    required this.accents,
  });
}

const _midnight = _Flavor(
  base: Color(0xFF0A0A0F),
  mantle: Color(0xFF12121A),
  crust: Color(0xFF050508),
  surface0: Color(0xFF1A1A24),
  surface1: Color(0xFF24242F),
  surface2: Color(0xFF2E2E3C),
  overlay0: Color(0xFF4A4A5A),
  overlay1: Color(0xFF5C5C6E),
  overlay2: Color(0xFF6E6E82),
  subtext0: Color(0xFF8A85A0),
  subtext1: Color(0xFFA5A0B8),
  text: Color(0xFFFFFFFF),
  accents: {
    AccentColor.rosewater: Color(0xFFFFC5B8),
    AccentColor.flamingo: Color(0xFFFF8A8A),
    AccentColor.pink: Color(0xFFFF6BD6),
    AccentColor.mauve: Color(0xFF6C5CE7), // the original app purple
    AccentColor.red: Color(0xFFFF6B6B),   // the existing dismiss/delete red
    AccentColor.maroon: Color(0xFFE05555),
    AccentColor.peach: Color(0xFFFF9F43),
    AccentColor.yellow: Color(0xFFFFD93D), // the existing flash/DST yellow
    AccentColor.green: Color(0xFF4CD964),
    AccentColor.teal: Color(0xFF2FD1C5),
    AccentColor.sky: Color(0xFF56CCF2),
    AccentColor.sapphire: Color(0xFF3AAED8),
    AccentColor.blue: Color(0xFF4A9BFF),
    AccentColor.lavender: Color(0xFFA29BFE),
  },
);

const _mocha = _Flavor(
  base: Color(0xFF1E1E2E),
  mantle: Color(0xFF181825),
  crust: Color(0xFF11111B),
  surface0: Color(0xFF313244),
  surface1: Color(0xFF45475A),
  surface2: Color(0xFF585B70),
  overlay0: Color(0xFF6C7086),
  overlay1: Color(0xFF7F849C),
  overlay2: Color(0xFF9399B2),
  subtext0: Color(0xFFA6ADC8),
  subtext1: Color(0xFFBAC2DE),
  text: Color(0xFFCDD6F4),
  accents: {
    AccentColor.rosewater: Color(0xFFF5E0DC),
    AccentColor.flamingo: Color(0xFFF2CDCD),
    AccentColor.pink: Color(0xFFF5C2E7),
    AccentColor.mauve: Color(0xFFCBA6F7),
    AccentColor.red: Color(0xFFF38BA8),
    AccentColor.maroon: Color(0xFFEBA0AC),
    AccentColor.peach: Color(0xFFFAB387),
    AccentColor.yellow: Color(0xFFF9E2AF),
    AccentColor.green: Color(0xFFA6E3A1),
    AccentColor.teal: Color(0xFF94E2D5),
    AccentColor.sky: Color(0xFF89DCEB),
    AccentColor.sapphire: Color(0xFF74C7EC),
    AccentColor.blue: Color(0xFF89B4FA),
    AccentColor.lavender: Color(0xFFB4BEFE),
  },
);

const _macchiato = _Flavor(
  base: Color(0xFF24273A),
  mantle: Color(0xFF1E2030),
  crust: Color(0xFF181926),
  surface0: Color(0xFF363A4F),
  surface1: Color(0xFF494D64),
  surface2: Color(0xFF5B6078),
  overlay0: Color(0xFF6E738D),
  overlay1: Color(0xFF8087A2),
  overlay2: Color(0xFF939AB7),
  subtext0: Color(0xFFA5ADCB),
  subtext1: Color(0xFFB8C0E0),
  text: Color(0xFFCAD3F5),
  accents: {
    AccentColor.rosewater: Color(0xFFF4DBD6),
    AccentColor.flamingo: Color(0xFFF0C6C6),
    AccentColor.pink: Color(0xFFF5BDE6),
    AccentColor.mauve: Color(0xFFC6A0F6),
    AccentColor.red: Color(0xFFED8796),
    AccentColor.maroon: Color(0xFFEE99A0),
    AccentColor.peach: Color(0xFFF5A97F),
    AccentColor.yellow: Color(0xFFEED49F),
    AccentColor.green: Color(0xFFA6DA95),
    AccentColor.teal: Color(0xFF8BD5CA),
    AccentColor.sky: Color(0xFF91D7E3),
    AccentColor.sapphire: Color(0xFF7DC4E4),
    AccentColor.blue: Color(0xFF8AADF4),
    AccentColor.lavender: Color(0xFFB7BDF8),
  },
);

const _frappe = _Flavor(
  base: Color(0xFF303446),
  mantle: Color(0xFF292C3C),
  crust: Color(0xFF232634),
  surface0: Color(0xFF414559),
  surface1: Color(0xFF51576D),
  surface2: Color(0xFF626880),
  overlay0: Color(0xFF737994),
  overlay1: Color(0xFF838BA7),
  overlay2: Color(0xFF949CBB),
  subtext0: Color(0xFFA5ADCE),
  subtext1: Color(0xFFB5BFE2),
  text: Color(0xFFC6D0F5),
  accents: {
    AccentColor.rosewater: Color(0xFFF2D5CF),
    AccentColor.flamingo: Color(0xFFEEBEBE),
    AccentColor.pink: Color(0xFFF4B8E4),
    AccentColor.mauve: Color(0xFFCA9EE6),
    AccentColor.red: Color(0xFFE78284),
    AccentColor.maroon: Color(0xFFEA999C),
    AccentColor.peach: Color(0xFFEF9F76),
    AccentColor.yellow: Color(0xFFE5C890),
    AccentColor.green: Color(0xFFA6D189),
    AccentColor.teal: Color(0xFF81C8BE),
    AccentColor.sky: Color(0xFF99D1DB),
    AccentColor.sapphire: Color(0xFF85C1DC),
    AccentColor.blue: Color(0xFF8CAAEE),
    AccentColor.lavender: Color(0xFFBABBF1),
  },
);

const _latte = _Flavor(
  base: Color(0xFFEFF1F5),
  mantle: Color(0xFFE6E9EF),
  crust: Color(0xFFDCE0E8),
  surface0: Color(0xFFCCD0DA),
  surface1: Color(0xFFBCC0CC),
  surface2: Color(0xFFACB0BE),
  overlay0: Color(0xFF9CA0B0),
  overlay1: Color(0xFF8C8FA1),
  overlay2: Color(0xFF7C7F93),
  subtext0: Color(0xFF6C6F85),
  subtext1: Color(0xFF5C5F77),
  text: Color(0xFF4C4F69),
  accents: {
    AccentColor.rosewater: Color(0xFFDC8A78),
    AccentColor.flamingo: Color(0xFFDD7878),
    AccentColor.pink: Color(0xFFEA76CB),
    AccentColor.mauve: Color(0xFF8839EF),
    AccentColor.red: Color(0xFFD20F39),
    AccentColor.maroon: Color(0xFFE64553),
    AccentColor.peach: Color(0xFFFE640B),
    AccentColor.yellow: Color(0xFFDF8E1D),
    AccentColor.green: Color(0xFF40A02B),
    AccentColor.teal: Color(0xFF179299),
    AccentColor.sky: Color(0xFF04A5E5),
    AccentColor.sapphire: Color(0xFF209FB5),
    AccentColor.blue: Color(0xFF1E66F5),
    AccentColor.lavender: Color(0xFF7287FD),
  },
);

// ─── Resolved colors — this is what screens use ──────────────────────────────

@immutable
class AppColors {
  final ThemeFlavor flavor;
  final AccentColor accentName;

  /// Scaffold background.
  final Color background;

  /// Bars, sheets, anything sitting directly on [background].
  final Color surface;

  /// Cards and list rows.
  final Color card;

  /// A card resting on a card (nested rows, pressed states).
  final Color cardAlt;

  /// Hairlines and separators.
  final Color divider;

  /// Disabled / inactive icons and labels.
  final Color muted;

  /// Secondary body copy.
  final Color subtext;

  /// Primary body copy and headings.
  final Color text;

  /// The user's chosen hue — buttons, active tabs, headers.
  final Color accent;

  /// A lighter step of [accent] — icons and small glyphs on dark surfaces.
  final Color accentSoft;

  /// A darker step of [accent] — gradient ends and pressed states.
  final Color accentDeep;

  /// Text/icon color that sits legibly *on top of* [accent].
  final Color onAccent;

  /// Destructive and alarming: dismiss, delete, slowest lap, finished timer.
  /// Deliberately NOT tied to [accent] — it must stay red when the accent is
  /// green, and it shifts per flavor so it stays readable on Latte.
  final Color danger;

  /// A darker step of [danger], for the dismiss button's gradient.
  final Color dangerDeep;

  /// Caution and attention: flash active, DST badge, a paused timer.
  final Color warning;

  /// Positive: fastest lap.
  final Color success;

  const AppColors._({
    required this.flavor,
    required this.accentName,
    required this.background,
    required this.surface,
    required this.card,
    required this.cardAlt,
    required this.divider,
    required this.muted,
    required this.subtext,
    required this.text,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.onAccent,
    required this.danger,
    required this.dangerDeep,
    required this.warning,
    required this.success,
  });

  bool get isLight => flavor.isLight;

  /// [accent] at a given opacity — the common "tinted chip" treatment.
  Color accentWash(double alpha) => accent.withValues(alpha: alpha);

  /// The two-stop gradient used on primary buttons.
  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, accentDeep],
      );

  /// Soft glow under a primary button.
  List<BoxShadow> get accentGlow => [
        BoxShadow(
          color: accent.withValues(alpha: isLight ? 0.28 : 0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Gradient and glow for destructive buttons (Dismiss, Delete).
  LinearGradient get dangerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [danger, dangerDeep],
      );

  List<BoxShadow> get dangerGlow => [
        BoxShadow(
          color: danger.withValues(alpha: isLight ? 0.28 : 0.32),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Text/icon color that sits legibly on top of [danger].
  Color get onDanger => danger.computeLuminance() > 0.5
      ? const Color(0xFF11111B)
      : Colors.white;
}

class AppPalette {
  static _Flavor _raw(ThemeFlavor f) => switch (f) {
        ThemeFlavor.midnight => _midnight,
        ThemeFlavor.mocha => _mocha,
        ThemeFlavor.macchiato => _macchiato,
        ThemeFlavor.frappe => _frappe,
        ThemeFlavor.latte => _latte,
      };

  /// The accent swatches available for a flavor, in palette order.
  static Map<AccentColor, Color> accentsFor(ThemeFlavor f) => _raw(f).accents;

  static Color accentValue(ThemeFlavor f, AccentColor a) =>
      _raw(f).accents[a] ?? _raw(f).accents[AccentColor.mauve]!;

  static Color _shift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  static AppColors resolve(ThemeFlavor flavor, AccentColor accent) {
    final f = _raw(flavor);
    final a = accentValue(flavor, accent);
    final light = flavor.isLight;

    // On light flavors the accents are already dark and saturated, so "soft"
    // means darker, not lighter — otherwise icons wash out against the page.
    final soft = light ? _shift(a, -0.08) : _shift(a, 0.14);
    final deep = light ? _shift(a, -0.14) : _shift(a, -0.09);

    return AppColors._(
      flavor: flavor,
      accentName: accent,
      background: f.base,
      surface: f.mantle,
      card: f.surface0,
      cardAlt: f.surface1,
      divider: f.surface2,
      muted: f.overlay1,
      subtext: f.subtext0,
      text: f.text,
      accent: a,
      accentSoft: soft,
      accentDeep: deep,
      onAccent: a.computeLuminance() > 0.5 ? f.crust : Colors.white,
      danger: f.accents[AccentColor.red]!,
      dangerDeep: _shift(f.accents[AccentColor.red]!, light ? -0.12 : -0.10),
      warning: f.accents[AccentColor.yellow]!,
      success: f.accents[AccentColor.green]!,
    );
  }

  /// A Material theme built from the resolved colors, so stock widgets
  /// (dialogs, switches, cursors) follow the user's choice too.
  static ThemeData materialTheme(AppColors c) {
    final base = c.isLight ? ThemeData.light() : ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerColor: c.divider,
      colorScheme: (c.isLight
              ? const ColorScheme.light()
              : const ColorScheme.dark())
          .copyWith(
        brightness: c.isLight ? Brightness.light : Brightness.dark,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.accentSoft,
        surface: c.surface,
        onSurface: c.text,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.onAccent : c.muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? c.accent : c.card),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.accent,
        selectionColor: c.accentWash(0.3),
        selectionHandleColor: c.accent,
      ),
    );
  }
}