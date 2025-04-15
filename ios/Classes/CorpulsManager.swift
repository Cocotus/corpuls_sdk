import CoreBluetooth
import CorpulsKit
import Flutter

public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?
    private var deviceID = ""
    private var deviceUUID = ""

    private init() {}

    public func initialize(channel: FlutterMethodChannel) {
        self.channel = channel
        self.sendLog("Initialisiere Corpuls Plugin.")

    }

    // Enum des Corpuls State aus DemoApp SyncViewController.swift Klasse
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
    private var state: State = .initial {
        didSet {
            guard state != oldValue else { return }
        }
    }

    private lazy var ble: CorpulsBLE = {
        let ble = CorpulsBLE.shared
        ble.settings = Settings(performDeviceIdentification: true, decgSpeed: .wide)

        ble.didUpdateSystemState = { [unowned self] state in
            switch state {
            case "unavailable":
                self.sendLog("BLE Modul: unavailable")
            case "disconnected":
                self.sendLog("BLE Modul: disconnected")
            case "scanning":
                self.sendLog("BLE Modul: scanning")
            case "selecting":
                self.sendLog("BLE Modul: selecting")
            case "connecting":
                self.sendLog("BLE Modul: connecting")
            case "connected":
                self.sendLog("BLE Modul: connected")
            case "syncing":
                self.sendLog("BLE Modul: syncing")
            case "success":
                self.sendLog("BLE Modul: success")
            default:
                self.sendLog("BLE Modul: Unbekannter State: \(state)")
            }
        }

        ble.didUpdateConnectionState = { [unowned self] isConnected in
            if isConnected {
                self.sendLog("Corpuls verbunden!")
            } else {
                self.sendLog("Corpuls NICHT verbunden/verfügbar!")
                self.state = ble.isEnabled ? .disconnected : .unavailable
                 // Automatically restart scanning if disconnected
                if self.state == .disconnected {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [unowned self] in
                                if self.state == .disconnected {
                                    self.sendLog("Scanne erneut nach Corpuls...")
                                    self.scanForDevices { result in
                                        self.sendLog("Scan Ergebnis: \(String(describing: result))")
                                    }
                                }
                            }
                  }
            }
}


        ble.didReceiveNotification = { [unowned self] (value, characteristic) in
            self.sendLog("Received notification from \(characteristic): \(value)")
        }

        ble.didUpdateAvailability = { [unowned self] isAvailable in
            if isAvailable && !ble.isConnected {
                self.sendLog("BLE module is available and not connected. Ready to scan.")
                self.scanForDevices { result in
                    self.sendLog("Scan Ergebnis: \(String(describing: result))")
                }
            }
        }

        return ble
    }()

public func connectCorpuls(result: @escaping FlutterResult) {
    // Überprüfen, ob BLE bereits eingerichtet ist
    if ble.isConnected {
        // Wenn ein Gerät bereits verbunden ist, gib das verbundene Gerät zurück
        let message = "Corpuls bereits verbunden! Gerät: " + self.deviceID
        self.sendLog(message)
        result(message)
        return
    }
    ble.setup() // Initialisiert BLE
    self.sendLog("Corpuls Bluetooth Modul initalisiert.")
    result("Corpuls Bluetooth Modul initalisiert.")
}

    public func scanForDevices(result: @escaping FlutterResult) {

        
        if ble.isConnected {
            // Wenn ein Gerät bereits verbunden ist, gib das verbundene Gerät zurück
            let message = "Corpuls bereits verbunden! Gerät: " + self.deviceID
            self.sendLog(message)
            result(message)
            return
        }

        guard ble.isEnabled else {
            let message = "Bluetooth Modul noch nicht bereit."
            sendLog(message)
            result(message)
            return
        }

        ble.scan(timeout: 2) { [unowned self] in
            switch $0 {
            case .success(let peripherals):
                if let firstPeripheral = peripherals.first {
                    ble.connect(to: firstPeripheral) { connectionResult in
                        switch connectionResult {
                        case .success:
                            self.deviceID = firstPeripheral.peripheral.name ?? ""
                            self.deviceUUID = firstPeripheral.id.uuidString
                            let message = "Mit Corpuls verbunden! UUID: \( firstPeripheral.id.uuidString ?? "Unknown Device")"
                            self.sendLog(message)
                            result(message) // Rückgabe des verbundenen Geräts
                        case .failure(let connectionError):
                            let errorMessage = "Fehler beim Verbinden: \(connectionError.localizedDescription)"
                            self.sendLog(errorMessage)
                            result(errorMessage) // Rückgabe eines Fehlers
                        }
                    }
                } else {
                    let message = "Keine Corpuls Geräte gefunden!"
                    self.sendLog(message)
                    result(message) // Rückgabe eines Fehlers
                }
            case .failure(let error):
                let errorMessage = "Suche mit Fehlern beendet: \(error.localizedDescription)"
                self.sendLog(errorMessage)
                result(errorMessage) // Rückgabe eines Fehlers
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
