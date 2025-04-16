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
            self.sendLog("Nachricht von Corpuls empfangen: \(value)")
        }
        
        ble.didUpdateAvailability = { [unowned self] isAvailable in
            if isAvailable && !ble.isConnected {
                self.sendLog("Bluetooth Modul initialisiert. Starte Suche nach Corpuls...")
                self.scanForDevices { result in
                    self.sendLog("Scan Ergebnis: \(String(describing: result))")
                }
            }
        }
        
        return ble
    }()
    
    public func connectCorpuls(uuid: String, result: @escaping FlutterResult) {
        // Überprüfen, ob BLE bereits eingerichtet ist
        if ble.isConnected {
            // Wenn ein Gerät bereits verbunden ist, gib das verbundene Gerät zurück
            let message = "Corpuls bereits verbunden! UUID: " + self.deviceUUID
            self.sendLog(message)
            result(message)
            return                                                                                                                                                                                                              
        }
        if self.state == .initial {
            self.deviceUUID = uuid
            self.state = .disconnected
            ble.setup() // Initialisiert BLE
            self.sendLog("Corpuls Bluetooth Modul initialisiert.")
            result("Corpuls Bluetooth Modul initialisiert.")
        }
     
    }
    
    private func scanForDevices(result: @escaping FlutterResult) {
        if ble.isConnected {
            // Wenn ein Gerät bereits verbunden ist, gib das verbundene Gerät zurück
            let message = "Corpuls bereits verbunden! ID: " + self.deviceUUID
            self.sendLog(message)
            return
        }
        
        guard ble.isEnabled else {
            let message = "Bluetooth Modul noch nicht bereit."
            sendLog(message)
            return
        }
        self.state = .scanning
        ble.scan(timeout: 2) { [unowned self] in
            switch $0 {
            case .success(let peripherals):
                if let firstPeripheral = peripherals.first {
                    state = .connecting(peripheral: firstPeripheral)
                    ble.connect(to: firstPeripheral) { connectionResult in
                        switch connectionResult {
                        case .success:
                            self.deviceID = firstPeripheral.peripheral.name ?? ""
                            self.deviceUUID = firstPeripheral.id.uuidString
                            let message = "Mit Corpuls verbunden! UUID: \( firstPeripheral.id.uuidString ?? "Unbekanntes Modell!")"
                            self.sendLog(message)
                        case .failure(let connectionError):
                            self.disconnect()
                            let errorMessage = "Fehler beim Verbinden des Corpuls: \(connectionError.localizedDescription)"
                            self.sendLog(errorMessage)
                        }
                    }
                } else {
                    let message = "Keine Corpuls Geräte gefunden!"
                    self.sendLog(message)
                }
            case .failure(let error):
                self.disconnect()
                let errorMessage = "Kein Corpuls gefunden!"
                self.sendLog(errorMessage)
            }
        }
    }
    
    private func disconnect() {
        ble.disconnect()
        self.state = .initial
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
