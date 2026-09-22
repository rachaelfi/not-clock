import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:not_clock/config/app_config.dart';
import 'package:not_clock/main.dart';

/// Rate and Share, with the platform differences handled in one place.
class AppLinksService {
  // ─── Rate ──────────────────────────────────────────────────────────────────

  /// Opens the store listing on the write-a-review screen.
  ///
  /// This is the only review path in the app, and it only runs when the user
  /// taps Rate app in Settings. Nothing prompts them anywhere else.
  ///
  /// `openStoreListing` does the right thing per platform:
  ///   • iOS     — itms-apps://…/id<ID>?action=write-review, straight to the
  ///               review composer
  ///   • Android — market://details?id=<package>, the Play listing with the
  ///               star widget at the top
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
      if (context.mounted) {
        _notify(context, "Couldn't open the store.");
      }
    }
  }

  // ─── Share ─────────────────────────────────────────────────────────────────

  /// Opens the system share sheet — AirDrop, Messages, Mail, Copy on iOS;
  /// the Sharesheet with whatever's installed on Android.
  ///
  /// [context] should be the context of the widget that was tapped, not the
  /// screen's. On iPad the share sheet is a popover that has to be anchored to
  /// something; passing the row's own context gives it the row's rect. Without
  /// an origin it either lands in the top-left corner or throws outright.
  static Future<void> shareApp(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${AppConfig.shareMessage}\n\n${AppConfig.shareUrl}',
          // Used as the subject line if they pick Mail. Ignored elsewhere.
          subject: AppConfig.shareSubject,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _notify(context, "Couldn't open the share sheet.");
      }
    }
  }

  // ─── Links ─────────────────────────────────────────────────────────────────

  /// Opens [url] in the browser. [label] names the link in the message shown
  /// if the URL hasn't been filled in yet, e.g. "privacy policy".
  ///
  /// `externalApplication` hands off to Safari / Chrome rather than an in-app
  /// web view — better for legal pages, where people expect a real browser
  /// with the address bar visible.
  static Future<void> openUrl(
    BuildContext context,
    String url, {
    required String label,
  }) async {
    if (url.isEmpty) {
      _notify(context, 'Add the $label URL to AppConfig first.');
      return;
    }

    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _notify(context, "Couldn't open the $label.");
      }
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