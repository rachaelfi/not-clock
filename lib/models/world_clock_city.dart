import 'package:not_clock/models/app_settings.dart';
import 'package:not_clock/services/time_now_service.dart';

class WorldClockCity {
  final String name;
  final String country;
  final String timezone; // IANA timezone e.g. 'America/New_York'

  /// Offset from UTC in total minutes. This is the single source of truth
  /// for computing current time. Positive = east of UTC, negative = west.
  /// Updated by API to include DST when available.
  int utcOffsetMinutes;

  String abbreviation;
  bool dst;
  bool _hasApiFetch = false;

  WorldClockCity({
    required this.name,
    required this.country,
    required this.timezone,
    this.utcOffsetMinutes = 0,
    this.abbreviation = '',
    this.dst = false,
  });

  /// Create a copy of this city (so we never share references with the global list)
  WorldClockCity copy() {
    return WorldClockCity(
      name: name,
      country: country,
      timezone: timezone,
      utcOffsetMinutes: utcOffsetMinutes,
      abbreviation: abbreviation,
      dst: dst,
    );
  }

  /// Update from API response. This updates the offset to reflect
  /// current DST status, so times are always accurate.
  void updateFromApi(TimeNowResponse response) {
    utcOffsetMinutes = response.utcOffsetMinutes;
    abbreviation = response.abbreviation;
    dst = response.dst;
    _hasApiFetch = true;
  }

  bool get hasApiFetch => _hasApiFetch;

  /// Current wall-clock time in this city.
  /// Always computed fresh: take current UTC time, add the offset.
  /// This avoids all DateTime parsing/timezone bugs.
  DateTime get currentTime {
    final utcNow = DateTime.now().toUtc();
    return DateTime.utc(
      utcNow.year, utcNow.month, utcNow.day,
      utcNow.hour, utcNow.minute, utcNow.second,
    ).add(Duration(minutes: utcOffsetMinutes));
  }

  /// Format time respecting 12/24h setting
  String formattedTime(AppSettings settings) {
    final t = currentTime;
    return settings.formatTime(t.hour, t.minute);
  }

  /// Format time with seconds
  String formattedTimeWithSeconds(AppSettings settings) {
    final t = currentTime;
    return settings.formatTimeWithSeconds(t.hour, t.minute, t.second);
  }

  /// Difference string relative to a local offset in minutes
  String offsetStringFrom(int localOffsetMinutes) {
    final diffMinutes = utcOffsetMinutes - localOffsetMinutes;
    if (diffMinutes == 0) return 'Same time';

    final sign = diffMinutes > 0 ? '+' : '';
    final hours = diffMinutes ~/ 60;
    final mins = (diffMinutes % 60).abs();

    if (mins == 0) {
      return '${sign}${hours} h';
    }
    return '${sign}${hours}H ${mins}M';
  }

  /// Whether it's currently daytime (6 AM - 6 PM) in this city
  bool get isDaytime {
    final hour = currentTime.hour;
    return hour >= 6 && hour < 18;
  }

  String get displayName => '$name, $country';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldClockCity &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          timezone == other.timezone;

  @override
  int get hashCode => Object.hash(name, timezone);
}

