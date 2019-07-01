//
//  KermitConstants.swift
//  Mobile-Kermit-SDK-iOS
//
//  Created by Ravi Deshmukh on 28/01/19.
//  Copyright © 2019 Pfizer Inc. All rights reserved.
//

import UIKit
import Foundation
func DLog(_ message: String, file: String = #function, function: String = #file, line: Int = #line,
          column: Int = #column) {
  #if DEBUG
  print("\(file) : \(function) : \(line) : \(column) - \(message)")
  #endif
}

class KermitConstants: NSObject {
  
  // packet data constants
  static let STX = "\u{2}"
  static let ETX = "\u{3}"
  static let EOT = "\u{2}\u{4}\u{3}"
  static let ACK = "\u{2}\u{6}\u{3}"
  static let NACK = "\u{2}\u{7}\u{3}"
  static let NAK = "\u{2}\u{15}\u{3}"
  static let CAN = "\u{2}\u{18}\u{3}"
  static let noDataAvailable = "\u{2}[]\u{3}"

  //packet data constants for ec1
  static let BCC = "\u{0}"
  //TODO: replace with actual type and ID
  static let IDS = "\u{24}"
  static let TYPE = "\u{2}"
  //CB services parameters
  static let serviceName = "Enbrel Data Monitor"
  static let uartServiceUUIDString                 = "8B580001-8E35-11E8-9EB6-529269FB1459"
  static let uartRXCharacteristicUUIDString        = "8B580002-8E35-11E8-9EB6-529269FB1459"
  static let uartTXCharacteristicUUIDString        = "8B580003-8E35-11E8-9EB6-529269FB1459"
   //TODO: remove when no need  of simulator injector app
  static let uartServiceUUIDSimulatorString                 = "8B580001-8E35-11E8-9EB6-529269FB1459"
  static let uartRXCharacteristicUUIDSimulatorString        = "8B580001-8E35-11E8-9EB6-529269FB1459"
  static let uartTXCharacteristicUUIDSimulatorString        = "8B580001-8E35-11E8-9EB6-529269FB1459"
  // operation Constant
  struct Operation {
    static let deviceInfoCommand = "get_device_information"
    static let deviceInfoForNACKCommand = "get_info"
    static let dataCommand = "get_operation_from,"
    static let addInjectionDataCommand = "set_operation,"
    static let eraseInjectionDataCommand = "clr_operation"
  }
  struct ConnectionStatus {
    static let deviceConnectionInProgress = "deviceConnectionInProgress"
    
  }
}
