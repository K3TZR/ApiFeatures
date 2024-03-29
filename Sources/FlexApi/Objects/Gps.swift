//
//  Gps.swift
//  ApiFeatures/Objects
//
//  Created by Douglas Adams on 8/15/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation

import SharedModel

@MainActor
@Observable
public final class Gps: Equatable {
  public nonisolated static func == (lhs: Gps, rhs: Gps) -> Bool {
    lhs === rhs
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public internal(set) var initialized = false
  
  public var altitude = ""
  public var frequencyError: Double = 0
  public var grid = ""
  public var installed = false
  public var latitude = ""
  public var longitude = ""
  public var speed = ""
  public var time = ""
  public var track: Double = 0
  public var tracked = false
  public var visible = false
  
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
  // MARK: - Public Parse methods
  
  /// Parse a Gps status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Gps.Property(rawValue: property.key)  else {
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

  public func setProperty(_ property: Property, _ value: String) {
    parse([(property.rawValue, value)])
    send(property, value)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Send methods

  private func send(_ property: Property, _ value: String) {
    // FIXME:
  }
}
