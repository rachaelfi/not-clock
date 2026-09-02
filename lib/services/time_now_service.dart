import 'dart:convert';
import 'package:http/http.dart' as http;

/// Response model from the time.now API
class TimeNowResponse {
  final String timezone;
  final String datetime;
  final int unixtime;
  final String utcOffset;
  final String abbreviation;
  final bool dst;
  final int dstOffset;
  final String clientIp;

  const TimeNowResponse({
    required this.timezone,
    required this.datetime,
    required this.unixtime,
    required this.utcOffset,
    required this.abbreviation,
    required this.dst,
    required this.dstOffset,
    required this.clientIp,
  });

  factory TimeNowResponse.fromJson(Map<String, dynamic> json) {
    return TimeNowResponse(
      timezone: json['timezone'] as String? ?? '',
      datetime: json['datetime'] as String? ?? '',
      unixtime: json['unixtime'] as int? ?? 0,
      utcOffset: json['utc_offset'] as String? ?? '+00:00',
      abbreviation: json['abbreviation'] as String? ?? '',
      dst: json['dst'] as bool? ?? false,
      dstOffset: json['dst_offset'] as int? ?? 0,
      clientIp: json['client_ip'] as String? ?? '',
    );
  }

  /// Parse the utc_offset string (e.g. "+05:30", "-04:00") into total minutes.
  int get utcOffsetMinutes {
    try {
      final sign = utcOffset.startsWith('-') ? -1 : 1;
      final cleaned = utcOffset.replaceAll(RegExp(r'[+-]'), '');
      final parts = cleaned.split(':');
      final hours = int.parse(parts[0]);
      final minutes = parts.length > 1 ? int.parse(parts[1]) : 0;
      return (hours * 60 + minutes) * sign;
    } catch (_) {
      return 0;
    }
  }
}

/// Service for interacting with the time.now API
class TimeNowService {
  static const String _baseUrl = 'https://time.now/developer/api';

  /// Fetch time data for a specific IANA timezone
  static Future<TimeNowResponse?> fetchTimezone(String timezone) async {
    try {
      final url = Uri.parse('$_baseUrl/timezone/$timezone');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TimeNowResponse.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetch time data based on the user's IP address (auto-detect location)
  static Future<TimeNowResponse?> fetchByIp() async {
    try {
      final url = Uri.parse('$_baseUrl/ip');
      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return TimeNowResponse.fromJson(json);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}