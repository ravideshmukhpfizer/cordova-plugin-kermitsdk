//
//  KermitError.swift
//  Mobile-Kermit-SDK-iOS
//
//  Created by Sascha Mundstein on 06.02.19.
//  Copyright © 2019 Pfizer, Inc. All rights reserved.
//

import Foundation

enum KermitError: Error {
  
  // Connection with Bluetooth device
  case notConnected
  case notAuthorized
  case serviceNotFound
  case characteristicNotFound
  case bluetoothError // general Bluetooth related error
  
  // Commands
  case nothingReceived
  case commandNotKnown
  case commandSyntaxError
  case commandValueError(passedValue: Int)
  
  // Payloads
  case invalidJSON
  case invalidValue(forProperty: String)
  case missingProperty(property: String)
  
}
