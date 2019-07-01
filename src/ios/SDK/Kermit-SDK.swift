//
//  Kermit-SDK.swift
//  Mobile-Kermit-SDK-iOS
//
//  Created by Sascha Mundstein on 17.01.19.
//  Copyright © 2019 Pfizer, Inc. All rights reserved.
//

import Foundation

class KermitSDK {
  
  static let shared = KermitSDK()
  typealias K = KermitConstants
  
  public func getDeviceInformation() throws -> String {
    return K.STX + K.Operation.deviceInfoCommand + K.ETX
  }
  
  public func getOperationFrom(recordNumber: Int) throws -> String {
    if recordNumber < 0 {
      throw KermitError.commandValueError(passedValue: recordNumber)
    }
    return K.STX + K.Operation.dataCommand + "\(recordNumber)" + K.ETX
  }
  
  public func getAllOperations() -> String {
    return K.STX + K.Operation.dataCommand + "\(0)" + K.ETX
  }
  
  public func cancelCurrentRequest() -> String {
    return K.CAN
  }
  
  public func addInjectionData(values: String) throws -> String {
    return K.STX + K.Operation.addInjectionDataCommand + values + K.ETX
  }
  public func addInvalidInjectionData() throws -> String {
    //
    return K.STX + K.Operation.addInjectionDataCommand + K.ETX

  }
  
  public func eraseInjectionData() throws -> String {
    return K.STX + K.Operation.eraseInjectionDataCommand + K.ETX
  }
  
  struct DeviceInformation {
    let modelName: String
    let serialNumber: String
    let batt_Level: BatteryLevel.BtrLevel
    let inj_Num: Int
    let inj_Day: Int
    struct BatteryLevel {
      enum BtrLevel: String {
        case completely_discharged = "discharge"
        case low = "low"
        case okay = "ok"
        case sufficient = "sufficient"
      }
      var battery: BtrLevel
      static func getBatteryLevel(batteryLevel: Int) -> KermitSDK.DeviceInformation.BatteryLevel.BtrLevel  {
        return batteryLevel == 0 ? BtrLevel.completely_discharged : batteryLevel == 1 ? BtrLevel.low : batteryLevel == 2 ? BtrLevel.okay : BtrLevel.sufficient
      }
    }
  }
  
  struct Record {
    
    enum OperationType: String, Codable {
      case injection
      case training
    }
    
    enum VolumeUnit: String, Codable {
      case mg, mL, units,none
    }
    
    let count: Int
    let time: Date
    let type: OperationType
    let drug: String?
    let volume: Double?
    let unit: VolumeUnit?
    let resultCode: String?
    
    struct RSLTCode {
      
      enum Result: Int {
        case successful = 0
        case stoppage = 1
        case failure = 2
        case reserved = 3
      }
      
      enum FailureReason: Int {
        case insertion = 0
        case clogging = 1
        case needleRetraction = 2
        case lowBattery = 3
        case fatalError = 4
        case r1, r2, r3  // reserved bits
      }
      
      let result: Result
      let failureReason : FailureReason?
      let rfFailure: Bool
      let autoPowerOff: Bool
      let tempOutsideRange: Bool
      
      static func codeWithHexString(hex: String) -> KermitSDK.Record.RSLTCode {
        
        // & 255 cuts off the leftmost 8 bits which are reserved and can be ignored
        let value = (Int(hex, radix: 16) ?? 0) & 255
        
        let result = Result(rawValue: value & Int("11",     radix: 2)!)!
        let failureReason = result != .failure ? nil :
          FailureReason(rawValue: (value & Int("11100", radix: 2)!) >> 2)!
        let rfFailure = (value & (1 << 5)) >> 5 != 0
        let autoPowerOff = (value & (1 << 6)) >> 6 != 0
        let tempOutsideRange = (value & (1 << 7)) >> 7 != 0
        
        let code = KermitSDK.Record.RSLTCode(
          result: result, failureReason: failureReason, rfFailure: rfFailure,
          autoPowerOff: autoPowerOff, tempOutsideRange: tempOutsideRange
        )
        return code;
      }
      
