import 'package:flutter/material.dart';
import 'package:not_clock/services/storage_service.dart';
import 'package:not_clock/theme/app_theme.dart';

/// Global app settings, shared across all screens via InheritedWidget.
/// Automatically saves to disk when changed and loads on init.
class AppSettings extends ChangeNotifier {
  bool _use24HourFormat = false;

  // Personalization
  ThemeFlavor _flavor = ThemeFlavor.midnight;
  AccentColor _accent = AccentColor.mauve;
  String _appIconId = 'default';

  // Sleep
  bool _nightClockEnabled = false;

  bool _sunriseEnabled = false;
  String _sunrisePresetId = 'classic_fire';
  int _sunriseWindowMinutes = 15;

  // ─── 24-hour format ─────────────────────────────────────────────────────────

  bool get use24HourFormat => _use24HourFormat;

  set use24HourFormat(bool value) {
    if (_use24HourFormat != value) {
      _use24HourFormat = value;
      notifyListeners();
      // Save to disk whenever the setting changes
      StorageService.save24HourFormat(value);
    }
  }

  void toggle24HourFormat() {
    use24HourFormat = !_use24HourFormat;
  }

  // ─── Theme ──────────────────────────────────────────────────────────────────

  ThemeFlavor get flavor => _flavor;

  set flavor(ThemeFlavor value) {
    if (_flavor != value) {
      _flavor = value;
      notifyListeners();
      StorageService.saveThemeFlavor(value.name);
    }
  }

  AccentColor get accent => _accent;

  set accent(AccentColor value) {
    if (_accent != value) {
      _accent = value;
      notifyListeners();
      StorageService.saveThemeAccent(value.name);
    }
  }

  /// The resolved palette. Every screen reads its colors from here:
  ///   final c = SettingsProvider.of(context).colors;
  AppColors get colors => AppPalette.resolve(_flavor, _accent);

  /// Back to the original purple-on-near-black look.
  void resetTheme() {
    _flavor = ThemeFlavor.midnight;
    _accent = AccentColor.mauve;
    notifyListeners();
    StorageService.saveThemeFlavor(_flavor.name);
    StorageService.saveThemeAccent(_accent.name);
  }

  // ─── App icon ───────────────────────────────────────────────────────────────

  String get appIconId => _appIconId;

  set appIconId(String value) {
    if (_appIconId != value) {
      _appIconId = value;
      notifyListeners();
      StorageService.saveAppIcon(value);
    }
  }

  // ─── Sleep ──────────────────────────────────────────────────────────────────

  bool get nightClockEnabled => _nightClockEnabled;

  set nightClockEnabled(bool value) {
    if (_nightClockEnabled != value) {
      _nightClockEnabled = value;
      notifyListeners();
      StorageService.saveNightClockEnabled(value);
    }
  }

  bool get sunriseEnabled => _sunriseEnabled;

  set sunriseEnabled(bool value) {
    if (_sunriseEnabled != value) {
      _sunriseEnabled = value;
      notifyListeners();
      StorageService.saveSunriseEnabled(value);
    }
  }

  String get sunrisePresetId => _sunrisePresetId;

  set sunrisePresetId(String value) {
    if (_sunrisePresetId != value) {
      _sunrisePresetId = value;
      notifyListeners();
      StorageService.saveSunrisePreset(value);
    }
  }

  int get sunriseWindowMinutes => _sunriseWindowMinutes;

  set sunriseWindowMinutes(int value) {
    if (_sunriseWindowMinutes != value) {
      _sunriseWindowMinutes = value;
      notifyListeners();
      StorageService.saveSunriseWindow(value);
    }
  }

  // ─── Loading ────────────────────────────────────────────────────────────────

  /// Load saved settings from disk. Call this once at app startup.
  Future<void> loadFromDisk() async {
    _use24HourFormat = await StorageService.load24HourFormat();
    _nightClockEnabled = await StorageService.loadNightClockEnabled();
    _sunriseEnabled = await StorageService.loadSunriseEnabled();
    _sunrisePresetId = await StorageService.loadSunrisePreset();
    _sunriseWindowMinutes = await StorageService.loadSunriseWindow();
    _appIconId = await StorageService.loadAppIcon();

    final flavorName = await StorageService.loadThemeFlavor();
    _flavor = ThemeFlavor.values.firstWhere(
      (f) => f.name == flavorName,
      orElse: () => ThemeFlavor.midnight,
    );

    final accentName = await StorageService.loadThemeAccent();
    _accent = AccentColor.values.firstWhere(
      (a) => a.name == accentName,
      orElse: () => AccentColor.mauve,
    );

    notifyListeners();
  }

  // ─── Formatting helpers ─────────────────────────────────────────────────────

  /// Format an hour and minute into a time string.
  /// Respects 24-hour setting.
  String formatTime(int hour, int minute) {
    final m = minute.toString().padLeft(2, '0');
    if (_use24HourFormat) {
      return '${hour.toString().padLeft(2, '0')}:$m';
    } else {
      final period = hour >= 12 ? 'PM' : 'AM';
      int h = hour;
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      return '$h:$m $period';
    }
  }

  /// Format with seconds.
  String formatTimeWithSeconds(int hour, int minute, int second) {
    final m = minute.toString().padLeft(2, '0');
    final s = second.toString().padLeft(2, '0');
    if (_use24HourFormat) {
      return '${hour.toString().padLeft(2, '0')}:$m:$s';
    } else {
      final period = hour >= 12 ? 'PM' : 'AM';
      int h = hour;
      if (h == 0) h = 12;
      if (h > 12) h -= 12;
      return '$h:$m:$s $period';
    }
  }
}