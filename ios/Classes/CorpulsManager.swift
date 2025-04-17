import CoreBluetooth
import CorpulsKit
import Flutter
import Foundation

class MedicalData: Codable {
    var mdeid: String = ""
    var einsatzstart: String = ""
    var einsatznummer: String = ""
    var medicaldeviceid: String = ""
    var caseid: String = ""
    
    struct PatientData: Codable {
        var id: String = ""
        var vorname: String = ""
        var nachname: String = ""
        var kassennummer: String = ""
        var kassenname: String = ""
        var versichertennummer: String = ""
        var versichertenstatus: String = ""
        var strasse: String = ""
        var plz: String = ""
        var stadt: String = ""
        var geburtsdatum: String = ""
        var alter: Int = 0
        var geschlecht: String = ""
        var gewicht: Int = 0
        var symptombeginn: String = ""
        var groesse: Int = 0
    }
    
    var patientdata: PatientData = PatientData()
    
    struct Data: Codable {
        var typ: String = ""
        var name: String = ""
        var data: String = ""
        var zeitpunkt: String = ""
    }
    
    var dataList: [Data] = []
    
    struct VitalData: Codable {
        var typ: String = ""
        var zeitpunkt: String = ""
        var value: Double = 0.0
    }
    
    var vitalDataList: [VitalData] = []
}



public class CorpulsManager {
    static let shared = CorpulsManager()
    private var channel: FlutterMethodChannel?
    private var deviceID = ""
    private var deviceUUID: UUID?
    private var trend: VitalParameterTrend?
    private var medicalData = MedicalData()
    
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
    
    private func getTrenddata(completion: @escaping (String) -> Void) {
        CorpulsBLE.shared.requestVitalParameterTrend { result in
            switch result {
            case .success(let trend):
                self.trend = trend
                var validEntries: [CorpulsKit.VitalParameterTrendEntry] = [] // Define a separate list for valid entries
                
                // Process entries
                validEntries = trend.entries.filter { $0.parameters.count > 0 }
                
                var vitalDataList: [MedicalData.VitalData] = [] // Neue Liste für VitalData erstellen
                
                for entry in validEntries {
                    let time = DateFormatter.shortTime.string(from: entry.entryDate)
                    for vitalParameter in entry.parameters {
                        let typeString = vitalParameter.typeString
                        let value = vitalParameter.value // Direkt auf den Wert zugreifen
                        // VitalData-Instanz erstellen
                        let vitalData = MedicalData.VitalData(typ: typeString, zeitpunkt: time, value: value)
                        // VitalData zur Liste hinzufügen
                        vitalDataList.append(vitalData)
                    }
                }
                
                // vitalDataList dem MedicalData-Objekt zuweisen
                self.medicalData.vitalDataList = vitalDataList
                
                do {
                    let jsonData = try JSONEncoder().encode(self.medicalData)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        print(jsonString)
                    }
                } catch {
                    print("Fehler beim Exportieren der Daten in JSON: \(error)")
                }
            case .failure(let error):
                self.sendLog("Failed to fetch trend data: \(error.localizedDescription)")
                completion("Error: \(error.localizedDescription)")
            }
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
                
                // Automatically fetch trend data
                self.getTrenddata { trendDataString in
                    self.sendLog(trendDataString)
                }
                
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
