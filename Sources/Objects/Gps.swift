//
//  Gps.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

import Shared

// Gps
//      creates a Gps instance to be used by a Client to support the
//      processing of the internal Gps (if installed). Gps instances are added,
//      removed and updated by the incoming TCP messages.
//
@MainActor
public final class Gps: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public internal(set) var initialized = false

  @Published public var altitude = ""
  @Published public var frequencyError: Double = 0
  @Published public var grid = ""
  @Published public var installed = false
  @Published public var latitude = ""
  @Published public var longitude = ""
  @Published public var speed = ""
  @Published public var time = ""
  @Published public var track: Double = 0
  @Published public var tracked = false
  @Published public var visible = false
  
  public  enum Property: String {
    case altitude
    case frequencyError = "freq_error"
    case grid
    case latitude = "lat"
    case longitude = "lon"
    case speed
    case installed = "status"
    case time
    case track
    case tracked
    case visible
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods

  /// Parse a Gps status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Gps: unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
      case .altitude:       altitude = property.value
      case .frequencyError: frequencyError = property.value.dValue
      case .grid:           grid = property.value
      case .installed:      installed = property.value == "present" ? true : false
      case .latitude:       latitude = property.value
      case .longitude:      longitude = property.value
      case .speed:          speed = property.value
      case .time:           time = property.value
      case .track:          track = property.value.dValue
      case .tracked:        tracked = property.value.bValue
      case .visible:        visible = property.value.bValue
      }
    }
    // is it initialized?
    if initialized == false{
      // NO, it is now
      initialized = true
      log("Gps: initialized", .debug, #function, #file, #line)
    }
  }
  
  ///   Gps Install
  ///   - Parameters:
  ///     - callback:           ReplyHandler (optional)
//  public static func gpsInstall(radio: Radio, callback: ReplyHandler? = nil) {
//   radio.send("radio gps install", replyTo: callback)
//  }
  
  /// Gps Un-Install
  /// - Parameters:
  ///   - callback:           ReplyHandler (optional)
//  public static func gpsUnInstall(radio: Radio, callback: ReplyHandler? = nil) {
//    radio.send("radio gps uninstall", replyTo: callback)
//  }

  /// Set a property
  /// - Parameters:
  ///   - radio:      the current radio
  ///   - property:   a Gps Token
  ///   - value:      the new value
//  public static func setProperty(radio: Radio, _ property: Property, value: Any) {
//    // FIXME: add commands
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Static methods

  /// Send a command to Set a Gps property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - token:      the parse token
  ///   - value:      the new value
//  private static func sendCommand(_ radio: Radio, _ token: Property, _ value: Any) {
//    // FIXME: add commands
//  }
}
