//
//  Equalizer.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import ComposableArchitecture
import Foundation

import Shared

public enum EqType: String {
  case rx = "rxsc"
  case tx = "txsc"
}

// Equalizer
//      Added, removed and updated by the incoming TCP messages.
//      Collected in the ApiModel.equalizers collection.
//
@MainActor
public final class Equalizer: Identifiable, ObservableObject {
//  public static func == (lhs: Equalizer, rhs: Equalizer) -> Bool {
//    guard lhs.eqEnabled == rhs.eqEnabled else { return false }
//    guard lhs.hz63 == rhs.hz63 else { return false }
//    guard lhs.hz125 == rhs.hz125 else { return false }
//    guard lhs.hz250 == rhs.hz250 else { return false }
//    guard lhs.hz500 == rhs.hz500 else { return false }
//    guard lhs.hz1000 == rhs.hz1000 else { return false }
//    guard lhs.hz2000 == rhs.hz2000 else { return false }
//    guard lhs.hz4000 == rhs.hz4000 else { return false }
//    guard lhs.hz8000 == rhs.hz8000 else { return false }
//    return true
//  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: EqualizerId) { self.id = id }
  
  @Dependency(\.apiModel) var apiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: EqualizerId
  public var initialized = false
  
  @Published public var eqEnabled = false
  @Published public var hz63: Int = 0
  @Published public var hz125: Int = 0
  @Published public var hz250: Int = 0
  @Published public var hz500: Int = 0
  @Published public var hz1000: Int = 0
  @Published public var hz2000: Int = 0
  @Published public var hz4000: Int = 0
  @Published public var hz8000: Int = 0
  
  public enum Property: String {
    //   NOTE: the Radio sends these tokens to the API
    case hz63    = "63hz"
    case hz125   = "125hz"
    case hz250   = "250hz"
    case hz500   = "500hz"
    case hz1000  = "1000hz"
    case hz2000  = "2000hz"
    case hz4000  = "4000hz"
    case hz8000  = "8000hz"

    //   NOTE: the Radio requires these tokens from the API
    case Hz63    = "63Hz"
    case Hz125   = "125Hz"
    case Hz250   = "250Hz"
    case Hz500   = "500Hz"
    case Hz1000  = "1000Hz"
    case Hz2000  = "2000Hz"
    case Hz4000  = "4000Hz"
    case Hz8000  = "8000Hz"

    //   NOTE: this token is the same in both directions
    case eqEnabled = "mode"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Set a property on an Equalizer
  /// - Parameters:
  ///   - property: property to set (Must use the 63Hz format tokens)
  ///   - value: a new value
  public func setEqProperty(_ token: Property, _ value: Any = 0) {
    
    // this guarantees that the "Hz63" form is used in commands to the Radio
    switch token {
      
    case .eqEnabled:        eqEnabled.toggle() ; equalizerCmd(.eqEnabled, "=", eqEnabled)
    case .hz63, .Hz63:      hz63 = value as! Int ; equalizerCmd(.Hz63, "=", value)
    case .hz125, .Hz125:    hz125 = value as! Int ; equalizerCmd(.Hz125, "=", value)
    case .hz250, .Hz250:    hz250 = value as! Int ; equalizerCmd(.Hz250, "=", value)
    case .hz500, .Hz500:    hz500 = value as! Int ; equalizerCmd(.Hz500, "=", value)
    case .hz1000, .Hz1000:  hz1000 = value as! Int ; equalizerCmd(.Hz1000, "=", value)
    case .hz2000, .Hz2000:  hz2000 = value as! Int ; equalizerCmd(.Hz2000, "=", value)
    case .hz4000, .Hz4000:  hz4000 = value as! Int ; equalizerCmd(.Hz4000, "=", value)
    case .hz8000, .Hz8000:  hz8000 = value as! Int ; equalizerCmd(.Hz8000, "=", value)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Send a command to Set a property on this Equalizer
  /// - Parameters:
  ///   - token:      the parse token
  ///   - separator:  String used between token and value
  ///   - value:      the new value
  private func equalizerCmd(_ token: Property, _ separator: String, _ value: Any) {
    if let isBool = value as? Bool {
      apiModel.send("eq " + id + " " + token.rawValue + separator + "\(isBool.as1or0)")
    } else {
      apiModel.send("eq " + id + " " + token.rawValue + separator + "\(value)")
    }
  }
  
  /*
   ✔️ eq " + id + "mode="   + 1/0
   eq " + id + "32Hz="   + hz32    // ???
   ✔️ eq " + id + "63Hz="   + hz63
   ✔️ eq " + id + "125Hz="  + hz125
   ✔️ eq " + id + "250Hz="  + hz250
   ✔️ eq " + id + "500Hz="  + hz500
   ✔️ eq " + id + "1000Hz=" + hz1000
   ✔️ eq " + id + "2000Hz=" + hz2000
   ✔️ eq " + id + "4000Hz=" + hz4000
   ✔️ eq " + id + "8000Hz=" + hz8000
   eq " + id + "info"
   eq apf gain=" + apfGain
   eq apf mode=" + apfMode
   eq apf qfactor=" + apfQFactor
   */

  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
//  static func status(_ properties: KeyValuesArray, _ inUse: Bool) {
//    // get the id
//    let id = properties[0].key
//    if id == "tx" || id == "rx" { return } // legacy equalizer ids, ignore
//    // is it in use?
//    if inUse {
//      // YES, add it if not already present
//      if ApiModel.shared.equalizers[id: id] == nil { ApiModel.shared.equalizers.append( Equalizer(id) ) }
//      // parse the properties
//      ApiModel.shared.equalizers[id: id]!.parse( Array(properties.dropFirst(1)) )
//
//    } else {
//      // NO, remove it
//      ApiModel.shared.equalizers.remove(id: id)
//      log("Equalizer \(id): REMOVED", .debug, #function, #file, #line)
//    }
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Equalizer \(id): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known keys
      switch token {

      case .hz63, .Hz63:      hz63 = property.value.iValue
      case .hz125, .Hz125:    hz125 = property.value.iValue
      case .hz250, .Hz250:    hz250 = property.value.iValue
      case .hz500, .Hz500:    hz500 = property.value.iValue
      case .hz1000, .Hz1000:  hz1000 = property.value.iValue
      case .hz2000, .Hz2000:  hz2000 = property.value.iValue
      case .hz4000, .Hz4000:  hz4000 = property.value.iValue
      case .hz8000, .Hz8000:  hz8000 = property.value.iValue
        
      case .eqEnabled:        eqEnabled = property.value.bValue
      }
      // is it initialized?
      if initialized == false {
        // NO, it is now
        initialized = true
        log("Equalizer \(id): ADDED", .debug, #function, #file, #line)
      }
    }
  }
}
