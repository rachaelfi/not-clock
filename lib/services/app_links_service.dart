import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:not_clock/config/app_config.dart';
import 'package:not_clock/main.dart';

/// Rate, Share, Feedback, and outbound links, with the platform differences
/// handled in one place.
class AppLinksService {
  // ─── Rate ──────────────────────────────────────────────────────────────────

  /// Opens the store listing on the write-a-review screen.
  ///
  /// This is the only review path in the app, and it only runs when the user
  /// taps Rate app in Settings. Nothing prompts them anywhere else.
  static Future<void> rateApp(BuildContext context) async {
    // No app store in a browser. Say so instead of throwing.
    if (!AppConfig.isIOS && !AppConfig.isAndroid) {
      _notify(context, 'Rating is available in the iOS and Android apps.');
      return;
    }

    if (!AppConfig.hasStoreId) {
      _notify(
        context,
        AppConfig.isIOS
            ? 'Add your App Store ID to AppConfig first.'
            : 'Add your Android package id to AppConfig first.',
      );
      return;
    }

    try {
      await InAppReview.instance.openStoreListing(
        appStoreId: AppConfig.appStoreId,
      );
    } catch (_) {
      if (context.mounted) _notify(context, "Couldn't open the store.");
    }
  }

  // ─── Share ─────────────────────────────────────────────────────────────────