      public func messages() -> [String] {
        var result = [String]()
        
        switch self.result {
        case .successful:
          result.append("Injection was successful. All injection processes are complete.")
        case .stoppage:
          result.append("Injection was stopped. After the cap was removed, the cassette was ejected before injection.")
        case .failure:
          result.append("Injection failed.")
        case .reserved:
          result.append("No valid result.")
        }
        
        if let reason = self.failureReason {
          switch reason {
          case .insertion:
            result.append("Insertion of the needle did not work.")
          case .clogging:
            result.append("There was clogging during injection.")
          case .needleRetraction:
            result.append("The retraction of the needle failed.")
          case .lowBattery:
            result.append("The battery voltage is under the specified value.")
          case .fatalError:
            result.append("A fatal device error occurred.")
          default: break
          }
        }
        else {
          result.append("No failure reason.")
        }
        
        
        result.append(self.rfFailure ?
          "Failed to write data to RF tag." :
          "Successfully wrote data to RF tag.")
        
        result.append(self.autoPowerOff ?
          "Auto power off was performed after removing the cap prior to injection." :
          "Auto power off was not performed after removing the cap prior to injection.")
        
        result.append(self.tempOutsideRange ?
          "Temperature outside the range of use was detected before injection." :
          "Temperature outside the range of use was not detected before injection.")
        
        return result
      }
    }
  }
  
  static func deviceInformationFromDevice(_ data: Data) -> DeviceInformation? {
    
    do {
      let info = try JSONDecoder().decode(DeviceInformation.self, from: data)
      return info
    }
    catch let error {
      print(error)
      return nil
    }
  }
  
  static func recordsArrayFromDevice(_ data: Data) -> [Record]? {
    
    do {
      let decoder = KermitSDK.Record.kermitRecordDecoder()
      let records = try decoder.decode([Record].self, from: data)
      return records
    }
    catch let error {
      print(error)
      return nil
    }
  }
  
  static func notificationFromDevice(_ data: Data) -> Record? {
    
    do {
      let decoder = KermitSDK.Record.kermitRecordDecoder()
      let record = try decoder.decode(Record.self, from: data)
      return record
    }
    catch let error {
      print(error)
      return nil
    }
    
    
  }
  
}

extension KermitSDK.Record: Decodable {
  
  enum CodingKeys: String, CodingKey {
    case count = "cnt"
    case time
    case type
    case drug
    case volume = "vol"
    case unit
    case resultCode = "rslt"
  }
  
  init(from decoder: Decoder) throws {
    
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let count = try container.decode(Int.self, forKey: .count)
    let time = try container.decode(Date.self, forKey: .time)
    let type: OperationType = try container.decode(OperationType.self, forKey: .type)
    let drug = try container.decode(String?.self, forKey: .drug)
    let volume = try container.decode(Double?.self, forKey: .volume)
    let unit: VolumeUnit? = try container.decode(VolumeUnit?.self, forKey: .unit)
    let resultCodeString = try container.decode(String?.self, forKey: .resultCode) ?? ""
    let resultCode = resultCodeString
    
    self.init(count: count, time: time, type: type, drug: drug, volume: volume, unit: unit, resultCode: resultCode)
  }
  
  // Convenience decoder to manage date formats
  static func kermitRecordDecoder() -> JSONDecoder {
    
    enum DateError: String, Error {
      case invalidDate
    }
    
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom({ (decoder) -> Date in
      let container = try decoder.singleValueContainer()
      let dateStr = try container.decode(String.self)
      
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
      if let date = formatter.date(from: dateStr) {
        return date
      }
      throw DateError.invalidDate
    })
    
    
    
    return decoder
  }
}

extension KermitSDK.DeviceInformation: Decodable {
  enum CodingKeys: String, CodingKey {
    case modelName = "model_name"
    case serialNumber = "serial_number"
    case battery_Level = "batt_lev"
    case inj_Num = "inj_num"
    case inj_Day = "inj_day"
  }
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let modelName = try container.decode(String.self, forKey: .modelName)
    let serialNumber = try container.decode(String.self, forKey: .serialNumber)
    let batteryLevel = BatteryLevel.getBatteryLevel(batteryLevel: try container.decode(Int.self, forKey: .battery_Level))
    let inj_Num = try container.decode(Int.self, forKey: .inj_Num)
    let inj_Day = try container.decode(Int.self, forKey: .inj_Day)
    
    self.init(modelName: modelName, serialNumber: serialNumber, batt_Level: batteryLevel, inj_Num: inj_Num, inj_Day: inj_Day)
  }
}


