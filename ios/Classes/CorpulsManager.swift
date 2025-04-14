import CoreBluetooth
import CorpulsKit
import Flutter

public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?

    private lazy var ble: CorpulsBLE = {
        let ble = CorpulsBLE.shared
        ble.settings = Settings(performDeviceIdentification: true, decgSpeed: .wide)

        ble.didUpdateSystemState = { state in
            // String 'state' can be used to update UI accordingly.
            // See documentation for possible values.
        }

        ble.didUpdateConnectionState = { [unowned self] isConnected in
            if isConnected {
                // Handle connection state update
            } else {
                // Handle disconnection
            }
        }

        ble.didReceiveNotification = { [unowned self] (value, characteristic) in
            // Handle received notification
        }

        ble.didUpdateAvailability = { [unowned self] isAvailable in
            if isAvailable && !ble.isConnected {
                // Handle device scan
            }
        }

        return ble
    }()

    private init() {}

    public func initialize(channel: FlutterMethodChannel) {
        self.channel = channel
        // Initialize any additional settings or listeners if needed
    }

    public func scanForDevices(result: @escaping FlutterResult) {
        ble.scan(timeout: 20) { [unowned self] in
            switch $0 {
            case .success(let peripherals):
                let deviceNames = peripherals.map { $0.peripheral.name ?? "Unknown Device" }
                self.sendDataToFlutter(deviceNames)
                result(deviceNames)
            case .failure(let error):
                result(FlutterError(code: "SCAN_FAILED", message: "Scan failed with error: \(error)", details: nil))
                self.notifyNoDataMobileMode()
            }
        }
    }

    // MARK: - Flutter Communication Methods

    func sendLog(_ message: String) {
        DispatchQueue.main.async {
            self.channel?.invokeMethod("log", arguments: message)
        }
    }

    func sendDataToFlutter(_ data: [String]) {
        DispatchQueue.main.async {
            self.channel?.invokeMethod("data", arguments: data)
        }
    }

    func notifyNoDataMobileMode() {
        DispatchQueue.main.async {
            self.sendLog("Kein Corpuls gefunden!")
            self.channel?.invokeMethod("noCorpuls", arguments: nil)
        }
    }
}
