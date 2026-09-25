import 'package:flutter/material.dart';

/// A sunrise simulation — four colour stops the screen walks through during
/// the wake-up window, from deepest at the start to brightest at alarm time.
///
/// The last stop should always be near-white: that's what's on screen at the
/// moment the alarm sounds, and it's what actually helps you wake up.
class SunrisePreset {
  final String id;
  final String name;
  final String description;

  /// Four colours, dimmest first. [colorAt] walks between them.
  final List<Color> stops;

  const SunrisePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.stops,
  });

  /// The colour at [t] through the sunrise, 0 at window start, 1 at alarm.
  Color colorAt(double t) {
    final scaled = t.clamp(0.0, 1.0) * (stops.length - 1);
    final i = scaled.floor().clamp(0, stops.length - 2);
    return Color.lerp(stops[i], stops[i + 1], scaled - i)!;
  }

  /// Left-to-right preview of the whole ramp, for the picker.
  LinearGradient get previewGradient => LinearGradient(colors: stops);

  static const all = <SunrisePreset>[
    SunrisePreset(
      id: 'classic_fire',
      name: 'Classic Fire Sunrise',
      description: 'Deep reddish-orange, warm amber, golden yellow, white',
      stops: [
        Color(0xFF4A1103),
        Color(0xFFC0561A),
        Color(0xFFF3C766),
        Color(0xFFFFFFFF),
      ],
    ),
    SunrisePreset(
      id: 'arctic_dawn',
      name: 'Cool Arctic Dawn',
      description: 'Deep navy, icy blue, frosty lavender, cool white',
      stops: [
        Color(0xFF061436),
        Color(0xFF2E7FC2),
        Color(0xFFBFC8F0),
        Color(0xFFF2F7FF),
      ],
    ),
    SunrisePreset(
      id: 'forest_canopy',
      name: 'Forest Canopy',
      description: 'Deep moss, soft mint, dappled pale yellow, warm white',
      stops: [
        Color(0xFF0B2412),
        Color(0xFF5FA87A),
        Color(0xFFDCE59A),
        Color(0xFFFFF8EC),
      ],
    ),
    SunrisePreset(
      id: 'desert_solstice',
      name: 'Desert Solstice',
      description: 'Burnt terracotta, dusty ochre, bright copper, blazing white',
      stops: [
        Color(0xFF461505),
        Color(0xFF9C5A21),
        Color(0xFFE08A3C),
        Color(0xFFFFFDF5),
      ],
    ),
    SunrisePreset(
      id: 'tropical_beach',
      name: 'Tropical Beach',
      description: 'Deep violet, coral pink, warm peach, sandy cream',
      stops: [
        Color(0xFF1E0A38),
        Color(0xFFD4557E),
        Color(0xFFF6A273),
        Color(0xFFFDEBD2),
      ],
    ),
  ];

  static SunrisePreset byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => all.first);
}

/// Selectable wake-up window lengths, in minutes.
const List<int> sunriseWindowOptions = [5, 10, 15, 20, 25, 30];