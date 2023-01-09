//
//  Atu.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
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
  @Published public var status: Status = .none
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
  // MARK: - Initialization

  public init() {}
  
  @Dependency(\.apiModel) var apiModel
  
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
      case .status:           status = Status(rawValue: property.value) ?? .none
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
  
  public func setAndSend(_ property: Property, _ value: String = "") {
    var newValue = value
    
    // alphabetical order
    switch property {
      
    case .enabled:             newValue = value
    case .memoriesEnabled:     newValue = value
    default:                   return
    }
    parse([(property.rawValue, newValue)])
    send(property, newValue)
  }

  public func send(_ property: Property, _ value: String) {
      // Known tokens, in alphabetical order
      switch property {
        
      case .enabled:              atuCmd(value == "1" ? "start" : "bypass")
      case .memoriesEnabled:      atuSetCmd(.memoriesEnabled, "=", value)
      default:                    return
      }
  }

  
  
  
  
  
  
  
  
  
  private func atuCmd(_ command: String) {
    apiModel.send("atu " + command)
  }
  private func atuSetCmd(_ token: Property, _ separator: String, _ value: Any) {
    apiModel.send("atu set " + token.rawValue + separator + "\(value)")
  }
  
  
//  public  func clear() {
//    apiModel.send("atu clear")
//  }
//  public static func start(_ radio: Radio) {
//    apiModel.send("atu start")
//  }
//  public static func bypass(_ radio: Radio) {
//    apiModel.send("atu bypass")
//  }
  
  /*
   "atu set memories_enabled=" + Convert.ToByte(_atuMemoriesEnabled)
   "atu start"
   "atu bypass"
   "atu clear"
   */
}
