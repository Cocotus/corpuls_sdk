<img src="corpuls_logo.png" alt="corpuls_logo" align="right" style="zoom:30%;" />

Version: 4.4.0.1
Date: 2024-10-11

[Downloads](https://my.corpuls.world/download/category/corpuls-sdk-software)

# Overview

## Intended use

The corpuls SDK is a software library to allow the exchange of information between corpuls devices and third party systems. Third party systems using the corpuls SDK can export data created and stored on corpuls devices. It also allows updating non-medical data on corpuls devices for administration purposes. The corpuls SDK and all data received from it is neither intended for medical decision making nor diagnosis and does not influence therapy.

## Goal

The goal of `CorpulsKit` is to provide a simple, effective interface to communicate over BLE with a *corpuls3* device. Values can be read from and written to the device. Also, BLE notifications are supported. All technical details related to Bluetooth are encapsulated within the SDK, so no expertise with BLE is required to exchange data. The public interface of the SDK is named `CorpulsBLE`.

## Versioning

The BLE functionality of a *corpuls3* can only be used with a compatible firmware version `>= 4.2.0`. Some features require newer versions. The framework versioning scheme was updated. Starting with version `4.3.0.0`, the `CorpulsKit` framework version will always be aligned with the respective software version of the *corpuls3*. As a compatibility side note, version `4.3.0.0` essentially matches version `1.2.0` in the old versioning scheme, so no breaking changes were introduced, despite the big jump in the major version.

## Characteristics

By means of BLE all data is exhanged via so called *Characteristics*. Values can be requested by using the desired enum value of type `Characteristic`:

`CorpulsBLE.shared.request(.deviceName)`

This will asynchronously return a `Result<CharacteristicValue, SyncError>`. In case of success, the `CharacteristicValue` can be tested against the desired value type to retrieve its model data. In case of failure, a typed `SyncError` is returned, stating the reason of failure.

```swift
CorpulsBLE.shared.requestCharacteristic(.availableDECGs) { [weak self] in
    guard let self else { return }

    switch $0 {
    case .success(let value):
        if case .availableDECGs(let indices) = value {
            let decgOverviewViewController = DECGOverviewViewController(decgIndices: indices)
            navigationController.pushViewController(decgOverviewViewController, animated: true)
        }

    case .failure(let error):
        showError(error)
    }
}
```

## General notes

Time-related variables suffixed by the term `Offset` (e.g. `missionStartOffset`) typically contain an integer value represented in *milliseconds* - unless stated otherwise.

# Project setup

## Environment

The `CorpulsKit` SDK is provided as a universal framework (`.xcframework`) and thus supports multiple architectures flexibly. The *Deployment Target* of the framework is *iOS 15.2* and typically is compiled against the most recent production *Base SDK*, currently *iOS 17.5* using *Xcode 15.4*. The SDK supports all recent iPhones and iPads.

## Setup instructions

1. The framework needs to be integrated into an existing Xcode project by dragging it into the section *Frameworks, Libraries and Embedded Content* on the *General* tab of the project.

2. After that, the option *Embed & Sign* needs to be chosen so the framework gets copied over into the *Frameworks* section of your app bundle and is properly signed.

3. In your app's `Info.plist` you need to declare the `NSBluetoothAlwaysUsageDescription` with a proper explanation.

4. Finally, you can use the provided functionality by importing it into your classes with `import CorpulsKit`.

5. The public interface of the SDK is named `CorpulsBLE`. You can easily access it via a singleton provided by the SDK: `CorpulsBLE.shared`. For simplicity, we will assume the following local reference: `let ble = CorpulsBLE.shared`

6. Initialize the Bluetooth environment of the SDK via `ble.setup`()

7. Query BLE availability with `ble.isEnabled`

8. Scan for surrounding *corpuls3* devices with `ble.scan()`. In case of success, a list of `CorpulsPeripheral` instances is returned which will represent the *corpuls3* devices near you. The list is sorted by their signal strength (RSSI) in descending order, so the device with the best signal strength is at the beginning of the list. The SDK only scans for actual *corpuls3* devices, so other BLE devices are ignored.

9. Starting with version `4.3.0.0` of the `CorpulsKit` SDK a `CorpulsPeripheral` does also include a `deviceIdentifier` property. This represents the particular field on the *corpuls3* that allows for easy identification for scenarios where multiple *corpuls3* devices reside in the same area close-by. If you are interested in using this property you can do so by opting into this feature via the `Settings` model belonging to the `CorpulsBLE` instance:
   ```swift
   ble.settings = Settings(performDeviceIdentification: true,
                           decgSpeed: .wide)
   ```

   **Note:** this feature also requires a corpuls3 software version `>= 4.3.0`. Scanning *corpuls3* devices in order to retrieve their *device identifier* does *not* require pairing.

9. Starting with version `4.4.0.0` of the `CorpulsKit` SDK it is also possible to scan for a specific *corpuls3* that matches a given `deviceIdentifier`. Instead of a list of *corpuls3* devices this will return the first *corpuls3* that uses the requested `deviceIdentifier`. This is very convenient if you already are aware of a specific *corpuls3* device you are looking for.
   
10. If you have found a *corpuls3* peripheral you're interested in, you can now connect to it with `ble.connect(to: peripheral)`

## Usage

1. If the peripheral of the *corpuls3* was successfully connected (as described in the previous section), you can now perform `READ` and `WRITE` requests in order to exchange data.

2. The pairing status of the *corpuls3* peripheral is checked automatically after connecting to it. If the device is not paired, a pairing request is performed. You will need to type in the six digit code presented on the *corpuls3* peripheral into the text field shown on your mobile device. At any given time, the paring status can be queried by calling `ble.isPaired`. It will only return `true` if you are currently connected to a *corpuls3* peripheral and the pairing process has succeeded before. For as long as the pairing is not revoked on either the *corpuls3* peripheral or the mobile device you won't be asked again for authentication.

3. The SDK provides a simple callback mechanism to inform the app about several asynchronous events:

   1. `didUpdateConnectionState`: Returns if a *corpuls3* is currently connected
   2. `didUpdateAvailability`: Returns if BLE is currently available, i.e. is activated and ready for scanning devices
   3. `didReceiveNotification`: Returns a notification event as tuple consisting of a `String` and its originating `Characteristic` to identify the payload.

4. Regular Characteristics can be read by performing `ble.requestCharacteristic()` with the required type.

5. Vital Parameters can be queried the same way, but there is a convenience function provided for those, as they are very common: `ble.requestVitalParameters()` 

   ```swift
   ble.requestVitalParameters { [weak self] in
       guard let self else { return }
   
       switch $0 {
       case .success(let vitalParameterList):
           let vitalParameterViewController = VitalParameterViewController(vitalParameterList: vitalParameterList)
            navigationController.pushViewController(vitalParameterViewController, animated: true)
   
       case .failure(let error):
           showError(error)
       }
   }
   ```

6. To provide a better insight into a patient's data over time, Vital Parameter trends can be queried. Calling the function below will yield a`VitalParameterTrend` instance in case of success. From there, the individual `VitalParameterTrendEntry` instances can be retrieved. For every minute since the start of a mission, one entry is created that contains the average data of available Vital Parameters within that minute. Also the `missionCreationDate` as well as the `missionStartOffset` (in milliseconds) can be retrieved and some convenience functions are provided to retrieve all numeric values of a particular `VitalParameterType` within that `VitalParameterTrend`. Please be advised that it is entirely possible that some Vital Parameters won't provide an actual value for some entries as their availability depends on the sensors you have attached to your *corpuls3* device. If a `VitalParameterTrendEntry` does not provide any values, its `parameters` field will be empty.

   ```swift
   ble.requestVitalParameterTrend { [weak self] in
       guard let self else { return }
   
       switch $0 {
       case .success(let trend):
           setupChart(for: trend)
   
       case .failure(let error):
           presentError(error)
       }
   }
   ```
   
7. NIBP values over time can also be retrieved from the `VitalParameterTrend`. This object provides a reference named `nibpValues` that returns a list of `NIBPValue` objects that allows for easy filtering. Its properties are:

   ```swift
   - date: Date // timestamp of corresponding VitalParameterTrendEntry
   - entryMinute: UInt // nth minute of entry since mission creation date
   - systolic: UInt
   - diastolic: UInt
   - mad: UInt
   - qualityIndicator: NIBPQualityIndicator // range: poor (0) - excellent (3)
   ```
   
   For debugging purposes, a `VitalParameterTrend` provides a property named `formattedNibpString` to print the current state of all available NIBP values on the command line. It provides the information available by the `NIBPValue` models in a simple tabular format:
   
   ```diff
   -------------------------------------------------
   Mission start: 2022-03-17T14:52:14.0+01:00
   NIBP # values: 4
   -------------------------------------------------
   011: 2022-03-17T15:02:33.4+01:00 - 123/83(96) ***
   013: 2022-03-17T15:04:43.3+01:00 - 122/82(95) **
   015: 2022-03-17T15:06:53.4+01:00 - 122/82(95) ***
   017: 2022-03-17T15:09:03.4+01:00 - 122/82(95) **
   -------------------------------------------------
   ```
   
8. *DECGs* can be queried with the function `requestDECG()`. The first parameter is the `query`. The next is a closure that is triggered whenever the synchronization progresses (value is a discrete percentage `Double` within interval `[0;1]`). The last parameter is the completion handler. In case of success a `Data` object is returned which represents a *DECG* Report in PDF format. This `Data` object easily can be visualized with a `PDFView` or a `WKWebView`. Also, it can be persisted to the file system, like any regular `Data` object. Synchronizing *DECG* data takes some time as its payload is considerably larger than those of the other Characteristics. You can expect a total transfer time of ~ 16 seconds per DECG report.

   ```swift
   ble.requestDECG(by: .latest) { progress in
       print(progress)
   } completion: {
       switch $0 {
       case .success(let decgData):
           // use a PDFView or similar means to show data
   
       case .failure(let error):
           // handle SyncError
       }
   }
   ```


The `query` parameter is an `enum` type consisting of three options:

   - `latest`: request the most recent *DECG* that is available
   - `earliest`: request the oldest *DECG* that is available. The BLE interface of the *corpuls3* provides access to the most recent 5 *DECGs* of a mission. So `earliest` would actually request the oldest of those five DECGs
   - `index`: request a *DECG* by its explicit index. After mission creation, the first available index of a DECG starts with `1` and is counted upwards. Only an index specified in the DECG overview (see Characteristic `availableDECGs`) is considered valid

9. Starting with version `4.3.0.0`, the SDK supports both *25 mm/s*  and *50 mm/s* DECG reporting speeds. By using the former, you will be able to fit the DECG curve of any particular lead on a single DIN A4 page in landscape format. The latter will provide more detail, but requires two DIN A4 pages in landscape to plot the whole standard ECG curve (10 seconds). You can define your preference via the `Settings` model. The `wide` setting is used as a default (50 mm/s).

   ```swift
   ble.settings = Settings(performDeviceIdentification: true,
                           decgSpeed: .narrow) // narrow = 25 mm/s, wide = 50 mm/s
   ```


10. Also, the SDK now supports displaying curves more flexibly. This comes in handy for scenarios where you don't use all ECG patches on a patient. As such, not all leads will provide data. The new DECG report will only include curves that actually contain data to preserve space.

11. Some Characteristics also provide a `WRITE` interface. Values can easily be updated by performing the function `ble.writeValue()`, whereas the parameter is of type `CharacteristicValue` and allows for convenient, type-safe value updates.

12. Single patient values can be updated as well with this function:

   ```swift
   ble.writePatientValue(.firstname("Steve")) { [weak self] in
       guard let self else { return }
   
       switch $0 {
       case .success:
           // updating value finished successfully
   
       case .failure(let error):
           showError(error)
       }
   }
   ```

13. The `CorpulsKit` SDK internally uses a retry mechanism to minimize the occurrence of failed requests that might happen due to timeouts and interferences in the field.

14. Scanning for devices can be stopped manually by performing `ble.stopSync()`.

15. If a persistent BLE connection is not needed anymore, it can be disconnected by using the respective function `ble.disconnect().`

16. Some Characteristics support the `notify` mechanism to propagate live updates of their values. Notifications can be enabled / disabled for a particular Characteristic by performing `ble.subscribe()` and `ble.unsubscribe()`, respectively. Also, a convenience function is provided to check if a Characteristic currently is subscribed for receiving notifications.

17. Starting with version `4.4.0.0` of the SDK the ID of the current mission can be requested from the corpuls3. This also requires at least `4.4.0` of the corpuls3 software. This ID exists in two variants:

    - `full`: Contains the numeric ID of the mission, the serial number of the *Patient Module* and an additional randomized identifier.
      Example: `20240822094815-DE00001AAB387401-F7C1FD4F`
    - `short`: Contains only the numeric mission ID, represented as a `String`
      Example: `20240822094815`

    ```swift
    ble.requestMissionId(length: .full) { [weak self] in
        guard let self else { return }
    
        switch $0 {
        case .success(let missionID):
            // process missionID
    
        case .failure(let error):
            showError(error)
        }
    }
    ```


18. Starting with version `4.4.0.0` of the SDK Events can be requested from the corpuls3. This also requires at least `4.4.0` of the corpuls3 software. Events are generated for a lot of useful actions and situations. The complete list of available Events is specified in the enum type `EventIdentifier` in the SDK. For example, the corpuls3 creates events when starting a mission,  saving a new `DECG`, updating Patient data etc. Events can be retrieved either since the start of the mission (default value is `0`) or from any given offset (in milliseconds) since mission start. This makes it possible to synchronize events in batches, e.g. once every minute. The filter closure provides the capability to selectively choose events of relevance for the given use case. This provides a flexible option to filter by `identifier`, `missionStartOffset` or the event's `parameters` (array of `Int` values).

    ```swift
    ble.requestEvents(missionStartOffset: 0) {
        $0.identifier == .EVT_ECG_DECG_SAVED || $0.identifier == .EVT_OPER_PATDATA_WRITE
    } completion: { [weak self] in
        guard let self else { return }
    
        switch $0 {
        case .success(let eventData):
          // process eventData.events
    
        case .failure(let error):
            showError(error)
        }
    }
    ```

19. Starting with version `4.4.0.0` of the SDK function calls are guarded against the software version of the *corpuls3*. This means that if a recent `CorpulsKit` version is used for querying data from an older *corpuls3* software version, this request will yield an error if the respective function is not yet available in the *corpuls3* software:

    ```
    Function 'requestVitalParameterTrend' requires at least corpuls3 software version '4.2.1'
    ```

    

# Available Characteristics

The following section provides a list of all supported Characteristics. Brackets will denote their individual capabilites:

| Capability | Description                                                      |
| ---------- | ---------------------------------------------------------------- |
| r          | Characteristic can be read                                       |
| w          | Characteristic can be written to                                 |
| n          | Characteristic supports sending out notifications as live events |



## `deviceName` [r]

The name of the corpuls3 as a BLE peripheral, currently `corpuls3-ble`. The device can be discovered and paired by this name.

## `appearance` [r]

The category of BLE devices. Always returns `0` for *unspecified device type*.

## `manufacturerName` [r]

Manufacturer name of the *corpuls3*. Always returns *GS Elektromedizinische Geraete G. Stemple GmbH*.

## `modelNumber` [r]

Model type of device. Always returns value `corpuls3`. 

## `serialNumber` [r]

The globally unique serial number of the *corpuls3* BLE module.
**Note:** Starting with version 4.4.0 of the corpuls3 software this serial number represents the serial number of the Patient Module (PAM).

Example: `DE000001234567890`

## `firmwareRevision` [r]

Returns the internal revision of the BLE GATT profile as an Integer.
Example: `8`

## `softwareRevision` [r]

The software revision of the corpuls3 itself.
Example: `REL-4.4.0_C3_BP`

## `currentDisplayTime` [r]

Current system time of the *corpuls3*, represented as an ISO 8601 encoded string.
Example: `2022-03-02T14:11:01.0+01:00`

## `vitalParameters` [r]

Returns a `VitalParameterList` model with an optional timestamp for `NIBP` and a list of all recent `VitalParameter` values. A `VitalParameter` has a `type`, a `unit` and an actual value, represented by a `Double`.

**Note:** Values typically are only available when actually measured. Even when the *corpuls3* is in *DEMO* mode, the *NIBP* value needs to be requested / created explicity with the *corpuls3*. Also, Vital Parameters can only be requested once every 60 seconds due to rate limiting.

Supported types are:

| Type       | Unit    | Example Value |
| :--------- | ------- | ------------- |
| HR_DEFI    | [1/min] | 60            |
| HR_DISPLAY | [1/min] | 60            |
| PP         | [1/min] | 61            |
| SPO2       | %       | 98.0          |
| SPO2_PI    | %       | 10.0          |
| NIBP_SYS   | mmHg    | 120           |
| NIBP_DIA   | mmHg    | 80            |
| NIBP_MAD   | mmHg    | 98            |
| IBP_P1_SYS | mmHg    | 120           |
| IBP_P1_DIA | mmHg    | 80            |
| IBP_P1_MAD | mmHg    | 98            |
| IBP_P2_SYS | mmHg    | 120           |
| IBP_P2_DIA | mmHg    | 80            |
| IBP_P2_MAD | mmHg    | 98            |
| IBP_P3_SYS | mmHg    | 120           |
| IBP_P3_DIA | mmHg    | 80            |
| IBP_P3_MAD | mmHg    | 98            |
| IBP_P4_SYS | mmHg    | 120           |
| IBP_P4_DIA | mmHg    | 80            |
| IBP_P4_MAD | mmHg    | 98            |
| CO2_ENS    | mmHg    | 42.0          |
| CO2_RR     | 1/min   | 14            |
| TEMP1      | °C      | 37.1          |
| TEMP2      | °C      | 37.2          |
| SPCO       | %       | 2             |
| SPHB       | g/dl    | 12.80         |
| SPMET      | %       | 0.1           |
| CPR_RATE   | 1/min   | 113           |
| NIBP_QI    | *       | ``***``       |

## `patientId` [r, w, n]

The patient's identifier.

## `patientData` [r, w, n]

A patient's main data:

- `firstname`
- `lastname`
- `birthdate` (format: `yyyy-MM-dd`)
- `age` (`UInt`)
- `sex` (`male`, `female`, `unknown`)
- `race` (`none`, `african`, `caucasian`, `pacific`, `asian`, `indian`, `unknown`)
- `weight (UInt)`
- `height (UInt)`
- `symptomOnset (String)`

**Note:** If the `birthdate` is stated explicitly, the patient's `age` is calculated implicitly. If however just a patient's `age` is known, his/her `birthdate` value is reset.

## `patientAddress` [r, w, n]

The residence address of the patient:

- `street`
- `postal code`
- `city`

## `caseNumber` [r, w, n]

The case number of the respective mission.

## `insuranceData` [r, w, n]

Data describing the insurance of the patient:

- insurance company name
- insurance company number
- insurance policy number
- insurance status
- insurance card number

## `medicalTeam` [r, w, n]

The medical team of the patient, represented as an array of `Strings`.

## `organisationData` [r, w, n]

Data describing the organization itself:

- EMS location
- organisation number
- organisation name

## `contactInfos` [r, w, n]

Contact information relevant to the mission:

- callback number
- radio identifier
- transport type

## `deviceId` [r, w, n]

The device identifier of the corpuls3. 

## `availableDECGs` [r]

Returns an overview of available *DECGs*. Only the most recent 5 *DECGs* of the current mission can be received from the corpuls3. Result contains an array of `DECGIndex` values whose fields are:

- `index`: absolute index of the *DECG* belonging to the current mission. Starts with `1` and is counted upwards.
- `date`: Timestamp when the *DECG* was created, i.e. persisted to the *CF card* of the *corpuls3*.

## `requestDECG` [r, w]

Is used to request a *DECG* by its index.
Example: if *DECG* with index `3` is to be requested, the Characteristic will be written with value `"3"`. After writing this index, the *corpuls3* validates the index, prepares all *DECG* data as an encrypted archive and makes it available for the next Characteristic where the data finally can be read. 

## `decgData` [r, n]

Is used to read prepared *DECG* data. This wil synchronize the data via BLE and create a PDF report from it. The result is then returned as a `Data` object, representing that PDF.

## `trendConfig` [r, w]

Is used to initiate Vital Parameter trend data. For now, the synchronization is initiated by any data that is written to this Characteristic. In future releases, this Characteristic will be extended to configure the expected data as needed. It is recommended to call the function `requestVitalParameterTrend()` instead of using this Characteristic. Requires a corpuls3 firmware with version `>= 4.2.1`.

## `trendData` [r, n]

Returns Vital Parameter trend data and maps it to a `VitalParameterTrend` instance. From there, the individual `VitalParameterTrendEntry` instances can be retrieved. For every minute since the start of a mission, one entry is created that constains the average data of available Vital Parameters within that minute. Also the `missionCreationDate` as well as the `missionStartOffset` (in milliseconds) can be retrieved and some convenience functions are provided to retrieve all numeric values of a particular `VitalParameterType` within that `VitalParameterTrend`. It is recommended to call the function `requestVitalParameterTrend()` instead of using this Characteristic. Requires a corpuls3 firmware with version `>= 4.2.1`.

## `commonConfig` [r, w, n]

Is used to configure and initiate various data transfers (e.g. for retrieving the current ID and Events from a mission). It is recommended to call the respective convenience functions instead of using this Characteristic directly. Requires a *corpuls3* firmware with version `>= 4.4.0`.

## `commonData` [r, n]

Is used to receive various data transfers (e.g. for retrieving the current ID and Events from a mission) after the transfer was configured via `commonConfig`. It is recommended to call the respective convenience functions instead of using this Characteristic directly. Requires a *corpuls3* firmware with version `>= 4.4.0`.

# Validation

Starting with version `4.3.0.0`, the SDK validates the maximum length of data to be transmitted before sending it to the *corpuls3* peripheral. This is the case for both the maxium length of a characteristic as well as its individual components (in case of characteristics which are assembled by multiple values). If payload validation fails, you will receive a `SyncError` of these types _before_ the data was sent:

```swift
SyncError.componentLengthExceeded
SyncError.characteristicLengthExceeded
```

Also, these types will include additional information about the actually failed component as well as the exceeded number of bytes. You can access this information via the property `errorDescription`. 
