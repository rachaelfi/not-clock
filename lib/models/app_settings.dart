import 'package:flutter/material.dart';
import 'package:not_clock/services/storage_service.dart';

/// Global app settings, shared across all screens via InheritedWidget.
/// Automatically saves to disk when changed and loads on init.
class AppSettings extends ChangeNotifier {
  bool _use24HourFormat = false;

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

  /// Load saved settings from disk. Call this once at app startup.
  Future<void> loadFromDisk() async {
    _use24HourFormat = await StorageService.load24HourFormat();
    notifyListeners();
  }

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