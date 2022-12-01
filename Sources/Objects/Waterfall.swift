//
//  Waterfall.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import CoreGraphics

import Shared

// Waterfall
//       creates a Waterfall instance to be used by a Client to support the
//       processing of a Waterfall. Waterfall instances are added / removed by the
//       incoming TCP messages. Waterfall objects periodically receive Waterfall
//       data in a UDP stream. They are collected in the Model.waterfalls
//       collection..
@MainActor
public final class Waterfall: Identifiable, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: WaterfallId) {
    self.id = id    
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public var isStreaming = false
  
  @Published public var autoBlackEnabled = false
  @Published public var autoBlackLevel: UInt32 = 0
  @Published public var blackLevel = 0
  @Published public var clientHandle: Handle = 0
  @Published public var colorGain = 0
  @Published public var delegate: StreamHandler?
  @Published public var gradientIndex = 0
  @Published public var lineDuration = 0
  @Published public var panadapterId: PanadapterId?
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public enum Property: String {
    case clientHandle         = "client_handle"   // New Api only
    
    // on Waterfall
    case autoBlackEnabled     = "auto_black"
    case blackLevel           = "black_level"
    case colorGain            = "color_gain"
    case gradientIndex        = "gradient_index"
    case lineDuration         = "line_duration"
    
    // unused here
    case available
    case band
    case bandZoomEnabled      = "band_zoom"
    case bandwidth
    case capacity
    case center
    case daxIq                = "daxiq"
    case daxIqChannel         = "daxiq_channel"
    case daxIqRate            = "daxiq_rate"
    case loopA                = "loopa"
    case loopB                = "loopb"
    case panadapterId         = "panadapter"
    case rfGain               = "rfgain"
    case rxAnt                = "rxant"
    case segmentZoomEnabled   = "segment_zoom"
    case wide
    case xPixels              = "x_pixels"
    case xvtr
  }
  
  public let id: WaterfallId
  public var initialized = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods
  
  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
  public static func status(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.streamId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if ApiModel.shared.waterfalls[id: id] == nil { ApiModel.shared.waterfalls.append( Waterfall(id) ) }
        // parse the properties
        ApiModel.shared.waterfalls[id: id]!.parse( Array(properties.dropFirst(1)) )
        StreamModel.shared.waterfallStreams.append( WaterfallStream(id) )
        
      } else {
        // NO, remove it
        ApiModel.shared.waterfalls.remove(id: id)
        StreamModel.shared.waterfallStreams.remove(id: id)
        log("Waterfall \(id.hex): REMOVED", .info, #function, #file, #line)
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse Waterfal properties
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Waterfall \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .autoBlackEnabled:   autoBlackEnabled = property.value.bValue
      case .blackLevel:         blackLevel = property.value.iValue
      case .clientHandle:       clientHandle = property.value.handle ?? 0
      case .colorGain:          colorGain = property.value.iValue
      case .gradientIndex:      gradientIndex = property.value.iValue
      case .lineDuration:       lineDuration = property.value.iValue
      case .panadapterId:       panadapterId = property.value.streamId ?? 0
        // the following are ignored here
      case .available, .band, .bandwidth, .bandZoomEnabled, .capacity, .center, .daxIq, .daxIqChannel,
          .daxIqRate, .loopA, .loopB, .rfGain, .rxAnt, .segmentZoomEnabled, .wide, .xPixels, .xvtr:  break
      }
    }
    // is it initialized?
    if initialized == false && panadapterId != 0 {
      // NO, it is now
      initialized = true
      log("Waterfall \(id.hex): ADDED handle = \(clientHandle.hex)", .debug, #function, #file, #line)
    }
  }

  public func setIsStreaming() {
    Task { await MainActor.run { isStreaming = true }}
  }

  /// Send a command to Set a Waterfall property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Waterfall
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: WaterfallId, _ token: Property, _ value: Any) {
//    radio.send("display panafall set " + "\(id.hex) " + token.rawValue + "=\(value)")
  }
  
}
