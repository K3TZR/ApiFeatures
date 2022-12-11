//
//  Xvtr.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 6/24/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

import Shared

// Xvtr
//      creates an Xvtr instance to be used by a Client to support the
//      processing of an Xvtr. Xvtr structs are added, removed and updated by
//      the incoming TCP messages. They are collected in the Model.xvtrs
//      collection.
@MainActor
public final class Xvtr: Identifiable, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: XvtrId) { self.id = id }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: XvtrId
  public var initialized = false
  
  @Published public var isValid = false
  @Published public var preferred = false
  @Published public var twoMeterInt = 0
  @Published public var ifFrequency: Hz = 0
  @Published public var loError = 0
  @Published public var name = ""
  @Published public var maxPower = 0
  @Published public var order = 0
  @Published public var rfFrequency: Hz = 0
  @Published public var rxGain = 0
  @Published public var rxOnly = false
  
  public enum Property: String {
    case name
    case ifFrequency    = "if_freq"
    case isValid        = "is_valid"
    case loError        = "lo_error"
    case maxPower       = "max_power"
    case order
    case preferred
    case rfFrequency    = "rf_freq"
    case rxGain         = "rx_gain"
    case rxOnly         = "rx_only"
    case twoMeterInt    = "two_meter_int"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse Xvtr key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Xvtr \(id): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .name:         name = String(property.value.prefix(4))
      case .ifFrequency:  ifFrequency = property.value.mhzToHz
      case .isValid:      isValid = property.value.bValue
      case .loError:      loError = property.value.iValue
      case .maxPower:     maxPower = property.value.iValue
      case .order:        order = property.value.iValue
      case .preferred:    preferred = property.value.bValue
      case .rfFrequency:  rfFrequency = property.value.mhzToHz
      case .rxGain:       rxGain = property.value.iValue
      case .rxOnly:       rxOnly = property.value.bValue
      case .twoMeterInt:  twoMeterInt = property.value.iValue
      }
    }
    // is it initialized?
    if initialized == false {
      // NO, it is now
      initialized = true
      log("Xvtr \(id): ADDED, name = \(name)", .debug, #function, #file, #line)
    }
  }
  
  
  
 
  
  
  
  
  
  
  /// Send a command to Set an Xvtr property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Xvtr
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: XvtrId, _ token: Property, _ value: Any) {
    radio.send("xvtr set " + "\(id) " + token.rawValue + "=\(value)")
  }
  
  /*
   Radio.cs
     4483,13:             SendCommand("xvtr create");

   Xvtr.cs
     "xvtr remove " + _index
     "xvtr set " + _index + " order=" + _order
     "xvtr set " + _index + " name=" + _name
     "xvtr set " + _index + " rf_freq=" + StringHelper.DoubleToString(_rfFreq, "f6")
     "xvtr set " + _index + " if_freq=" + StringHelper.DoubleToString(_ifFreq, "f6")
     "xvtr set " + _index + " lo_error=" + StringHelper.DoubleToString(_loError, "f6")
     "xvtr set " + _index + " rx_gain=" + StringHelper.DoubleToString(_rxGain, "f2")
     "xvtr set " + _index + " rx_only=" + Convert.ToByte(_rxOnly)
     "xvtr set " + _index + " max_power=" + StringHelper.DoubleToString(_maxPower, "f2")
   */
}
