import CoreBluetooth
import CorpulsKit
import Flutter

public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?
    private var deviceID = ""
    private var deviceUUID: UUID?
    
    private init() {}
    
    public func initialize(channel: FlutterMethodChannel) {
        self.channel = channel
        self.sendLog("Initialisiere Corpuls Plugin.")
    }
    
    // Enum, das den Corpuls-Status repräsentiert
    private enum State: Equatable {
        case initial, unavailable, disconnected, scanning, selecting, connecting(peripheral: CorpulsPeripheral), connected(peripheral: CBPeripheral), syncing, success
    }
    private var state: State = .initial {
        didSet {
            guard state != oldValue else { return }
        }
    }
    
    // Lazy-Initialisierung des BLE-Managers
    private lazy var ble: CorpulsBLE = {
        let ble = CorpulsBLE.shared
        ble.settings = Settings(performDeviceIdentification: true, decgSpeed: .wide)
        
        ble.didUpdateSystemState = { [unowned self] state in }
        
        ble.didUpdateConnectionState = { [unowned self] isConnected in
            handleConnectionStateChange(isConnected)
        }
        
        ble.didReceiveNotification = { [unowned self] (value, characteristic) in
            self.sendLog("Benachrichtigung von Corpuls empfangen: \(value)")
        }
        
        ble.didUpdateAvailability = { [unowned self] isAvailable in
            if isAvailable && !ble.isConnected {
                self.sendLog("Bluetooth-Modul initialisiert. Starte Gerätesuche...")
                self.startDeviceScan()
            }
        }
        
        return ble
    }()
    public func connectCorpuls(uuid: String, result: @escaping FlutterResult) {
        // Prüfen, ob BLE bereits verbunden ist
        if ble.isConnected {
            let message = "Corpuls bereits verbunden! UUID: \(self.deviceUUID?.uuidString ?? "")"
            self.sendLog(message)
            result(message)
            return
        }
        
        if uuid.isEmpty {
            self.deviceUUID = nil
            self.sendLog("Keine UUID übergeben. Es werden Corpuls Geräte gesucht...")
        } else {
            // Versuche, eine UUID aus dem String zu erstellen
            let  uuidObject =  UUID(uuidString: uuid)
            self.deviceUUID = uuidObject
        }
        
        
        
        // Falls der Status initial ist, initialisiere die Verbindung
        if self.state == .initial {
            self.state = .disconnected
            ble.setup()
            self.sendLog("Corpuls Bluetooth-Modul initialisiert.")
            result("Corpuls Bluetooth-Modul initialisiert.")
        }
    }
    
    private func startDeviceScan() {
        if self.deviceUUID != nil {
            self.scanForDevice(with: self.deviceUUID!)
        } else {
            self.scanForDevices()
        }
    }
    
    private func scanForDevice(with peerIdentifier: UUID) {
        guard ble.isEnabled else {
            self.sendLog("Bluetooth-Modul noch nicht bereit.")
            return
        }
        state = .scanning
        ble.scan(peerIdentifier: peerIdentifier) { [unowned self] result in
            handleScanResult(result)
        }
    }
    
    private func scanForDevices() {
        guard ble.isEnabled else {
            self.sendLog("Bluetooth-Modul noch nicht bereit.")
            return
        }
        
        state = .scanning
        ble.scan(timeout: 2) { [unowned self] result in
            switch result {
            case .success(let peripherals):
                if let firstPeripheral = peripherals.first {
                    connectToPeripheral(firstPeripheral)
                } else {
                    self.sendLog("Keine Corpuls Geräte gefunden!")
                    self.state = .disconnected
                }
            case .failure(let error):
                self.disconnect()
                self.sendLog("Gerätesuche fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleScanResult(_ result: Result<CorpulsPeripheral, SyncError>) {
        switch result {
        case .success(let peripheral):
            connectToPeripheral(peripheral)
        case .failure(let error):
            self.disconnect()
            self.sendLog("Gerätesuche fehlgeschlagen: \(error.localizedDescription)")
        }
    }
    
    private func connectToPeripheral(_ peripheral: CorpulsPeripheral) {
        state = .connecting(peripheral: peripheral)
        ble.connect(to: peripheral) { [unowned self] connectionResult in
            switch connectionResult {
            case .success:
                self.deviceID = peripheral.peripheral.name ?? ""
                self.deviceUUID = peripheral.id
                self.sendLog("Erfolgreich mit Corpuls verbunden! UUID: \(peripheral.id.uuidString)")
            case .failure(let error):
                self.disconnect()
                self.sendLog("Fehler beim Verbinden mit Corpuls: \(error.localizedDescription)")
            }
        }
    }
    
    private func disconnect() {
        self.sendLog("Schließe Bluetooth Modul")
        ble.disconnect()
        self.deviceUUID = nil
        self.state = .initial
    }
    
    private func handleConnectionStateChange(_ isConnected: Bool) {
        if isConnected {
            self.sendLog("Corpuls verbunden!")
        } else {
            self.sendLog("Corpuls nicht verbunden/verfügbar!")
            self.state = ble.isEnabled ? .disconnected : .unavailable
            if self.state == .disconnected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if self.state == .disconnected {
                        self.sendLog("Erneuter Scan nach Corpuls...")
                        self.scanForDevices()
                    }
                }
            }
        }
    }
    
    // MARK: - Flutter-Kommunikationsmethoden
    
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
            self.sendLog("Kein Corpuls Gerät gefunden!")
            self.channel?.invokeMethod("noCorpuls", arguments: nil)
        }
    }
    
    
}
