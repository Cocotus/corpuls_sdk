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
    case "getPlatformVersion":
       let platformVersion = "iOS " + UIDevice.current.systemVersion
       CorpulsManager.shared.sendLog("getPlatformVersion called: \(platformVersion)")
       result(platformVersion)
    case "connectCorpuls":
            guard let args = call.arguments as? [String: Any],
                  let uuid = args["uuid"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid UUID.", details: nil))
                return
            }
            connectCorpuls(uuid: uuid, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}