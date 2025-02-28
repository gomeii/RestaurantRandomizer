import Flutter
import UIKit
import GoogleMaps

@UIApplication
@obc class AppDelegate: FlutterAppDelegate {
    override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Load API key from GoogleMaps-Info.plist
        if let path = Bundle.main.path(forResource: "GoogleMaps-Info", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path),
           let apiKey = dict["GOOGLE_MAPS_API_KEY"] as? String {
            GMSServices.provideAPIKey(apiKey)
        } else {
            print("⚠️ Google Maps API Key not found in GoogleMaps-Info.plist")
        }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
