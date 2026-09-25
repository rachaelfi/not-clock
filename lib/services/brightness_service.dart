import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:screen_brightness/screen_brightness.dart';

/// Thin wrapper around `screen_brightness`, so the plugin is named in exactly
/// one place.
///
/// ⚠️ If `flutter pub get` resolves you to screen_brightness 1.x, the method
/// names are `setScreenBrightness` and `resetScreenBrightness` — rename the two
/// calls below and nothing else changes.
///
/// Scope: this sets brightness for *this app's window only*. iOS restores the
/// system level when the app leaves the foreground; Android does the same via
/// window attributes. No special permission is needed on either platform —
/// notably not Android's WRITE_SETTINGS, which is only required for changing
/// the global system brightness.
class BrightnessService {
  static bool _held = false;
  static double? _last;

  /// Sets brightness to [value], 0–1. Writes are skipped unless the value has
  /// moved at least 1%, since the sunrise ticks every second and most ticks
  /// don't change anything visible.
  static Future<void> set(double value) async {
    if (kIsWeb) return;

    final v = value.clamp(0.0, 1.0);
    if (_last != null && (_last! - v).abs() < 0.01) return;

    try {
      await ScreenBrightness().setApplicationScreenBrightness(v);
      _last = v;
      _held = true;
    } catch (_) {
      // Unsupported device or denied — the sunrise still works visually,
      // it just won't drive the backlight.
    }
  }

  /// Hands brightness back to the system. Always call this when leaving the
  /// Night Clock, or the phone stays at whatever the sunrise left it on.
  static Future<void> restore() async {
    if (kIsWeb || !_held) return;

    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Nothing useful to do; the OS resets on backgrounding anyway.
    }
    _held = false;
    _last = null;
  }
}