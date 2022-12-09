//
//  Atu.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

import Shared

// Atu
//      creates an Atu instance to be used by a Client to support the
//      processing of the Antenna Tuning Unit (if installed). Atu structs are
//      added, removed and updated by the incoming TCP messages.
@MainActor
public final class Atu: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
    
  public internal(set) var initialized  = false

  @Published public var enabled: Bool = false
  @Published public var memoriesEnabled: Bool = false
  @Published public var status: String = ""
  @Published public var usingMemory: Bool = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public types
  
  public enum Status: String {
    case none             = "NONE"
    case tuneNotStarted   = "TUNE_NOT_STARTED"
    case tuneInProgress   = "TUNE_IN_PROGRESS"
    case tuneBypass       = "TUNE_BYPASS"           // Success Byp
    case tuneSuccessful   = "TUNE_SUCCESSFUL"       // Success
    case tuneOK           = "TUNE_OK"
    case tuneFailBypass   = "TUNE_FAIL_BYPASS"      // Byp
    case tuneFail         = "TUNE_FAIL"
    case tuneAborted      = "TUNE_ABORTED"
    case tuneManualBypass = "TUNE_MANUAL_BYPASS"    // Byp
  }
  
  public enum Property: String {
    case status
    case enabled            = "atu_enabled"
    case memoriesEnabled    = "memories_enabled"
    case usingMemory        = "using_mem"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (singleton)

  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Parse status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Atu: unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .enabled:          enabled = property.value.bValue
      case .memoriesEnabled:  memoriesEnabled = property.value.bValue
      case .status:           status = property.value
      case .usingMemory:      usingMemory = property.value.bValue
      }
    }
    // is it initialized?
    if initialized == false{
      // NO, it is now
      initialized = true
      log("Atu: initialized", .debug, #function, #file, #line)
    }
  }
  
//  public func update(_ property: (Property, String)) {
//    parse([(key: property.0.rawValue, value: property.1)])
//  }
//
//  public func update(_ properties: [(Property, String)]) async {
//    for property in properties {
//      update((property.0, property.1))
//    }
//  }
//
//  public func get(_ property: Property) async -> Any {
//    var value: Any
//
//    switch property {
//    case .enabled:          value = enabled
//    case .memoriesEnabled:  value = memoriesEnabled
//    case .status:           value = status
//    case .usingMemory:      value = usingMemory
//    }
//    return value
//  }
//
//  public func get(_ properties: [Property]) async -> [Any] {
//    var values = [Any]()
//
//    for property in properties {
//      await values.append(get(property))
//    }
//    return values
//  }

  
  
  
  
  
  
  
  
  
  /// Set a property
  /// - Parameters:
  ///   - radio:      the current radio
  ///   - property:   an Atu Token
  ///   - value:      the new value
//  public static func setProperty(radio: Radio, _ property: Property, value: Any) {
//    // FIXME: add commands
//
//    private func atuCmd(_ radio: Radio, _ token: Property, _ value: Any) {
//      radio.send("atu " + token.rawValue + "=\(value)")
//    }
//    private func atuSetCmd(_ radio: Radio, _ token: Property, _ value: Any) {
//      radio.send("atu set " + token.rawValue + "=\(value)")
//    }
//  }

//  public static func clear(_ radio: Radio, callback: ReplyHandler? = nil) {
//    radio.send("atu clear", replyTo: callback)
//  }
//  public static func start(_ radio: Radio, callback: ReplyHandler? = nil) {
//    radio.send("atu start", replyTo: callback)
//  }
//  public static func bypass(_ radio: Radio, callback: ReplyHandler? = nil) {
//    radio.send("atu bypass", replyTo: callback)
//  }
  
  /*
   "atu set memories_enabled=" + Convert.ToByte(_atuMemoriesEnabled)
   "atu start"
   "atu bypass"
   "atu clear"
   */
}
