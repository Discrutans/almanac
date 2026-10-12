import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.example.almanac/high_refresh_rate",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "enable" else {
        result(FlutterMethodNotImplemented)
        return
      }
      if #available(macOS 12.0, *) {
        result(Double(NSScreen.main?.maximumFramesPerSecond ?? 60))
      } else {
        result(60.0)
      }
    }

    super.awakeFromNib()
  }
}
