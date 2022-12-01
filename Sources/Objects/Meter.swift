//
//  Meter.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 6/2/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

import Shared


// Meter
//      A Meter instance to be used by a Client to support the
//      rendering of a Meter. They are collected in the
//      Model.meters collection.
@MainActor
public final class Meter: Identifiable, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: MeterId) { self.id = id }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: MeterId
  public var initialized: Bool = false
  
  @Published public var desc: String = ""
  @Published public var fps: Int = 0
  @Published public var high: Float = 0
  @Published public var low: Float = 0
  @Published public var group: String = ""
  @Published public var name: String = ""
  @Published public var peak: Float = 0
  @Published public var source: String = ""
  @Published public var units: String = ""
  @Published public var value: Float = 0
  
  public static var streamId: UInt32?
  public static var isStreaming = false
  
  public enum Source: String {
    case codec      = "cod"
    case tx
    case slice      = "slc"
    case radio      = "rad"
    case amplifier  = "amp"
  }
  public enum ShortName: String, CaseIterable {
    case codecOutput            = "codec"
    case microphoneAverage      = "mic"
    case microphoneOutput       = "sc_mic"
    case microphonePeak         = "micpeak"
    case postClipper            = "comppeak"
    case postFilter1            = "sc_filt_1"
    case postFilter2            = "sc_filt_2"
    case postGain               = "gain"
    case postRamp               = "aframp"
    case postSoftwareAlc        = "alc"
    case powerForward           = "fwdpwr"
    case powerReflected         = "refpwr"
    case preRamp                = "b4ramp"
    case preWaveAgc             = "pre_wave_agc"
    case preWaveShim            = "pre_wave"
    case signal24Khz            = "24khz"
    case signalPassband         = "level"
    case signalPostNrAnf        = "nr/anf"
    case signalPostAgc          = "agc+"
    case swr                    = "swr"
    case temperaturePa          = "patemp"
    case voltageAfterFuse       = "+13.8b"
    case voltageBeforeFuse      = "+13.8a"
    case voltageHwAlc           = "hwalc"
  }
  
  public enum Property: String {
    case desc
    case fps
    case high       = "hi"
    case low
    case name       = "nam"
    case group      = "num"
    case source     = "src"
    case units      = "unit"
  }
  
  public enum Units: String {
    case none
    case amps
    case db
    case dbfs
    case dbm
    case degc
    case degf
    case percent
    case rpm
    case swr
    case volts
    case watts
  }
 
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
  public static func status(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = UInt32(properties[0].key.components(separatedBy: ".")[0], radix: 10) {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if ApiModel.shared.meters[id: id] == nil { ApiModel.shared.meters.append( Meter(id) ) }
        // parse the properties
        ApiModel.shared.meters[id: id]!.parse( properties )
        
      } else {
        // NO, remove it
        ApiModel.shared.meters.remove(id: id)
        log("Meter \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse Meter key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <n.key=value>
    for property in properties {
      // separate the Meter Number from the Key
      let numberAndKey = property.key.components(separatedBy: ".")
      
      // get the Key
      let key = numberAndKey[1]
      
      // check for unknown Keys
      guard let token = Property(rawValue: key) else {
        // unknown, log it and ignore the Key
        log("Meter \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
      case .desc:     desc = property.value
      case .fps:      fps = property.value.iValue
      case .high:     high = property.value.fValue
      case .low:      low = property.value.fValue
      case .name:     name = property.value.lowercased()
      case .group:    group = property.value
      case .source:   source = property.value.lowercased()
      case .units:    units = property.value.lowercased()
      }
    }
    // is it initialized?
    if initialized == false && group != "" && units != "" {
      //NO, it is now
      initialized = true
      log("Meter \(id): ADDED, name = \(name), source = \(source), group = \(group)", .debug, #function, #file, #line)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods
  
  /// Process the Vita struct containing Meter data
  /// - Parameters:
  ///   - vita:        a Vita struct
  public static func vitaProcessor(_ vita: Vita) async {
    let kDbDbmDbfsSwrDenom: Float = 128.0   // denominator for Db, Dbm, Dbfs, Swr
    let kDegDenom: Float = 64.0             // denominator for Degc, Degf
    
    var meterIds = [UInt32]()

//    if isStreaming == false {
//      isStreaming = true
//      streamId = vita.streamId
//      // log the start of the stream
//      log("Meter \(vita.streamId.hex) stream: STARTED", .info, #function, #file, #line)
//    }
    
    // NOTE:  there is a bug in the Radio (as of v2.2.8) that sends
    //        multiple copies of meters, this code ignores the duplicates
    
    vita.payloadData.withUnsafeBytes { payloadPtr in
      // four bytes per Meter
      let numberOfMeters = Int(vita.payloadSize / 4)
      
      // pointer to the first Meter number / Meter value pair
      let ptr16 = payloadPtr.bindMemory(to: UInt16.self)
      
      // for each meter in the Meters packet
      for i in 0..<numberOfMeters {
        // get the Meter id and the Meter value
        let id: UInt32 = UInt32(CFSwapInt16BigToHost(ptr16[2 * i]))
        let value: UInt16 = CFSwapInt16BigToHost(ptr16[(2 * i) + 1])
        
        // is this a duplicate?
        if !meterIds.contains(id) {
          // NO, add it to the list
          meterIds.append(id)
          
          // find the meter (if present) & update it
          if let meter = ApiModel.shared.meters[id: id] {
            //          meter.streamHandler( value)
            let newValue = Int16(bitPattern: value)
            let previousValue = meter.value
            
            // check for unknown Units
            guard let token = Units(rawValue: meter.units) else {
              //      // log it and ignore it
              //      log("Meter \(desc) \(description) \(group) \(name) \(source): unknown units - \(units))", .warning, #function, #file, #line)
              return
            }
            var adjNewValue: Float = 0.0
            switch token {
              
            case .db, .dbm, .dbfs, .swr:        adjNewValue = Float(exactly: newValue)! / kDbDbmDbfsSwrDenom
            case .volts, .amps:                 adjNewValue = Float(exactly: newValue)! / 256.0
            case .degc, .degf:                  adjNewValue = Float(exactly: newValue)! / kDegDenom
            case .rpm, .watts, .percent, .none: adjNewValue = Float(exactly: newValue)!
            }
            // did it change?
            if adjNewValue != previousValue {
              let value = adjNewValue
              Task { await MainActor.run { ApiModel.shared.meters[id: id]?.value = value }}
            }
          }
        }
      }
    }
  }
}
