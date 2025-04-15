import CoreBluetooth
import CorpulsKit
import Flutter

public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?

    private lazy var ble: CorpulsBLE = {
        let ble = CorpulsBLE.shared
        ble.settings = Settings(performDeviceIdentification: true, decgSpeed: .wide)

        ble.didUpdateSystemState = { [unowned self] state in
            switch state {
            case "unavailable":
                self.sendLog("BLE module is unavailable.")
            case "disconnected":
                self.sendLog("BLE module is disconnected.")
            case "scanning":
                self.sendLog("BLE module is scanning for devices.")
            case "selecting":
                self.sendLog("BLE module is in selecting state.")
            case "connecting":
                self.sendLog("BLE module is connecting to a device.")
            case "connected":
                self.sendLog("BLE module is connected to a device.")
            case "syncing":
                self.sendLog("BLE module is syncing data.")
            case "success":
                self.sendLog("BLE module operation succeeded.")
            }
        }

        ble.didUpdateConnectionState = { [unowned self] isConnected in
            if isConnected {
                self.sendLog("Device connected successfully.")
            } else {
                self.sendLog("Device disconnected.")
            }
        }

        ble.didReceiveNotification = { [unowned self] (value, characteristic) in
            self.sendLog("Received notification from \(characteristic): \(value)")
        }

        ble.didUpdateAvailability = { [unowned self] isAvailable in
            if isAvailable && !ble.isConnected {
                self.sendLog("BLE module is available and not connected. Ready to scan.")
            }
        }

        return ble
    }()

    private init() {}

    public func initialize(channel: FlutterMethodChannel) {
        self.channel = channel
        self.sendLog("CorpulsManager initialized.")
    }

    public func scanForDevices(result: @escaping FlutterResult) {
        guard ble.isEnabled else {
            sendLog("BLE module is unavailable.")
            result(FlutterError(code: "BLE_UNAVAILABLE", message: "BLE module is unavailable.", details: nil))
            return
        }

        ble.scan(timeout: 2) { [unowned self] in
            switch $0 {
            case .success(let peripherals):
                if let firstPeripheral = peripherals.first {
                    ble.connect(to: firstPeripheral) { connectionResult in
                        switch connectionResult {
                        case .success:
                            self.sendLog("Connected to device: \(firstPeripheral.peripheral.name ?? "Unknown Device")")
                            result("Connected to device: \(firstPeripheral.peripheral.name ?? "Unknown Device")")
                        case .failure(let connectionError):
                            self.sendLog("Failed to connect: \(connectionError.localizedDescription)")
                            result(FlutterError(code: "CONNECT_FAILED", message: "Failed to connect to device", details: connectionError.localizedDescription))
                        }
                    }
                } else {
                    self.sendLog("No devices found during scan.")
                    result(FlutterError(code: "NO_DEVICES", message: "No devices found during scan.", details: nil))
                }
            case .failure(let error):
                self.sendLog("Scan failed with error: \(error.localizedDescription)")
                result(FlutterError(code: "SCAN_FAILED", message: "Scan failed with error: \(error)", details: nil))
            }
        }
    }

    public func getTrendData(result: @escaping FlutterResult) {
        self.sendLog("Requesting vital parameter trend data...")

        ble.requestVitalParameterTrend { [unowned self] response in
            switch response {
            case .success(let trend):

                self.sendLog("Trend data received successfully: \(trend)")
                result(trend)
            case .failure(let error):
                self.sendLog("Failed to retrieve trend data: \(error.localizedDescription)")
                result(FlutterError(code: "TREND_DATA_FAILED", message: "Failed to retrieve trend data", details: error.localizedDescription))
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