import CoreBluetooth
import CorpulsKit
import Flutter

public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?

    private init() {}

    public func initialize(channel: FlutterMethodChannel) {
        self.channel = channel
        self.sendLog("Initialisiere Corpuls Plugin.")
    }

    // Enum to represent the state, inspired by SyncViewController
    private enum State: Equatable {
        case initial
        case unavailable
        case disconnected
        case scanning
        case selecting
        case connecting(peripheral: CorpulsPeripheral)
        case connected(peripheral: CBPeripheral)
        case syncing
        case success
    }

    // State property
    private var state: State = .initial {
        didSet {
            guard state != oldValue else { return }
            // Handle state changes here if necessary
        }
    }

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
            default:
                self.sendLog("Unknown BLE state: \(state)")
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



public func scanForDevices(result: @escaping FlutterResult) {
    guard ble.isEnabled else {
        let message = "BLE module is unavailable."
        sendLog(message)
        result(message) // Return a string
        return
    }

    ble.scan(timeout: 2) { [unowned self] in
        switch $0 {
        case .success(let peripherals):
            if let firstPeripheral = peripherals.first {
                ble.connect(to: firstPeripheral) { connectionResult in
                    switch connectionResult {
                    case .success:
                        let message = "Connected to device: \(firstPeripheral.peripheral.name ?? "Unknown Device")"
                        self.sendLog(message)
                        result(message) // Return a string
                    case .failure(let connectionError):
                        let errorMessage = "Failed to connect: \(connectionError.localizedDescription)"
                        self.sendLog(errorMessage)
                        result(errorMessage) // Return a string
                    }
                }
            } else {
                let message = "No devices found during scan."
                self.sendLog(message)
                result(message) // Return a string
            }
        case .failure(let error):
            let errorMessage = "Scan failed with error: \(error.localizedDescription)"
            self.sendLog(errorMessage)
            result(errorMessage) // Return a string
        }
    }
}

    private func handleError(_ error: Error) {
        self.state = .disconnected // Update state to disconnected on error
        self.sendLog("Error occurred: \(error.localizedDescription)")
    }

    // MARK: - Flutter Communication Methods

    func sendLog(_ message: String) {
        #if DEBUG
        print(message)
        #endif
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
            self.sendLog("No Corpuls device found!")
            self.channel?.invokeMethod("noCorpuls", arguments: nil)
        }
    }
}
