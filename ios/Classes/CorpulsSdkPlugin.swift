import Flutter
import UIKit

public class CorpulsSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "corpuls_sdk", binaryMessenger: registrar.messenger())
    let instance = CorpulsSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    CorpulsManager.shared.initialize(channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "scanForDevices":
      CorpulsManager.shared.scanForDevices(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}