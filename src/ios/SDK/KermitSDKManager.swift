//
//  EKBTConnectionManager.swift
//  Mobile-Kermit-SDK-iOS
//
//  Created by Ravi Deshmukh on 28/01/19.
//  Copyright © 2019 Pfizer Inc. All rights reserved.
//

import UIKit
import CoreBluetooth

enum CommandType {
  case waitingForDeviceInfo
  case waitingForNACKDeviceInfo
  case waitingForOperationsRecords
  case waitingForCancelAcknowledgement
  case waitingForAddInjectorData
  case waitingForEraseInjectorData
  case idle
}
enum ConnectionState {
  case none
  case connecting
  case connected
  case faild
  case disconnecting
  case disconnected
}
enum ScanState {
  case none
  case scanning
  case scanned
  case failed
}
//TOTO remove this after done with final product
enum DeviceTypes {
  case SimulatorInjector
  case ActualInjector
}
protocol KermitSDKManagerDelegate {
  func onScanCompleted(devices: String)
  func onConnectionStateChanged(connectionState: ConnectionState)
  func onCommandResponse(command: String, response: String)
  func onSuccess(message: String)
  func onFailed(error: String)
}

class KermitSDKManager: NSObject {
  static let sharedSDKManager = KermitSDKManager()
  // Setup basic Bluetooth variables
  var centralManager: CBCentralManager!
  var peripheralManager: CBPeripheralManager!
  var service: CBMutableService!
  // Define required Bluetooth constants
  let serviceName = KermitConstants.serviceName
  var eKMonitorPeripheral: CBPeripheral!
  var eKMonitorServiceCBUUID = CBUUID(string: KermitConstants.uartServiceUUIDString)
  var eKMonitorTXCharacteristicCBUUID = CBUUID(string: KermitConstants.uartTXCharacteristicUUIDString )
  var eKMonitorRXCharacteristicCBUUID = CBUUID(string: KermitConstants.uartRXCharacteristicUUIDString )
  fileprivate var ekuartRXCharacteristic        : CBCharacteristic?
  fileprivate var ekuartTXCharacteristic        : CBCharacteristic?
  // Manage sending and receiving data
  var responseString = ""     // Accumulating what we get back from the device
  var pendingData:NSData!     // Data to be re-sent
  var commandTypeState = CommandType.idle
  var connectionState = ConnectionState.none
  var scanState = ScanState.none
  //TODO: need to remove when done with final product
  var deviceType = DeviceTypes.SimulatorInjector
  // Report to calling object
  var ekSDKDelegate: KermitSDKManagerDelegate?
  var reAttemptCounter : Int!
  var advertisedDataArray = [[String : Any]]()
  var advertisedDataForSelectedDevice = [String : Any]()
  var peripheralArray = Array<CBPeripheral>()
  
  //Request Timeout
  var timer: Timer!
  var scanTimer : Timer!
  class func isBluetoothSupported()-> Bool {
    if let _ = NSClassFromString("CBPeripheralManager") {
      return true
    }
    return false
  }
  
