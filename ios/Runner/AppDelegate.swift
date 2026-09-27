import Flutter
import UIKit
import UserNotifications
import alarm

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Route notification callbacks to this delegate, so tapping the alarm
    // notification opens the app instead of being swallowed.
    UNUserNotificationCenter.current().delegate = self

    // Registers the background task that lets a scheduled alarm survive the
    // app being suspended. Must run before the app finishes launching — iOS
    // rejects a task registered any later.
    SwiftAlarmPlugin.registerBackgroundTasks()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}