//
//  BandSetting.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 4/6/19.
//  Copyright © 2019 Douglas Adams. All rights reserved.
//

import Foundation

import Shared

// BandSetting
//      creates a BandSetting instance to be used by a Client to support the
//      processing of the band settings. BandSetting instances are added, removed and
//      updated by the incoming TCP messages. They are collected in the
//      Model.bandSettings collection.
@MainActor
public final class BandSetting: Identifiable, ObservableObject {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: BandId) { self.id = id }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: BandId
  public var initialized: Bool = false

  @Published public var accTxEnabled: Bool = false
  @Published public var accTxReqEnabled: Bool = false
  @Published public var name = 999
  @Published public var hwAlcEnabled: Bool = false
  @Published public var inhibit: Bool = false
  @Published public var rcaTxReqEnabled: Bool = false
  @Published public var rfPower: Int = 0
  @Published public var tunePower: Int = 0
  @Published public var tx1Enabled: Bool = false
  @Published public var tx2Enabled: Bool = false
  @Published public var tx3Enabled: Bool  = false
  
  public enum Property: String {
    case accTxEnabled       = "acc_tx_enabled"
    case accTxReqEnabled    = "acc_txreq_enable"
    case name               = "band_name"
    case hwAlcEnabled       = "hwalc_enabled"
    case inhibit
    case rcaTxReqEnabled    = "rca_txreq_enable"
    case rfPower            = "rfpower"
    case tunePower          = "tunepower"
    case tx1Enabled         = "tx1_enabled"
    case tx2Enabled         = "tx2_enabled"
    case tx3Enabled         = "tx3_enabled"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
//  public static func status(_ properties: KeyValuesArray, _ inUse: Bool) {
//    // get the id
//    if let id = properties[0].key.objectId {
//      // is it in use?
//      if inUse {
//        // YES, add it if not already present
//        if ApiModel.shared.bandSettings[id: id] == nil { ApiModel.shared.bandSettings.append( BandSetting(id) ) }
//        // parse the properties
//        ApiModel.shared.bandSettings[id: id]!.parse( Array(properties.dropFirst(1)) )
//      } else {
//        // NO, remove it
//        ApiModel.shared.bandSettings.remove(id: id)
//        log("BandSetting \(id): REMOVED", .debug, #function, #file, #line)
//      }
//    }
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse BandSetting key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("BandSetting \(id): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known keys
      switch token {
        
      case .accTxEnabled:     accTxEnabled = property.value.bValue
      case .accTxReqEnabled:  accTxReqEnabled = property.value.bValue
      case .name:             name = property.value == "GEN" ? 999 : property.value.iValue
      case .hwAlcEnabled:     hwAlcEnabled = property.value.bValue
      case .inhibit:          inhibit = property.value.bValue
      case .rcaTxReqEnabled:  rcaTxReqEnabled = property.value.bValue
      case .rfPower:          rfPower = property.value.iValue
      case .tunePower:        tunePower = property.value.iValue
      case .tx1Enabled:       tx1Enabled = property.value.bValue
      case .tx2Enabled:       tx2Enabled = property.value.bValue
      case .tx3Enabled:       tx3Enabled = property.value.bValue
      }
      // is it initialized?
      if initialized == false {
        // NO, it is now
        initialized = true
        log("BandSetting \(id): ADDED, name = \(name)", .debug, #function, #file, #line)
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
    case .accTxEnabled:       value = accTxEnabled
    case .accTxReqEnabled:    value = accTxReqEnabled
    case .name:               value = name
    case .hwAlcEnabled:       value = hwAlcEnabled
    case .inhibit:            value = inhibit
    case .rcaTxReqEnabled:    value = rcaTxReqEnabled
    case .rfPower:            value = rfPower
    case .tunePower:          value = tunePower
    case .tx1Enabled:         value = tx1Enabled
    case .tx2Enabled:         value = tx2Enabled
    case .tx3Enabled:         value = tx3Enabled
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
}