  // MARK: -- Initializers
  override init() {
    super.init()
     //TODO: remove when no need  of simulator injector app
      if deviceType == .SimulatorInjector {
        eKMonitorServiceCBUUID = CBUUID(string: KermitConstants.uartServiceUUIDSimulatorString)
        eKMonitorTXCharacteristicCBUUID = CBUUID(string: KermitConstants.uartTXCharacteristicUUIDSimulatorString )
        eKMonitorRXCharacteristicCBUUID = CBUUID(string: KermitConstants.uartRXCharacteristicUUIDSimulatorString )
      }
      let opts = [CBCentralManagerOptionShowPowerAlertKey: true]
      centralManager = CBCentralManager(delegate: self, queue: nil, options: opts)
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
  }
  /*
   * get the scanning status is true or false
   */
  func isScanning() -> Bool {
      return scanState == .scanning ? true : false
  }
  /*
   * scan the peripheral Device
   */
  func startScanning() {
      scanState = .scanning
      if centralManager.state == .poweredOn {
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false , CBConnectPeripheralOptionNotifyOnDisconnectionKey : true])
        timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
         scanTimer = Timer.scheduledTimer(timeInterval: 20, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
      }else {
        scanState = .failed
        ekSDKDelegate?.onFailed(error: "Please make sure Bluetooth is power on.")
      }
   
  }
  /*
   * stop scanning the peripheral Device
   */
  func stopScanning() {
      if centralManager.isScanning {
        centralManager.stopScan()
        scanState = .failed
      }
  }
  /*
   *connecting and paring the peripheral device
   */
  func connect(deviceAddress: String) {
      if peripheralManager != nil && centralManager != nil {
        for adData in advertisedDataArray {
          if let uuids = adData["kCBAdvDataServiceUUIDs"] {
            let uuid = String(describing: uuids)
            let id = String(uuid.filter { !" \n\t\r".contains($0) })
            if deviceAddress == id {
              centralManager.connect(eKMonitorPeripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true])
              self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
            }
          }
        }
      }
      connectionState = .connecting
  }
  /*
   * disconecting the peripheral Device
   */
  func disconnect() {
      guard let peripheral = eKMonitorPeripheral else { return }
      centralManager.cancelPeripheralConnection(peripheral)
  }
 
  
  // MARK: - Enabling, disabling and advertising the service
  
  func enableService() {
    
      // If the service is already registered, re-register it.
      if service != nil { peripheralManager.remove(service) }
    
      // Service needs to be "primary" to work when app is in background.
      service = CBMutableService(type: eKMonitorServiceCBUUID, primary: true)
      let cbProperties = CBCharacteristicProperties.notify.rawValue|CBCharacteristicProperties.write.rawValue|CBCharacteristicProperties.read.rawValue
      let cbPermissions = CBAttributePermissions.readable.rawValue|CBAttributePermissions.writeable.rawValue
      ekuartRXCharacteristic = CBMutableCharacteristic(type: eKMonitorRXCharacteristicCBUUID, properties: CBCharacteristicProperties(rawValue: cbProperties), value: nil, permissions: CBAttributePermissions(rawValue: cbPermissions))
      ekuartTXCharacteristic = CBMutableCharacteristic(type: eKMonitorTXCharacteristicCBUUID, properties: CBCharacteristicProperties(rawValue: cbProperties), value: nil, permissions: CBAttributePermissions(rawValue: cbPermissions))
      service.characteristics = ([ekuartRXCharacteristic , ekuartTXCharacteristic] as! [CBCharacteristic])
      peripheralManager.add(service)
  }
  
  func disableService() {
      guard peripheralManager != nil else {
        ekSDKDelegate?.onFailed(error: "\nPlease make sure device's bluetooth is on!!!")
        return
      }
      guard service != nil else {
        ekSDKDelegate?.onFailed(error: "\nPlease make sure device's bluetooth is on!!!")
        return
      }
      peripheralManager.remove(service)
      service = nil
      stopAdvertising()
  }
  
  func startAdvertising() {
      if peripheralManager.isAdvertising {
        peripheralManager.stopAdvertising()
      }
      let advertisment = [
          CBAdvertisementDataServiceUUIDsKey: [eKMonitorServiceCBUUID],
          CBAdvertisementDataLocalNameKey: serviceName
          ] as [String : Any]
        peripheralManager.startAdvertising(advertisment)
  }
  
  func stopAdvertising() {
      peripheralManager.stopAdvertising()
  }
  
  var isAdvertising: Bool {
      return peripheralManager.isAdvertising
  }
  
  // MARK: -- Commands
  
  /*
     Request to peripheral for give the device information i.e madel name ,serial number, battery level , injuction number and injection day etc.
   */
  func getDeviceInformation(){
      guard let _ = eKMonitorPeripheral else {
       ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
        self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        responseString = ""
        commandTypeState =  .waitingForDeviceInfo
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.getDeviceInformation()
          sendToSubscribers(data: command.data(using: .utf8))
        }catch let error {
          print(error)
        }
      }
  }
  /*
   *Request to peripheral for get operations records.
   */
  func getAllOperationsRecord() {
      guard let _ = eKMonitorPeripheral else {
       ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
        self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        responseString = ""
        commandTypeState = .waitingForOperationsRecords
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.getOperationFrom(recordNumber: 0)
          sendToSubscribers(data: command.data(using: .utf8))
        }
        catch let error {
          print(error)
        }
      }
  }
  func getOperationsRecordFrom(count: Int) {
     guard let _ = eKMonitorPeripheral else {
        ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
         self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        responseString = ""
        commandTypeState = .waitingForOperationsRecords
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.getOperationFrom(recordNumber: count)
          sendToSubscribers(data: command.data(using: .utf8))
        }
        catch let error {
          print(error)
        }
      }
  }
  
  /*
   *send the operation records for feeding into peripheral
   */
  func addOperationRecord(values: String) {
  //    sendAddInjectorDataCommand(time:String, injectionType: String, drugName:String, volume:Double, unit: String , resultCode: String) {
      guard let _ = eKMonitorPeripheral else {
        ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
        self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        responseString = ""
        commandTypeState = .waitingForAddInjectorData
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.addInjectionData(values: values)
          sendToSubscribers(data: command.data(using: .utf8))
        }catch let error {
          print(error)
        }
      }
  }
  /*
   * send command for invalid response
   */
  //TODO: remove this when implement the actual inavlid data from peripheral
  func sendAddInvalidInjectorDataCommand() {
      guard let _ = eKMonitorPeripheral else {
       ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
        self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        responseString = ""
        commandTypeState = .waitingForNACKDeviceInfo
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.addInvalidInjectionData()
          sendToSubscribers(data: command.data(using: .utf8))
        }
        catch let error {
          print(error)
        }
      }
  }
  /*
   *Request for earase the peripheral filled data
   */
  func clearOperationRecords() {
     guard let _ = eKMonitorPeripheral else {
       ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      if commandTypeState == .idle {
        responseString = ""
        commandTypeState = .waitingForEraseInjectorData
        self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
        print("Connection State = \(connectionState)")
        do {
          let command = try KermitSDK.shared.eraseInjectionData()
          sendToSubscribers(data: command.data(using: .utf8))
        }
        catch let error {
          print(error)
          
        }
      }
  }
  /*
   *Request for cancel the current command request.
   */
  func cancelProcess() {
        print("Connection State = \(connectionState)")
      guard let _ = eKMonitorPeripheral else {
       ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
        return
      }
      commandTypeState = .waitingForCancelAcknowledgement
      self.timer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(self.requestTimeout), userInfo: nil, repeats: false)
      let command = KermitSDK.shared.cancelCurrentRequest()
      sendToSubscribers(data: command.data(using: .utf8))
  }
  
  /*
    this method is used to communicate with the device. Using this method perform read , write and notify operation with peripheral
   */
  func sendToSubscribers(data: Data?) {
      guard peripheralManager.state == .poweredOn else {
        print("sendToSubscribers: peripheral not ready for sending state \(peripheralManager.state)")
        return
      }
      guard let data = data else { return }
        // working with actual device
        guard let char  = ekuartRXCharacteristic else{
          ekSDKDelegate?.onFailed(error:"\n Characteristics not available")
          return}
        guard let periP = eKMonitorPeripheral else {
        self.ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
          return }
        if deviceType == .SimulatorInjector {
          guard peripheralManager.updateValue(data, for: char as! CBMutableCharacteristic, onSubscribedCentrals: nil) else {
            print("Failed to send data, buffering data for retry once ready.")
            pendingData = data as NSData
            return
          }
        }else {
          periP.writeValue(data, for: char, type: .withResponse)
          
        }
  }
  
  // MARK: -- Parse the response
  func parseResponse(response: String) {
      // Check for correct starting and ending control characters
      let sendCommand = commandTypeState == .waitingForDeviceInfo ? "get_device_information": commandTypeState == .waitingForOperationsRecords ? "get_operation_from," : commandTypeState == .waitingForAddInjectorData ? "set_operation" : commandTypeState == .waitingForEraseInjectorData ? "clr_operation" : commandTypeState == .waitingForNACKDeviceInfo ? "NACK" : commandTypeState == .waitingForCancelAcknowledgement ? "CAN" : ""
      let res = commandTypeState == .waitingForAddInjectorData ? "ACK" : commandTypeState == .waitingForEraseInjectorData ? "ACK" : commandTypeState == .waitingForNACKDeviceInfo ? "NACK" : commandTypeState == .waitingForCancelAcknowledgement ? "ACK" : response
        print("\n 1. Command Sent to Injection = \(sendCommand) \n 2. Response Received from Injection = \(res)")
        if response.starts(with: KermitConstants.STX) && String(response.last!) == KermitConstants.ETX {
               if commandTypeState == .idle {
              commandTypeState = .waitingForOperationsRecords
            }
          if !response.contains(KermitConstants.EOT) {
            responseString = "\(responseString)\(response.dropFirst().dropLast())"
          }
          // Cases related to characters ACK, EOT which all comes from Injector
            if response == KermitConstants.noDataAvailable {
              responseString = ""
              ekSDKDelegate?.onCommandResponse(command: sendCommand, response: "\nNo data Available...")
              commandTypeState = .idle
            }
            else if response == KermitConstants.EOT {
                // --> Last packet of a series of packets
                // Append cleaned string to the response string
                let responseString1 = responseString.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
                //responseString = ""
                print("Final Response Recieved from Injector = \(responseString1)")
              if commandTypeState == .waitingForDeviceInfo {
                    // Send ACK back to Injector
                    guard let _ = KermitSDK.deviceInformationFromDevice(responseString1.data(using: .utf8)!) else {
                      ekSDKDelegate?.onFailed(error: "\nFaulty payload")
                      //sendToSubscribers(data: KermitConstants.NAK.data(using: .utf8))
                      commandTypeState = .idle
                      responseString = ""
  //                    retryCount += KermitConstants.one_Value
  //                    print("Faulty payload")
  //                    ekSDKDelegate?.didReceiveError(reason: "\nFaulty payload")
  //                    if retryCount < KermitConstants.max_retryCount {
  //                      sendToSubscribers(data: KermitConstants.NAK.data(using: .utf8))
  //                    }else {
  //                      ekSDKDelegate?.didReceiveError(reason: "\nUnable to fetch data")
  //                      retryCount = KermitConstants.zero_Value
  //                      commandTypeState = .idle
  //                    }
                      return
                    }
  //                retryCount = KermitConstants.zero_Value
                    ekSDKDelegate?.onCommandResponse(command: sendCommand, response: responseString1)
                    sendToSubscribers(data: KermitConstants.ACK.data(using: .utf8))
                    commandTypeState = .idle
                   responseString = ""
                }
                else if  commandTypeState == .waitingForOperationsRecords {
                  guard let _ = KermitSDK.recordsArrayFromDevice(responseString1.data(using: .utf8)!) else {
                      sendToSubscribers(data: KermitConstants.NAK.data(using: .utf8))
                      ekSDKDelegate?.onFailed(error:"\nFaulty payload")// TODO: Use try-catch
                      commandTypeState = .idle
                     responseString = ""
                    //                    retryCount += KermitConstants.one_Value
                    //                    print("Faulty payload")
                    //                    ekSDKDelegate?.didReceiveError(reason: "\nFaulty payload")
                    //                    if retryCount < KermitConstants.max_retryCount {
                    //                      sendToSubscribers(data: KermitConstants.NAK.data(using: .utf8))
                    //                    }else {
                    //                      ekSDKDelegate?.didReceiveError(reason: "\nUnable to fetch data")
                    //                      retryCount = KermitConstants.zero_Value
                    //                      commandTypeState = .idle
                    //                    }
                      return
                  }
  //                retryCount = KermitConstants.zero_Value
                  sendToSubscribers(data: KermitConstants.ACK.data(using: .utf8))
                  ekSDKDelegate?.onCommandResponse(command: sendCommand, response: responseString1)
                   commandTypeState = .idle
                  responseString = ""
                }
                else {
                  // TODO: Add further delegate whenever needed
                }
            }
            else if response == KermitConstants.ACK {
            
                // Right now, Injector sends ACK only for cancel comand
                if commandTypeState == .waitingForCancelAcknowledgement {
                  responseString = ""
                  commandTypeState = .idle
                  ekSDKDelegate?.onCommandResponse(command: sendCommand, response: res)
                  return
                }
                else if  commandTypeState == .waitingForAddInjectorData {
                  commandTypeState = .idle
                  ekSDKDelegate?.onCommandResponse(command: sendCommand, response: res)
                }
                else if  commandTypeState == .waitingForEraseInjectorData{
                  commandTypeState = .idle
                 ekSDKDelegate?.onCommandResponse(command: sendCommand, response: res)
                }
            }
            else if response == KermitConstants.NACK {
                commandTypeState = .idle
                ekSDKDelegate?.onCommandResponse(command: sendCommand, response: res)
            }else {
                sendToSubscribers(data: KermitConstants.ACK.data(using: .utf8))
            }
        }else {
            ekSDKDelegate?.onFailed(error:"\nInvalid packet received.......")
            return
        }
  }
  private func deviceData(from characteristic: CBCharacteristic) -> String {
      guard let characteristicData = characteristic.value else { return "" }
      return String(data: characteristicData , encoding: String.Encoding.utf8) ?? ""
  }
  /*
   *Request time out method
   */
  @objc func requestTimeout() {
      if scanState == .scanning {
        stopScanning()
      }else if connectionState == .connecting {
        connectionState = .none
      }
      ekSDKDelegate?.onFailed(error: "Request Timeout")
      invalidateTimer()
      commandTypeState = .idle
  }
  func invalidateTimer() {
      if timer != nil {
        timer.invalidate()
        timer = nil
      }
    if scanTimer != nil {
      scanTimer.invalidate()
      scanTimer = nil
    }
  }
  func stopScanningForTimeInterval() {
      if scanState == .scanning {
        stopScanning()
      }
      invalidateTimer()
  }
}