  /// Opens the system share sheet — AirDrop, Messages, Mail, Copy on iOS;
  /// the Sharesheet with whatever's installed on Android.
  ///
  /// [context] should be the context of the widget that was tapped, not the
  /// screen's. On iPad the share sheet is a popover that has to be anchored to
  /// something; passing the row's own context gives it the row's rect.
  static Future<void> shareApp(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${AppConfig.shareMessage}\n\n${AppConfig.shareUrl}',
          subject: AppConfig.shareSubject,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) _notify(context, "Couldn't open the share sheet.");
    }
  }

  // ─── Feedback ──────────────────────────────────────────────────────────────

  /// Opens the user's mail app with To, Subject, and a diagnostics footer
  /// already filled in, cursor in an empty message area above it.
  ///
  /// The From address fills itself in — it's whatever account their mail app
  /// is signed in to, typically the iCloud or Gmail address tied to their
  /// store account. An app cannot read or set that, and shouldn't be able to:
  /// it's the user's identity, and handing it to apps silently would be a
  /// privacy hole. Letting their own mail app supply it gets the same result
  /// with none of that.
  ///
  /// On iOS this opens Mail's compose screen — Cancel (which offers to save or
  /// delete the draft) top left, send arrow top right. Android opens whichever
  /// mail app they've set, or a chooser.
  static Future<void> sendFeedback(BuildContext context) async {
    if (AppConfig.supportEmail.isEmpty) {
      _notify(context, 'Add your support email to AppConfig first.');
      return;
    }

    final body = await _feedbackBody();

    // Build the query by hand rather than with Uri(queryParameters:), which
    // encodes spaces as "+" — several mail clients render those literally.
    final uri = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      query: 'subject=${Uri.encodeComponent(AppConfig.feedbackSubject)}'
          '&body=${Uri.encodeComponent(body)}',
    );

    try {
      final opened = await launchUrl(uri);
      if (opened) return;
    } catch (_) {
      // fall through to the copy fallback
    }

    // No mail app configured, or the launch was refused. Give them the
    // address rather than a dead end.
    if (context.mounted) _offerToCopyAddress(context);
  }

  /// Blank space to type in, then a diagnostics block.
  ///
  /// Device model, OS version, and app version are here because they turn
  /// "my alarm didn't go off" into something you can actually chase down.
  /// Deliberately NOT included: any install ID or UUID. There's no backend or
  /// crash reporting to correlate one against, so it would be a tracking
  /// identifier collected for nothing — and one you'd have to declare on the
  /// App Privacy and Data Safety forms.
  ///
  /// Everything here is visible in the draft before sending, and the user can
  /// delete any of it.
  static Future<String> _feedbackBody() async {
    final buffer = StringBuffer()
      ..writeln()
      ..writeln()
      ..writeln()
      ..writeln('———————————————')
      ..writeln('Please keep the details below — they help with debugging.')
      ..writeln('${AppConfig.appName} '
          '${AppConfig.appVersion} (${AppConfig.buildNumber})');

    final device = await _deviceLine();
    if (device != null) buffer.writeln(device);

    return buffer.toString();
  }

  /// "iPhone14,5 · iOS 18.2" or "Google Pixel 7 · Android 15 (SDK 35)".
  /// Null on web, where there's no meaningful device to report.
  static Future<String?> _deviceLine() async {
    if (kIsWeb) return null;

    try {
      final plugin = DeviceInfoPlugin();

      if (AppConfig.isIOS) {
        final ios = await plugin.iosInfo;
        // utsname.machine is the hardware identifier ("iPhone14,5") rather
        // than a marketing name. Less pretty, far more precise for bugs.
        return '${ios.utsname.machine} · iOS ${ios.systemVersion}';
      }

      if (AppConfig.isAndroid) {
        final android = await plugin.androidInfo;
        return '${android.manufacturer} ${android.model} · '
            'Android ${android.version.release} '
            '(SDK ${android.version.sdkInt})';
      }
    } catch (_) {
      // Diagnostics are a nicety — never block the email over them.
    }
    return null;
  }

  static void _offerToCopyAddress(BuildContext context) {
    final c = SettingsProvider.read(context).colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          'No mail app set up. Email ${AppConfig.supportEmail}',
          style: TextStyle(color: c.text),
        ),
        backgroundColor: c.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Copy',
          textColor: c.accentSoft,
          onPressed: () => Clipboard.setData(
            ClipboardData(text: AppConfig.supportEmail),
          ),
        ),
      ));
  }

  // ─── Links ─────────────────────────────────────────────────────────────────

  /// Opens [url] in the browser. [label] names the link in the message shown
  /// if the URL hasn't been filled in yet, e.g. "privacy policy".
  ///
  /// The launch mode differs by platform:
  ///
  ///   • Mobile — `externalApplication` hands off to Safari / Chrome rather
  ///     than an in-app web view. Better for legal pages, where people expect
  ///     a real browser with the address bar visible.
  ///
  ///   • Web — `externalApplication` calls `window.open`, which Chrome blocks
  ///     as a popup, so the launch fails and returns false. `platformDefault`
  ///     with `_blank` is what url_launcher_web is built around. If the
  ///     browser still refuses, we fall back to navigating the current tab,
  ///     which no popup blocker interferes with.
  static Future<void> openUrl(
    BuildContext context,
    String url, {
    required String label,
  }) async {
    if (url.isEmpty) {
      _notify(context, 'Add the $label URL to AppConfig first.');
      return;
    }

    final uri = Uri.tryParse(url);
    // Uri.parse happily accepts "example.com/page" with no scheme and then
    // fails to launch it, so check for one up front.
    if (uri == null || !uri.hasScheme) {
      _notify(context, 'The $label URL needs to start with https://');
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );

      if (opened) return;

      // New tab refused — on web, open in this tab instead.
      if (kIsWeb) {
        final sameTab = await launchUrl(uri, webOnlyWindowName: '_self');
        if (sameTab) return;
      }

      if (context.mounted) _notify(context, "Couldn't open the $label.");
    } catch (_) {
      if (context.mounted) _notify(context, "Couldn't open the $label.");
    }
  }

  // ─── Helper ────────────────────────────────────────────────────────────────

  static void _notify(BuildContext context, String message) {
    final c = SettingsProvider.read(context).colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, style: TextStyle(color: c.text)),
        backgroundColor: c.card,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }
}