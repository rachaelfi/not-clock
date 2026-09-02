import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// StorageService handles all persistent data using shared_preferences.
/// 
/// shared_preferences stores simple key-value pairs on disk:
/// - Strings, ints, bools, doubles, and List<String>
/// - For complex objects (alarms, cities), we serialize to JSON strings
/// 
/// Each data type has its own key so they don't interfere with each other.
class StorageService {
  // Storage keys — each piece of data gets a unique key
  static const String _keyUse24Hour = 'settings_use_24_hour';
  static const String _keyAlarms = 'alarms_list';
  static const String _keyWorldClocks = 'world_clocks_list';
  static const String _keyRecentTimers = 'recent_timers_list';

  // ─── Settings ───────────────────────────────────────────────────────────────

  /// Save the 24-hour format preference
  static Future<void> save24HourFormat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUse24Hour, value);
  }

  /// Load the 24-hour format preference (defaults to false)
  static Future<bool> load24HourFormat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyUse24Hour) ?? false;
  }

  // ─── Alarms ─────────────────────────────────────────────────────────────────

  /// Save the full alarm list as a JSON string.
  /// Each alarm is converted to a Map, then the list is JSON-encoded.
  static Future<void> saveAlarms(List<Map<String, dynamic>> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(alarms);
    await prefs.setString(_keyAlarms, jsonString);
  }

  /// Load the alarm list from disk.
  /// Returns an empty list if nothing was saved yet.
  static Future<List<Map<String, dynamic>>> loadAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyAlarms);
    if (jsonString == null) return [];

    // Decode the JSON string back into a List of Maps
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.cast<Map<String, dynamic>>();
  }

  // ─── World Clocks ───────────────────────────────────────────────────────────

  /// Save added world clocks. We only store name + timezone —
  /// the offset/abbreviation/DST are fetched fresh from the API on load.
  static Future<void> saveWorldClocks(
      List<Map<String, String>> cities) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(cities);
    await prefs.setString(_keyWorldClocks, jsonString);
  }

  /// Load saved world clocks.
  static Future<List<Map<String, String>>> loadWorldClocks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyWorldClocks);
    if (jsonString == null) return [];

    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((item) => Map<String, String>.from(item)).toList();
  }

  // ─── Recent Timers ──────────────────────────────────────────────────────────

  /// Save recent timer durations as a list of seconds (ints).
  /// Duration doesn't have built-in JSON support, so we store .inSeconds.
  static Future<void> saveRecentTimers(List<int> secondsList) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(secondsList);
    await prefs.setString(_keyRecentTimers, jsonString);
  }

  /// Load recent timer durations.
  static Future<List<int>> loadRecentTimers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_keyRecentTimers);
    if (jsonString == null) return [];

    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.cast<int>();
  }
}