// MARK: -- CBCentralManagerDelegate
extension KermitSDKManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
      centralManager = central
      switch central.state {
      case .unknown:
        print("central.state is .unknown")
      case .resetting:
        print("central.state is .resetting")
      case .unsupported:
        print("central.state is .unsupported")
      case .unauthorized:
        print("central.state is .unauthorized")
      case .poweredOff:
        print("central.state is .poweredOff")
      case .poweredOn:
          print("central.state is .poweredOn")
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                      advertisementData: [String : Any], rssi RSSI: NSNumber) {
       print(peripheral)
        self.invalidateTimer()
        advertisedDataArray.append(advertisementData)
        var str = ""
        if let name = advertisementData["kCBAdvDataLocalName"] {
          str = String(describing: name)
        }else {
          str = "'"
        }
        if let uuids = advertisementData["kCBAdvDataServiceUUIDs"] {
          let uuid = String(describing: uuids)
          let id = String(uuid.filter { !" \n\t\r".contains($0) })
          str = str + ",\(id)"
          
        }else {
          str = str + ","
        }
        if let _ = advertisementData["kCBAdvDataIsConnectable"] {
         str = str + ",\(true)"
        }else {
        str = str + ",\(false)"
        }
        ekSDKDelegate?.onScanCompleted(devices: str)
  }
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
      print("Connected!")
      connectionState = .connected
      self.invalidateTimer()
      var str = ""
      if let name = advertisedDataForSelectedDevice["kCBAdvDataLocalName"] {
        str = "\nName= \(String(describing: name))"
      }
      ekSDKDelegate?.onConnectionStateChanged(connectionState: .connected)
      invalidateTimer()
      ekSDKDelegate?.onSuccess(message: "\(str) - MSBN52832 Device Connected successfuly")
      eKMonitorPeripheral.discoverServices([eKMonitorServiceCBUUID])
  }
  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
      print(error as Any)
      connectionState = .faild
      ekSDKDelegate?.onConnectionStateChanged(connectionState: .faild)
      invalidateTimer()
  }
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
      print(error as Any)
      connectionState = .disconnected
      ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
      invalidateTimer()
  }
}
// MARK: -- CBPeripheralDelegate
extension KermitSDKManager: CBPeripheralDelegate {
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      guard let services = peripheral.services else { return }
       NotificationCenter.default.post(name: Notification.Name("discoverServices"), object: nil, userInfo: nil)
      for service in services {
        print(service)
        ekSDKDelegate?.onSuccess(message: "\nServices:\n isPrimary= \(service.isPrimary)\n UUID: \(service.uuid)")
        peripheral.discoverCharacteristics(nil, for: service)
      }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      for aCharacteristic : CBCharacteristic in service.characteristics! {
        if aCharacteristic.uuid.isEqual(eKMonitorTXCharacteristicCBUUID) {
          print("TX Characteristic found")
          ekuartTXCharacteristic = aCharacteristic
        } else if aCharacteristic.uuid.isEqual(eKMonitorRXCharacteristicCBUUID) {
          print("RX Characteristic found")
          ekuartRXCharacteristic = aCharacteristic
        }
      }
      eKMonitorPeripheral = peripheral
      //Enable notifications on TX Characteristic
      if (ekuartTXCharacteristic != nil && ekuartRXCharacteristic != nil) {
        let message = "\nEnabling notifications for \(ekuartTXCharacteristic!.uuid.uuidString) peripheral.setNotifyValue(true, for: \(ekuartTXCharacteristic!.uuid.uuidString))"
        ekSDKDelegate?.onSuccess(message: message)
        peripheral.setNotifyValue(true, for: ekuartTXCharacteristic!)
      } else {
        ekSDKDelegate?.onFailed(error: "UART service does not have required characteristics. Try to turn Bluetooth Off and On again to clear cache.")
      }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    
      // TODO: Refactor the error handling code further here.
      invalidateTimer()
      switch characteristic.uuid {
        case eKMonitorTXCharacteristicCBUUID :
          let deviceResponseString = deviceData(from: characteristic)
          parseResponse(response: deviceResponseString)
        
        default:
          print("Unhandeleted UUID characteristics \(characteristic.uuid)")
        }
    
