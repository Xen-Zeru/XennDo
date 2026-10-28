import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var settingsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Use the engine registrar with Flutter's UIScene lifecycle, not window.
    let channel = FlutterMethodChannel(
      name: "xenndo/settings",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "canRequestNotificationPermission":
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          DispatchQueue.main.async {
            result(settings.authorizationStatus == .notDetermined)
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    settingsChannel = channel
  }
}
