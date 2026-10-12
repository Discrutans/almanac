import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let messenger = registrar(forPlugin: "AlmanacHighRefreshRate")?.messenger() {
      let channel = FlutterMethodChannel(
        name: "com.example.almanac/high_refresh_rate",
        binaryMessenger: messenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "enable" else {
          result(FlutterMethodNotImplemented)
          return
        }
        if #available(iOS 10.3, *) {
          result(Double(UIScreen.main.maximumFramesPerSecond))
        } else {
          result(60.0)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
