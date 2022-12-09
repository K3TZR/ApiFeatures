//
//  Memory.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/20/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Foundation

import Shared

// Memory Class implementation
//       creates a Memory instance to be used by a Client to support the
//       processing of a Memory. Memory structs are added, removed and
//       updated by the incoming TCP messages. They are collected in the
//       MemoriesCollection.
@MainActor
public final class Memory: Identifiable, ObservableObject {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: MemoryId) { self.id = id }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: MemoryId
  public var initialized = false
  
  @Published public var digitalLowerOffset = 0
  @Published public var digitalUpperOffset = 0
  @Published public var filterHigh = 0
  @Published public var filterLow = 0
  @Published public var frequency: Hz = 0
  @Published public var group = ""
  @Published public var mode = ""
  @Published public var name = ""
  @Published public var offset = 0
  @Published public var offsetDirection = ""
  @Published public var owner = ""
  @Published public var rfPower = 0
  @Published public var rttyMark = 0
  @Published public var rttyShift = 0
  @Published public var squelchEnabled = false
  @Published public var squelchLevel = 0
  @Published public var step = 0
  @Published public var toneMode = ""
  @Published public var toneValue: Float = 0
  
  public enum Property: String {
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case frequency                  = "freq"
    case group
    case highlight
    case highlightColor             = "highlight_color"
    case mode
    case name
    case owner
    case repeaterOffsetDirection    = "repeater"
    case repeaterOffset             = "repeater_offset"
    case rfPower                    = "power"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxFilterHigh               = "rx_filter_high"
    case rxFilterLow                = "rx_filter_low"
    case step
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case toneMode                   = "tone_mode"
    case toneValue                  = "tone_value"
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
//        if ApiModel.shared.memories[id: id] == nil { ApiModel.shared.memories.append( Memory(id) ) }
//        // parse the properties
//        ApiModel.shared.memories[id: id]!.parse( Array(properties.dropFirst(1)) )
//        
//      } else {
//        // NO, remove it
//        ApiModel.shared.memories.remove(id: id)
//        log("Memory \(id): REMOVED", .debug, #function, #file, #line)
//      }
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Memory \(id): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known keys
      switch token {
        
      case .digitalLowerOffset:       digitalLowerOffset = property.value.iValue
      case .digitalUpperOffset:       digitalUpperOffset = property.value.iValue
      case .frequency:                frequency = property.value.mhzToHz
      case .group:                    group = property.value.replacingSpaces()
      case .highlight:                break   // ignored here
      case .highlightColor:           break   // ignored here
      case .mode:                     mode = property.value.replacingSpaces()
      case .name:                     name = property.value.replacingSpaces()
      case .owner:                    owner = property.value.replacingSpaces()
      case .repeaterOffsetDirection:  offsetDirection = property.value.replacingSpaces()
      case .repeaterOffset:           offset = property.value.iValue
      case .rfPower:                  rfPower = property.value.iValue
      case .rttyMark:                 rttyMark = property.value.iValue
      case .rttyShift:                rttyShift = property.value.iValue
      case .rxFilterHigh:             filterHigh = property.value.iValue
      case .rxFilterLow:              filterLow = property.value.iValue
      case .squelchEnabled:           squelchEnabled = property.value.bValue
      case .squelchLevel:             squelchLevel = property.value.iValue
      case .step:                     step = property.value.iValue
      case .toneMode:                 toneMode = property.value.replacingSpaces()
      case .toneValue:                toneValue = property.value.fValue
      }
      // is it initialized?
      if initialized == false {
        // NO, it is now
        initialized = true
        log("Memory \(id): ADDED", .debug, #function, #file, #line)
      }
    }
  }

  
  
  
  
  
  
  

  public func setProperty(radio: Radio, _ id: MemoryId, property: Property, value: Any) {
    // FIXME: add commands
  }

  public func getProperty( _ id: MemoryId, property: Property) -> Any? {
    switch property {
      
    case .digitalLowerOffset:       return digitalLowerOffset as Any
    case .digitalUpperOffset:       return digitalUpperOffset as Any
    case .frequency:                return frequency as Any
    case .group:                    return group as Any
    case .highlight:                return nil   // ignored here
    case .highlightColor:           return nil   // ignored here
    case .mode:                     return mode as Any
    case .name:                     return name as Any
    case .owner:                    return owner as Any
    case .repeaterOffsetDirection:  return offsetDirection as Any
    case .repeaterOffset:           return offset as Any
    case .rfPower:                  return rfPower as Any
    case .rttyMark:                 return rttyMark as Any
    case .rttyShift:                return rttyShift as Any
    case .rxFilterHigh:             return filterHigh as Any
    case .rxFilterLow:              return filterLow as Any
    case .squelchEnabled:           return squelchEnabled as Any
    case .squelchLevel:             return squelchLevel as Any
    case .step:                     return step as Any
    case .toneMode:                 return toneMode as Any
    case .toneValue:                return toneValue as Any
    }
  }
  /// Send a command to Set a Memory property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Memory
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: MemoryId, _ token: Property, _ value: Any) {

    // FIXME: add commands
    
    //    radio.send("tnf set " + "\(id) " + token.rawValue + "=\(value)")
  }
}
