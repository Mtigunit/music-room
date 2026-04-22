import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsAPIKey") as? String {
      let trimmedKey = mapsApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
      let hasUnresolvedPlaceholder =
        trimmedKey.contains("$(") && trimmedKey.contains(")")

      if !trimmedKey.isEmpty &&
        trimmedKey != "YOUR_API_KEY_HERE" &&
        !hasUnresolvedPlaceholder
      {
        GMSServices.provideAPIKey(trimmedKey)
      } else {
        #if DEBUG
          NSLog(
            "Google Maps API key is missing or invalid. " +
              "Check GoogleMapsAPIKey in Info.plist and Maps_API_KEY in Env.xcconfig."
          )
        #endif
      }
    } else {
      #if DEBUG
        NSLog(
          "Google Maps API key is missing in Info.plist. " +
            "Check GoogleMapsAPIKey key setup."
        )
      #endif
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
