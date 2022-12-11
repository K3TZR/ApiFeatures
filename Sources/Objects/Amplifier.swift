//
//  Amplifier.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/7/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import SwiftUI

import ComposableArchitecture
import Shared

// Amplifier
//       creates an Amplifier instance to be used by a Client to support the
//       control of an external Amplifier. Amplifier instances are added, removed and
//       updated by the incoming TCP messages. They are collected in the
//       Model.amplifiers collection.
@MainActor
public final class Amplifier: Identifiable, ObservableObject {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: AmplifierId) { self.id = id }

  @Dependency(\.apiModel) var apiModel

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: AmplifierId
  public var initialized = false

  @Published public var ant: String = ""
  @Published public var antennaDict = [String:String]()
  @Published public var handle: Handle = 0
  @Published public var ip: String = ""
  @Published public var model: String = ""
  @Published public var port: Int = 0
  @Published public var serialNumber: String = ""
  @Published public var state: String = ""
  
  public enum Property: String {
    case ant
    case handle
    case ip
    case model
    case port
    case serialNumber  = "serial_num"
    case state
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse Tnf key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Amplifier \(id.hex): unknown propety, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known keys
      switch token {
        
      case .ant:          ant = property.value ; antennaDict = parseAntennaSettings( property.value)
      case .handle:       handle = property.value.handle ?? 0
      case .ip:           ip = property.value
      case .model:        model = property.value
      case .port:         port = property.value.iValue
      case .serialNumber: serialNumber = property.value
      case .state:        state = property.value
      }
      // is it initialized?
      if initialized == false {
        // NO, it is now
        initialized = true
        log("Amplifier \(id.hex): ADDED, model = \(model)", .debug, #function, #file, #line)
      }
    }
  }
  
  @MainActor public func update(_ property: (Property, String)) {
    parse([(key: property.0.rawValue, value: property.1)])
  }
  
  @MainActor public func update(_ properties: [(Property, String)]) {
    for property in properties {
      update((property.0, property.1))
    }
  }
  
  public func get(_ property: Property) async -> Any {
    var value: Any
    
    switch property {
    case .ant:          value = ant
    case .handle:       value = handle
    case .ip:           value = ip
    case .model:        value = model
    case .port:         value = port
    case .serialNumber: value = serialNumber
    case .state:        value = state
    }
    return value
  }
  
  public func get(_ properties: [Property]) async -> [Any] {
    var values = [Any]()
    
    for property in properties {
      await values.append(get(property))
    }
    return values
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Parse a list of antenna pairs
  /// - Parameter settings:     the list
  private func parseAntennaSettings(_ settings: String) -> [String:String] {
    var antDict = [String:String]()
    
    // pairs are comma delimited
    let pairs = settings.split(separator: ",")
    // each setting is <ant:ant>
    for setting in pairs {
      if !setting.contains(":") { continue }
      let parts = setting.split(separator: ":")
      if parts.count != 2 {continue }
      antDict[String(parts[0])] = String(parts[1])
    }
    return antDict
  }

  
  
  
  
  
  
  /// Send a command to Set an Amplifier property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Amplifier
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: AmplifierId, _ token: Property, _ value: Any) {
    // FIXME: add commands
  }
  
  /*
   amplifier set " + _handle + " operate=" + Convert.ToByte(_isOperate)
   */
}