/// City database with IANA timezones and fallback offsets in minutes.
/// These offsets are standard (non-DST) defaults. The API will update
/// them with the current DST-adjusted offset when fetched.
final List<WorldClockCity> availableCities = [
  // Americas
  WorldClockCity(name: 'Honolulu', country: 'USA', timezone: 'Pacific/Honolulu', utcOffsetMinutes: -600),
  WorldClockCity(name: 'Anchorage', country: 'USA', timezone: 'America/Anchorage', utcOffsetMinutes: -540),
  WorldClockCity(name: 'Los Angeles', country: 'USA', timezone: 'America/Los_Angeles', utcOffsetMinutes: -480),
  WorldClockCity(name: 'San Francisco', country: 'USA', timezone: 'America/Los_Angeles', utcOffsetMinutes: -480),
  WorldClockCity(name: 'Seattle', country: 'USA', timezone: 'America/Los_Angeles', utcOffsetMinutes: -480),
  WorldClockCity(name: 'Las Vegas', country: 'USA', timezone: 'America/Los_Angeles', utcOffsetMinutes: -480),
  WorldClockCity(name: 'Denver', country: 'USA', timezone: 'America/Denver', utcOffsetMinutes: -420),
  WorldClockCity(name: 'Phoenix', country: 'USA', timezone: 'America/Phoenix', utcOffsetMinutes: -420),
  WorldClockCity(name: 'Salt Lake City', country: 'USA', timezone: 'America/Denver', utcOffsetMinutes: -420),
  WorldClockCity(name: 'Chicago', country: 'USA', timezone: 'America/Chicago', utcOffsetMinutes: -360),
  WorldClockCity(name: 'Dallas', country: 'USA', timezone: 'America/Chicago', utcOffsetMinutes: -360),
  WorldClockCity(name: 'Houston', country: 'USA', timezone: 'America/Chicago', utcOffsetMinutes: -360),
  WorldClockCity(name: 'Mexico City', country: 'Mexico', timezone: 'America/Mexico_City', utcOffsetMinutes: -360),
  WorldClockCity(name: 'New York', country: 'USA', timezone: 'America/New_York', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Miami', country: 'USA', timezone: 'America/New_York', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Atlanta', country: 'USA', timezone: 'America/New_York', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Washington D.C.', country: 'USA', timezone: 'America/New_York', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Boston', country: 'USA', timezone: 'America/New_York', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Toronto', country: 'Canada', timezone: 'America/Toronto', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Lima', country: 'Peru', timezone: 'America/Lima', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Bogotá', country: 'Colombia', timezone: 'America/Bogota', utcOffsetMinutes: -300),
  WorldClockCity(name: 'Caracas', country: 'Venezuela', timezone: 'America/Caracas', utcOffsetMinutes: -240),
  WorldClockCity(name: 'Halifax', country: 'Canada', timezone: 'America/Halifax', utcOffsetMinutes: -240),
  WorldClockCity(name: 'Santiago', country: 'Chile', timezone: 'America/Santiago', utcOffsetMinutes: -240),
  WorldClockCity(name: 'São Paulo', country: 'Brazil', timezone: 'America/Sao_Paulo', utcOffsetMinutes: -180),
  WorldClockCity(name: 'Buenos Aires', country: 'Argentina', timezone: 'America/Argentina/Buenos_Aires', utcOffsetMinutes: -180),
  WorldClockCity(name: 'Rio de Janeiro', country: 'Brazil', timezone: 'America/Sao_Paulo', utcOffsetMinutes: -180),

  // Europe & Africa
  WorldClockCity(name: 'Reykjavik', country: 'Iceland', timezone: 'Atlantic/Reykjavik', utcOffsetMinutes: 0),
  WorldClockCity(name: 'London', country: 'UK', timezone: 'Europe/London', utcOffsetMinutes: 0),
  WorldClockCity(name: 'Dublin', country: 'Ireland', timezone: 'Europe/Dublin', utcOffsetMinutes: 0),
  WorldClockCity(name: 'Lisbon', country: 'Portugal', timezone: 'Europe/Lisbon', utcOffsetMinutes: 0),
  WorldClockCity(name: 'Casablanca', country: 'Morocco', timezone: 'Africa/Casablanca', utcOffsetMinutes: 0),
  WorldClockCity(name: 'Paris', country: 'France', timezone: 'Europe/Paris', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Berlin', country: 'Germany', timezone: 'Europe/Berlin', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Madrid', country: 'Spain', timezone: 'Europe/Madrid', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Rome', country: 'Italy', timezone: 'Europe/Rome', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Amsterdam', country: 'Netherlands', timezone: 'Europe/Amsterdam', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Brussels', country: 'Belgium', timezone: 'Europe/Brussels', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Lagos', country: 'Nigeria', timezone: 'Africa/Lagos', utcOffsetMinutes: 60),
  WorldClockCity(name: 'Cairo', country: 'Egypt', timezone: 'Africa/Cairo', utcOffsetMinutes: 120),
  WorldClockCity(name: 'Athens', country: 'Greece', timezone: 'Europe/Athens', utcOffsetMinutes: 120),
  WorldClockCity(name: 'Helsinki', country: 'Finland', timezone: 'Europe/Helsinki', utcOffsetMinutes: 120),
  WorldClockCity(name: 'Istanbul', country: 'Turkey', timezone: 'Europe/Istanbul', utcOffsetMinutes: 180),
  WorldClockCity(name: 'Moscow', country: 'Russia', timezone: 'Europe/Moscow', utcOffsetMinutes: 180),
  WorldClockCity(name: 'Riyadh', country: 'Saudi Arabia', timezone: 'Asia/Riyadh', utcOffsetMinutes: 180),
  WorldClockCity(name: 'Nairobi', country: 'Kenya', timezone: 'Africa/Nairobi', utcOffsetMinutes: 180),

  // Asia & Oceania
  WorldClockCity(name: 'Tehran', country: 'Iran', timezone: 'Asia/Tehran', utcOffsetMinutes: 210),
  WorldClockCity(name: 'Dubai', country: 'UAE', timezone: 'Asia/Dubai', utcOffsetMinutes: 240),
  WorldClockCity(name: 'Kabul', country: 'Afghanistan', timezone: 'Asia/Kabul', utcOffsetMinutes: 270),
  WorldClockCity(name: 'Karachi', country: 'Pakistan', timezone: 'Asia/Karachi', utcOffsetMinutes: 300),
  WorldClockCity(name: 'Mumbai', country: 'India', timezone: 'Asia/Kolkata', utcOffsetMinutes: 330),
  WorldClockCity(name: 'New Delhi', country: 'India', timezone: 'Asia/Kolkata', utcOffsetMinutes: 330),
  WorldClockCity(name: 'Colombo', country: 'Sri Lanka', timezone: 'Asia/Colombo', utcOffsetMinutes: 330),
  WorldClockCity(name: 'Kathmandu', country: 'Nepal', timezone: 'Asia/Kathmandu', utcOffsetMinutes: 345),
  WorldClockCity(name: 'Dhaka', country: 'Bangladesh', timezone: 'Asia/Dhaka', utcOffsetMinutes: 360),
  WorldClockCity(name: 'Bangkok', country: 'Thailand', timezone: 'Asia/Bangkok', utcOffsetMinutes: 420),
  WorldClockCity(name: 'Jakarta', country: 'Indonesia', timezone: 'Asia/Jakarta', utcOffsetMinutes: 420),
  WorldClockCity(name: 'Ho Chi Minh City', country: 'Vietnam', timezone: 'Asia/Ho_Chi_Minh', utcOffsetMinutes: 420),
  WorldClockCity(name: 'Beijing', country: 'China', timezone: 'Asia/Shanghai', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Shanghai', country: 'China', timezone: 'Asia/Shanghai', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Hong Kong', country: 'China', timezone: 'Asia/Hong_Kong', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Taipei', country: 'Taiwan', timezone: 'Asia/Taipei', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Singapore', country: 'Singapore', timezone: 'Asia/Singapore', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Perth', country: 'Australia', timezone: 'Australia/Perth', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Kuala Lumpur', country: 'Malaysia', timezone: 'Asia/Kuala_Lumpur', utcOffsetMinutes: 480),
  WorldClockCity(name: 'Seoul', country: 'South Korea', timezone: 'Asia/Seoul', utcOffsetMinutes: 540),
  WorldClockCity(name: 'Tokyo', country: 'Japan', timezone: 'Asia/Tokyo', utcOffsetMinutes: 540),
  WorldClockCity(name: 'Osaka', country: 'Japan', timezone: 'Asia/Tokyo', utcOffsetMinutes: 540),
  WorldClockCity(name: 'Adelaide', country: 'Australia', timezone: 'Australia/Adelaide', utcOffsetMinutes: 570),
  WorldClockCity(name: 'Sydney', country: 'Australia', timezone: 'Australia/Sydney', utcOffsetMinutes: 600),
  WorldClockCity(name: 'Melbourne', country: 'Australia', timezone: 'Australia/Melbourne', utcOffsetMinutes: 600),
  WorldClockCity(name: 'Brisbane', country: 'Australia', timezone: 'Australia/Brisbane', utcOffsetMinutes: 600),
  WorldClockCity(name: 'Auckland', country: 'New Zealand', timezone: 'Pacific/Auckland', utcOffsetMinutes: 720),
  WorldClockCity(name: 'Wellington', country: 'New Zealand', timezone: 'Pacific/Auckland', utcOffsetMinutes: 720),
];