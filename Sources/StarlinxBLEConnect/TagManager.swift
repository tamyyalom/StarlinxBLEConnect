//
//  ConnectToTag.swift
//  lynx
//
//  Created by rivki glick on 14/12/2020.
//

import UIKit
import CoreBluetooth
import NordicDFU

class TagManager: NSObject, CBCentralManagerDelegate,  UIPopoverPresentationControllerDelegate, CBPeripheralDelegate, DFUServiceDelegate, DFUProgressDelegate {
    
    private var centralManager: CBCentralManager!
    public var connected = false
    
    weak var delegate: TagManagerProtocol?
    private var peripheralP: CBPeripheral!
    private var dfuController: DFUServiceController!
    private var UUIDService: CBUUID?
    private var UUIDCharacteristics: CBUUID?
    var peripheral: DiscoveredPeripheral!
    private var discoveredPeripherals = [DiscoveredPeripheral]()
    private var filteredPeripherals = [DiscoveredPeripheral]()
    
    var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    let reconnectInterval = 15 // seconds
    var timerForScanning: Timer?
    var reconnectCount = 0
    
    func start(serviceKey: String, characteristicKey: String, deviceId: String, completionHandler: @escaping (_ succes: Bool, _ message: String) -> Void) {
        
        centralManager = CBCentralManager(delegate: self, queue: nil/*, options: [CBCentralManagerOptionRestoreIdentifierKey: device_id]*/)

        let permission = checkPermission()
        if permission == .allowedAlways {
            
            let deviceKey = deviceId.suffix(12)
            let serviceId = serviceKey + deviceKey
            let characteristics = characteristicKey + deviceKey
            UUIDService = CBUUID(string: serviceId)
            UUIDCharacteristics = CBUUID(string: characteristics)
            
            centralManager.scanForPeripherals(withServices: [UUIDService!], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
            
            completionHandler(true, "")
        } else {
            var message = String()
            
            switch permission  {
                case .notDetermined:
                    message = "Bluetooth is not Determined"
                case .restricted:
                    message = "Bluetooth state is restricted"
                case .denied:
                    message = "Bluetooth is denied"
                default:()
            }
            LogHelper.logError(err: message)
            completionHandler(false, message)
        }
    }
    
    func updateTagVersion(url: String) {
        
        guard let firmware = DFUFirmware(urlToZipFile: URL(string: url)!) else {
            LogHelper.logError(err: "updata tag version: can not create Firmware")
            
//            callback(.failure(QuickError(message: "Can not create Firmware")))
            return
        }
        LogHelper.logDebug(message: "updata tag version: success")
        
        let initiator = DFUServiceInitiator().with(firmware: firmware)
        
        initiator.delegate = self
        initiator.progressDelegate = self
        initiator.enableUnsafeExperimentalButtonlessServiceInSecureDfu = true
        dfuController = initiator.start(target: peripheralP)
    }
    
    
    func checkPermission() -> CBManagerAuthorization {
        CBCentralManager.authorization
    }
    
    func isConnected() -> Bool {
        return connected
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Find peripheral among already discovered ones, or create a new object if it is a new one.
        
        var discoveredPeripheral = discoveredPeripherals.first(where: { $0.basePeripheral.identifier == peripheral.identifier })
        
        discoveredPeripheral = DiscoveredPeripheral(peripheral)
        discoveredPeripherals.append(discoveredPeripheral!)
        self.peripheral = discoveredPeripheral
        print(peripheral)
        peripheralP = peripheral
        
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        
        if let peripheralsObject = dict[CBCentralManagerRestoredStatePeripheralsKey] {
            let peripherals = peripheralsObject as! Array<CBPeripheral>
            guard peripherals.count > 0 else { return }
            LogHelper.logDebug(message: "Peripheral found")
            
            let peripheral = peripherals[0]
            let discoveredPeripheral = DiscoveredPeripheral(peripheral)
            discoveredPeripherals.append(discoveredPeripheral)
            self.peripheral = discoveredPeripheral
            peripheral.delegate = self
            
            if self.peripheral.basePeripheral.state == .connected {
                centralManager.stopScan()
                
                connected = true
                delegate?.didChangeStatus(state: .connected)
                
                peripheral.discoverServices([UUIDService!])
                central.connect(peripheral, options: nil)
            }
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        print(peripheral)
        centralManager.stopScan()
        
        delegate?.didChangeStatus(state: .connecting)
        peripheral.delegate = self
        if let UUIDService = UUIDService {
            peripheral.discoverServices([UUIDService])
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error:Error?) {
        
        LogHelper.logError(err: "peripheral didFailToConnect")
        connected = false

        if UIApplication.shared.applicationState == .background && reconnectCount < 4 {
//            self.tryReconnect(central, to: peripheral)
        } else {
            delegate?.didChangeStatus(state: .disconnected)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        LogHelper.logError(err: "peripheral didDisconnectPeripheral")
        
        guard let cbError = error as? CBError else { return }
        
        print(cbError.localizedDescription)
        LogHelper.logError(err: "\(cbError.localizedDescription)!!!!!!!!!!")
        
        if cbError.code == .peripheralDisconnected || cbError.code == .connectionTimeout {
            
            centralManager = nil
            
        } else {
            let name = UUIDService?.uuidString
            if cbError.code == .unknown && peripheral.name == name {
                central.connect(peripheral, options: nil)
            }
        }
        
        connected = false
        delegate?.didDisconnect()
        delegate?.didChangeStatus(state: .disconnected)
        
        if UIApplication.shared.applicationState == .background && reconnectCount < 4 {
//            self.tryReconnect(central, to: peripheral)
        } else {
            var discoveredPeripheral = discoveredPeripherals.first(where: { $0.basePeripheral.identifier == peripheral.identifier })
            if discoveredPeripheral == nil {
                discoveredPeripheral = DiscoveredPeripheral(peripheral)
                discoveredPeripherals.append(discoveredPeripheral!)
                self.peripheral = discoveredPeripheral
            }
        }
    }
    
    private func tryReconnect(_ central: CBCentralManager, to peripheral: CBPeripheral) {
        reconnectCount += 1
        LogHelper.logError(err: "try Reconnect!!!!")
        DispatchQueue.main.async { // while in background mode Timer would work only being in main queue
            self.backgroundTaskId = UIApplication.shared.beginBackgroundTask (withName: "reconnectAgain") {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                self.backgroundTaskId = .invalid
            }
            
            self.timerForScanning?.invalidate()
            self.timerForScanning = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.reconnectInterval), repeats: false) { _ in
//                if CurrentTripManager.shared.getCurrentTrip() == nil {
//                    //TODO: - check this!
//                    let arrayOfServices: [CBUUID] = [McuMgrBleTransport.SMP_SERVICE]
//                    self.centralManager.scanForPeripherals(withServices: arrayOfServices, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
//                } else {
                    central.connect(peripheral, options: [:])
//                }
                UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                self.backgroundTaskId = .invalid
            }
        }
    }
    
    func stopLookingForTag() {
        if centralManager != nil {
            centralManager = nil
            backgroundTaskId = .invalid
            timerForScanning?.invalidate()
            timerForScanning = nil
            delegate?.didChangeStatus(state: .disconnected)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Check for error.
        guard error == nil else {
            //            lock.open(error)
            return
        }
        
        let s = peripheral.services?.map({ $0.uuid.uuidString }).joined(separator: ", ")
            ?? "none"
        //        log(msg: "Services discovered: \(s)", atLevel: .verbose)
        
        // Get peripheral's services.
        guard let services = peripheral.services else {
            return
        }
        // Find the service matching the SMP service UUID.
        for service in services {
            if service.uuid == UUIDService {
                peripheral.discoverCharacteristics([UUIDCharacteristics!], for: service)
                return
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        guard error == nil else { return }
        
        // Get service's characteristics.
        guard let characteristics = service.characteristics else { return }
        
        // Find the characteristic matching the SMP characteristic UUID.
        for characteristic in characteristics {
            if characteristic.uuid == UUIDCharacteristics {
                if ((characteristic.properties.contains(.notify))) {
                    peripheral.setNotifyValue(true, for: characteristic)
                    //Do your Write here
                }
                if characteristic.properties.contains(.write) {
                    peripheral.writeValue(Data([1]), for: characteristic, type: .withResponse)
                    connected = true
                    reconnectCount = 0
           
                    delegate?.didChangeStatus(state: .connected)
                }
                return
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
                           error: Error?) {
        
        guard characteristic.uuid == UUIDCharacteristics, error == nil else { return }

        connected = true
        reconnectCount = 0
        delegate?.didChangeStatus(state: .connected)
        
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        guard characteristic.uuid == UUIDCharacteristics, error == nil else { return }
        
        guard let data = characteristic.value else { return }
        
        delegate?.readTagValue(data: data)
        print(data)
    }
    
    // MARK: - DFUProgressDelegate
    
    func dfuProgressDidChange(for part: Int, outOf totalParts: Int, to progress: Int, currentSpeedBytesPerSecond: Double, avgSpeedBytesPerSecond: Double) {
        LogHelper.logDebug(message: "dfuProgressDidChange")
        
        delegate?.dfuProgressDidChange(part: part, totalParts: totalParts, to: progress)
    }
    
    func dfuStateDidChange(to state: DFUState) {
        LogHelper.logDebug(message: "dfuProgressDidChange")

        if state == .completed {
            dfuController = nil
        }

        print(state.description())
        delegate?.dfuStateDidChange(state: state)
    }
    
    func dfuError(_ error: DFUError, didOccurWithMessage message: String) {
        dfuController = nil
        LogHelper.logError(err: "dfuError")
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if central.state != .poweredOn {
            LogHelper.logError(err: "Central is not powered on")
        } else {
            centralManager.scanForPeripherals(withServices: [UUIDService!], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
}