      if let errorReason = error {
        print("Error debugDescription \(errorReason)")
        ekSDKDelegate?.onFailed(error: errorReason.localizedDescription)
      }
    
  }
  func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
      print("Peripheral services changed...")
      // reconnect
      centralManager = CBCentralManager(delegate: self, queue: nil)
  }
}
//CBPeriheralManagerDelegate
extension KermitSDKManager: CBPeripheralManagerDelegate {
  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
      print("service \(service)")
      startAdvertising()
  }
  
  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    
      switch peripheral.state {
      case .poweredOn:
        print("peripheralStateChange: Powered On")
        // As soon as the peripheral/bluetooth is turned on, start initializing
        // the service.
        enableService()
        break
      case .poweredOff:
        print("peripheralStateChange: Powered Off")
        // As soon as the peripheral/bluetooth is turned on, start initializing
        // the service.
        disableService()
        break
      case .resetting:
        print("peripheralStateChange: Resetting")
        break
      case .unauthorized:
        print("peripheralStateChange: unauthorized")
        disableService()
        break
      case .unsupported:
        print("peripheralStateChange: unsupported")
        break
        
      case .unknown:
        print("peripheralStateChange: unknown")
        break
        
      default:
        print("default")
      }
    
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic){
      print("CBPeripheralManager : didSubscribe: uuid \(characteristic.uuid)")
      print("CBPeripheralManager : didSubscribe: - Identifier: \(central.identifier)")
      self.invalidateTimer()
      if connectionState == .connecting {
        ekSDKDelegate?.onConnectionStateChanged(connectionState:.connected)
        invalidateTimer()
      }
  }
  
  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
      ekSDKDelegate?.onConnectionStateChanged(connectionState: .disconnected)
  }
  
  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    
      if (error != nil) {
        print(error!.localizedDescription)
        return
      }
      print("didStartAdvertising");
    
  }
  
  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
      print("peripheralManagerIsReadyToUpdateSubscribers")
      
      if (pendingData != nil) {
        let data = pendingData.copy()
        pendingData = nil
        sendToSubscribers(data: data as? Data)
      }
  }
}
