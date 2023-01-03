//
//  Waterfall.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation
import ComposableArchitecture
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
  
  @Dependency(\.apiModel) var apiModel
  
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

  @Published public var selectedGradient = "Basic"

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
  
//  public enum GradientEnum: String, CaseIterable {
//    case Basic
//    case Dark
//    case Deuteranopia
//    case Grayscale
//    case Purple
//    case Tritanopia
//  }

  public static let gradients = [
    "Basic",
    "Dark",
    "Deuteranopia",
    "Grayscale",
    "Purple",
    "Tritanopia"
  ]

  
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
  
  
  
  
  
  public func parseAndSend(_ property: Property, _ value: String = "") {
    var newValue = value
    
    // alphabetical order
    switch property {
    case .autoBlackEnabled:     newValue = (!autoBlackEnabled).as1or0
    case .blackLevel:           newValue = value
    case .colorGain:            newValue = value
    case .gradientIndex:        newValue = value
    case .lineDuration:         newValue = value
      // the following are ignored here
    case .clientHandle, .panadapterId, .available, .band, .bandwidth, .bandZoomEnabled, .capacity, .center, .daxIq, .daxIqChannel,
        .daxIqRate, .loopA, .loopB, .rfGain, .rxAnt, .segmentZoomEnabled, .wide, .xPixels, .xvtr:  break
    }
    
    parse([(property.rawValue, newValue)])
    send(property, newValue)
  }
  
  public func send(_ property: Property, _ value: String) {
    // Known tokens, in alphabetical order
    switch property {
    case .autoBlackEnabled:     waterfallCmd(.autoBlackEnabled, value)
    case .blackLevel:           waterfallCmd(.blackLevel, value)
    case .colorGain:            waterfallCmd(.colorGain, value)
    case .gradientIndex:        waterfallCmd(.gradientIndex, value)
    case .lineDuration:         waterfallCmd(.lineDuration, value)
      // the following are ignored here
    case .clientHandle, .panadapterId, .available, .band, .bandwidth, .bandZoomEnabled, .capacity, .center, .daxIq, .daxIqChannel,
        .daxIqRate, .loopA, .loopB, .rfGain, .rxAnt, .segmentZoomEnabled, .wide, .xPixels, .xvtr:  break
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Send a command to Set a Waterfall property
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  private func waterfallCmd(_ token: Property, _ value: Any) {
    apiModel.send("display panafall set " + "\(id.hex) " + token.rawValue + "=\(value)")
  }
}

/*
   display panafall set 0x" + _stream_id.ToString("X") + " rxant=" + _rxant);
   display panafall set 0x" + _stream_id.ToString("X") + " rfgain=" + _rfGain);
   display panafall set 0x" + _stream_id.ToString("X") + " daxiq_channel=" + _daxIQChannel);
   display panafall set 0x" + _stream_id.ToString("X") + " fps=" + value);
   display panafall set 0x" + _stream_id.ToString("X") + " average=" + value);
   display panafall set 0x" + _stream_id.ToString("x") + " weighted_average=" + Convert.ToByte(_weightedAverage));
   display panafall set 0x" + _stream_id.ToString("X") + " loopa=" + Convert.ToByte(_loopA));
   display panafall set 0x" + _stream_id.ToString("X") + " loopb=" + Convert.ToByte(_loopB));
   display panafall set 0x" + _stream_id.ToString("X") + " line_duration=" + _fallLineDurationMs.ToString());
   display panafall set 0x" + _stream_id.ToString("X") + " black_level=" + _fallBlackLevel.ToString());
   display panafall set 0x" + _stream_id.ToString("X") + " color_gain=" + _fallColorGain.ToString());
   display panafall set 0x" + _stream_id.ToString("X") + " auto_black=" + Convert.ToByte(_autoBlackLevelEnable));
   display panafall set 0x" + _stream_id.ToString("X") + " gradient_index=" + _fallGradientIndex.ToString());
   display panafall remove 0x" + _stream_id.ToString("X"));
 */
