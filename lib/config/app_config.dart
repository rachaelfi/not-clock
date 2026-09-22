import 'package:flutter/foundation.dart';

/// Everything that changes when the app is published lives here, so you don't
/// have to hunt through screens for it.
///
/// ⚠️ The three IDs below are placeholders. Fill them in before shipping —
/// `AppLinksService` shows an explanatory message rather than failing silently
/// while they're empty.
class AppConfig {
  /// Numeric App Store ID, digits only, no "id" prefix.
  /// Find it in App Store Connect → your app → App Information → Apple ID,
  /// or in the store URL: apps.apple.com/app/not-clock/id**1234567890**
  static const String appStoreId = '';

  /// Android application id. Must match `applicationId` in
  /// android/app/build.gradle — usually com.yourname.not_clock.
  static const String androidPackageId = '';

  /// Optional landing page. If you have one, it's the better thing to share:
  /// a single link that works for whoever receives it, iPhone or Android.
  /// Leave empty to share the platform-specific store URL instead.
  static const String websiteUrl = '';

  static const String appName = 'Not Clock';

  /// Keep in step with the `version:` line in pubspec.yaml. That line reads
  /// `1.0.0+1` — the part before + is [appVersion], the part after is
  /// [buildNumber].
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  /// Your name or studio name, for the copyright line.
  static const String developerName = '';

  /// First year the app shipped. The About footer shows a range up to the
  /// current year automatically — "© 2026" this year, "© 2026–2027" next.
  static const int copyrightStartYear = 2026;

  static const String tagline = 'Alarms, sleep, and a sky to fall asleep to.';

  static const String description =
      'Not Clock brings your alarms, world clocks, stopwatch, and timers '
      'together in one calm place. Set a sleep alarm and the Night Clock '
      'dims to a starry sky, then greets you with sunrise or daylight when '
      "it's time to get up.";

  // ─── Legal ─────────────────────────────────────────────────────────────────
  //
  // Both stores require a privacy policy URL on the listing itself, even for
  // apps that collect nothing. Linking it from About as well is the norm.

  static const String privacyPolicyUrl = '';
  static const String termsUrl = '';

  /// Shown as the email subject when someone shares to Mail.
  static const String shareSubject = 'Not Clock';

  static const String shareMessage =
      'Not Clock — alarms, sleep tracking, world clock, and a night sky to '
      'fall asleep to. Worth a look:';

  // ─── Derived URLs ──────────────────────────────────────────────────────────

  static String get appStoreUrl =>
      'https://apps.apple.com/app/id$appStoreId';

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$androidPackageId';

  /// True on iPhone and iPad. Uses `defaultTargetPlatform` rather than
  /// `dart:io`'s `Platform`, because `dart:io` doesn't exist on the web and
  /// would crash the app in Chrome.
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// The link to put in a shared message.
  static String get shareUrl {
    if (websiteUrl.isNotEmpty) return websiteUrl;
    return isIOS ? appStoreUrl : playStoreUrl;
  }

  /// Whether the ID needed on this platform has actually been filled in.
  static bool get hasStoreId =>
      isIOS ? appStoreId.isNotEmpty : androidPackageId.isNotEmpty;
}