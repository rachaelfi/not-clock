import 'package:flutter/material.dart';
import 'dart:async';
import 'package:not_clock/main.dart';
import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/models/world_clock_city.dart';
import 'package:not_clock/services/time_now_service.dart';
import 'package:not_clock/services/storage_service.dart';
import 'package:not_clock/screens/world_clock_sub/city_search.dart';

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  String _localTimezoneName = 'America/New_York';
  int _localOffsetMinutes = -300; // Default: EST (UTC-5)
  String _localAbbreviation = 'EST';
  bool _localDst = false;
  bool _localFetched = false;
  bool _isLoadingLocal = true;

  final List<WorldClockCity> _addedClocks = [];
  bool _isEditing = false;

  Timer? _clockTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedClocks(); // Load saved cities from disk
    _detectLocalTimezone();
    _fetchLocalTime();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _fetchLocalTime();
      _refreshAllClocks();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Load saved world clocks from disk.
  /// We store just the name and timezone — the offset/DST/abbreviation
  /// are fetched fresh from the API each time.
  Future<void> _loadSavedClocks() async {
    final saved = await StorageService.loadWorldClocks();
    for (final cityMap in saved) {
      final name = cityMap['name'] ?? '';
      final timezone = cityMap['timezone'] ?? '';
      final country = cityMap['country'] ?? '';

      // Find the city in our database to get its default offset
      final match = availableCities.where(
          (c) => c.name == name && c.timezone == timezone);

      if (match.isNotEmpty) {
        final city = match.first.copy();
        setState(() => _addedClocks.add(city));
        // Fetch live time data from API in background
        _fetchCityTime(city);
      } else {
        // City not in our database — create with defaults
        final city = WorldClockCity(
            name: name, country: country, timezone: timezone);
        setState(() => _addedClocks.add(city));
        _fetchCityTime(city);
      }
    }
  }

  /// Save the current world clock list to disk.
  /// Only stores name, country, and timezone — lightweight.
  Future<void> _saveClocks() async {
    await StorageService.saveWorldClocks(
      _addedClocks
          .map((c) => {
                'name': c.name,
                'country': c.country,
                'timezone': c.timezone,
              })
          .toList(),
    );
  }

  /// Immediate local detection from device (no network needed)
  void _detectLocalTimezone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      setState(() {
        _localOffsetMinutes = offset.inMinutes;
        _localAbbreviation = now.timeZoneName;
        _localTimezoneName = _timezoneFromAbbreviation(now.timeZoneName, offset.inMinutes);
        _isLoadingLocal = false;
      });
    } catch (_) {
      setState(() => _isLoadingLocal = false);
    }
  }

  /// Async fetch from API to get more accurate data (DST, city name, etc.)
  Future<void> _fetchLocalTime() async {
    try {
      final response = await TimeNowService.fetchByIp();
      if (response != null && mounted) {
        setState(() {
          _localOffsetMinutes = response.utcOffsetMinutes;
          _localAbbreviation = response.abbreviation;
          _localDst = response.dst;
          _localTimezoneName = response.timezone;
          _localFetched = true;
        });
      }
    } catch (_) {}
  }

  /// Map device timezone abbreviation to a friendly IANA timezone name
  String _timezoneFromAbbreviation(String abbr, int offsetMinutes) {
    const knownTimezones = <String, String>{
      'EST': 'America/New_York', 'EDT': 'America/New_York',
      'CST': 'America/Chicago', 'CDT': 'America/Chicago',
      'MST': 'America/Denver', 'MDT': 'America/Denver',
      'PST': 'America/Los_Angeles', 'PDT': 'America/Los_Angeles',
      'AKST': 'America/Anchorage', 'AKDT': 'America/Anchorage',
      'HST': 'Pacific/Honolulu',
      'GMT': 'Europe/London', 'BST': 'Europe/London',
      'CET': 'Europe/Paris', 'CEST': 'Europe/Paris',
      'EET': 'Europe/Athens', 'EEST': 'Europe/Athens',
      'JST': 'Asia/Tokyo', 'KST': 'Asia/Seoul',
      'AEST': 'Australia/Sydney', 'AEDT': 'Australia/Sydney',
      'NZST': 'Pacific/Auckland', 'NZDT': 'Pacific/Auckland',
    };
    if (knownTimezones.containsKey(abbr)) return knownTimezones[abbr]!;
    for (final city in availableCities) {
      if (city.utcOffsetMinutes == offsetMinutes) return city.timezone;
    }
    return 'America/New_York';
  }

  Future<void> _fetchCityTime(WorldClockCity city) async {
    final response = await TimeNowService.fetchTimezone(city.timezone);
    if (response != null && mounted) {
      setState(() => city.updateFromApi(response));
    }
  }

  Future<void> _refreshAllClocks() async {
    for (final city in _addedClocks) {
      await _fetchCityTime(city);
    }
  }

  /// Local time: use device's DateTime.now() directly (always correct)
  String _localTimeString(AppSettings settings) {
    final now = DateTime.now();
    return settings.formatTime(now.hour, now.minute);
  }

  String get _localDateString {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  void _addClock() async {
    final settings = SettingsProvider.of(context);
    final result = await Navigator.push<WorldClockCity>(
      context,
      MaterialPageRoute(
        builder: (_) => CitySearchScreen(
          alreadyAdded: _addedClocks,
          settings: settings,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _addedClocks.add(result);
        _addedClocks.sort((a, b) => a.utcOffsetMinutes.compareTo(b.utcOffsetMinutes));
      });
      _saveClocks(); // Persist to disk
      // Try to fetch live DST-aware offset from API
      _fetchCityTime(result);
    }
  }

  void _removeClock(int index) {
    setState(() {
      _addedClocks.removeAt(index);
      if (_addedClocks.isEmpty) _isEditing = false;
    });
    _saveClocks(); // Persist to disk
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsProvider.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('World Clock',
                    style: TextStyle(color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    if (_addedClocks.isNotEmpty)
                      GestureDetector(
                        onTap: _toggleEdit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isEditing
                                ? const Color(0xFF6C5CE7).withValues(alpha: 0.25)
                                : const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(_isEditing ? 'Done' : 'Edit',
                              style: const TextStyle(color: Color(0xFFA29BFE),
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    if (_addedClocks.isNotEmpty) const SizedBox(width: 10),
                    if (!_isEditing)
                      GestureDetector(
                        onTap: _addClock,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add, color: Color(0xFFA29BFE), size: 24),
                        ),
                      ),
                    if (!_isEditing) const SizedBox(width: 10),
                    if (!_isEditing) const SettingsGearButton(),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            _buildLocalTimeSection(settings),
            const SizedBox(height: 24),
            Expanded(
              child: _addedClocks.isEmpty
                  ? _buildEmptyState()
                  : _buildClocksList(settings),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalTimeSection(AppSettings settings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C5CE7).withValues(alpha: 0.12),
            const Color(0xFF6C5CE7).withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Color(0xFFA29BFE), size: 14),
              const SizedBox(width: 6),
              const Text('MY LOCATION',
                  style: TextStyle(color: Color(0xFF8A85A0), fontSize: 11,
                      fontWeight: FontWeight.w500, letterSpacing: 1.5)),
              if (_localAbbreviation.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(_localAbbreviation,
                      style: const TextStyle(color: Color(0xFFA29BFE), fontSize: 10,
                          fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                ),
              ],
              if (_localDst) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD93D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DST',
                      style: TextStyle(color: Color(0xFFFFD93D), fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _isLoadingLocal
              ? const SizedBox(height: 52, child: Center(
                  child: SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C5CE7), strokeWidth: 2))))
              : Text(_localTimeString(settings),
                  style: const TextStyle(color: Colors.white, fontSize: 44,
                      fontWeight: FontWeight.w200, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(_localTimezoneName.replaceAll('_', ' ').replaceAll('/', ' / '),
              style: const TextStyle(color: Color(0xFFA29BFE), fontSize: 16,
                  fontWeight: FontWeight.w400)),
          const SizedBox(height: 4),
          Text(_localDateString,
              style: const TextStyle(color: Color(0xFF6A6A7A), fontSize: 13,
                  fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.language, size: 48, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 12),
          Text('Tap + to add a city',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildClocksList(AppSettings settings) {
    return ListView.separated(
      itemCount: _addedClocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          _buildClockCard(_addedClocks[index], index, settings),
    );
  }

  Widget _buildClockCard(WorldClockCity city, int index, AppSettings settings) {
    final offsetStr = city.offsetStringFrom(_localOffsetMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF14141E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E1E2E), width: 1),
      ),
      child: Row(
        children: [
          if (_isEditing) ...[
            GestureDetector(
              onTap: () => _removeClock(index),
              child: Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF6B6B), shape: BoxShape.circle),
                child: const Icon(Icons.remove, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(offsetStr,
                        style: const TextStyle(color: Color(0xFF6A6A7A), fontSize: 12,
                            fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                    if (city.dst) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD93D).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('DST',
                            style: TextStyle(color: Color(0xFFFFD93D), fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(city.name,
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    Text(city.country,
                        style: const TextStyle(color: Color(0xFF4A4A5A), fontSize: 12)),
                    if (city.abbreviation.isNotEmpty)
                      Text('  ·  ${city.abbreviation}',
                          style: const TextStyle(color: Color(0xFF4A4A5A), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(city.formattedTime(settings),
                  style: const TextStyle(color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w300)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    city.isDaytime ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                    color: city.isDaytime
                        ? const Color(0xFFFFD93D) : const Color(0xFFA29BFE),
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(city.isDaytime ? 'Day' : 'Night',
                      style: TextStyle(
                        color: city.isDaytime
                            ? const Color(0xFFFFD93D).withValues(alpha: 0.7)
                            : const Color(0xFFA29BFE).withValues(alpha: 0.7),
                        fontSize: 11, fontWeight: FontWeight.w400,
                      )),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}