//
//  Panadapter.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 5/31/15.
//  Copyright (c) 2015 Douglas Adams, K3TZR
//

import Foundation

import FlexErrors
import Shared

// Panadapter implementation
//       creates a Panadapter instance to be used by a Client to support the
//       processing of a Panadapter. Panadapter structs are added / removed by the
//       incoming TCP messages. Panadapter objects periodically receive Panadapter
//       data in a UDP stream. They are collected in the PanadaptersCollection.

@MainActor
public final class Panadapter: Identifiable, ObservableObject {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: PanadapterId) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public var isStreaming = false
  
  @Published public var antList = [String]()
  @Published public var clientHandle: Handle = 0
  @Published public var dbmValues = [LegendValue]()
  @Published public var fillLevel: Int = 0
  @Published public var freqValues = [LegendValue]()
  @Published public var maxBw: Hz = 0
  @Published public var minBw: Hz = 0
  @Published public var preamp = ""
  @Published public var rfGainHigh = 0
  @Published public var rfGainLow = 0
  @Published public var rfGainStep = 0
  @Published public var rfGainValues = ""
  @Published public var waterfallId: UInt32 = 0
  @Published public var wide = false
  @Published public var wnbUpdating = false
  @Published public var xvtrLabel = ""
  
  @Published public var average: Int = 0
  @Published public var band: String = ""
  // FIXME: Where does autoCenter come from?
  @Published public var bandwidth: Hz = 0
  @Published public var bandZoomEnabled: Bool  = false
  @Published public var center: Hz = 0
  @Published public var daxIqChannel: Int = 0
  @Published public var fps: Int = 0
  @Published public var loggerDisplayEnabled: Bool = false
  @Published public var loggerDisplayIpAddress: String = ""
  @Published public var loggerDisplayPort: Int = 0
  @Published public var loggerDisplayRadioNumber: Int = 0
  @Published public var loopAEnabled: Bool = false
  @Published public var loopBEnabled: Bool = false
  @Published public var maxDbm: CGFloat = 0
  @Published public var minDbm: CGFloat = 0
  @Published public var rfGain: Int = 0
  @Published public var rxAnt: String = ""
  @Published public var segmentZoomEnabled: Bool = false
  @Published public var weightedAverageEnabled: Bool = false
  @Published public var wnbEnabled: Bool = false
  @Published public var wnbLevel: Int = 0
  @Published public var xPixels: CGFloat = 0
  @Published public var yPixels: CGFloat = 0
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: PanadapterId

  public let daxIqChoices = Radio.kDaxIqChannels
  public var initialized = false
  
  public enum Property: String {
    // on Panadapter
    case antList                    = "ant_list"
    case average
    case band
    case bandwidth
    case bandZoomEnabled            = "band_zoom"
    case center
    case clientHandle               = "client_handle"
    case daxIq                      = "daxiq"
    case daxIqChannel               = "daxiq_channel"
    case fps
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case maxBw                      = "max_bw"
    case maxDbm                     = "max_dbm"
    case minBw                      = "min_bw"
    case minDbm                     = "min_dbm"
    case preamp                     = "pre"
    case rfGain                     = "rfgain"
    case rxAnt                      = "rxant"
    case segmentZoomEnabled         = "segment_zoom"
    case waterfallId                = "waterfall"
    case weightedAverageEnabled     = "weighted_average"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case wnbUpdating                = "wnb_updating"
    case xPixels                    = "x_pixels"
    case xvtrLabel                  = "xvtr"
    case yPixels                    = "y_pixels"
    // ignored by Panadapter
    case available
    case capacity
    case daxIqRate                  = "daxiq_rate"
    // not sent in status messages
    case n1mmSpectrumEnable         = "n1mm_spectrum_enable"
    case n1mmAddress                = "n1mm_address"
    case n1mmPort                   = "n1mm_port"
    case n1mmRadio                  = "n1mm_radio"
  }
  
  public struct LegendValue: Identifiable {
    public var id: CGFloat         // relative position 0...1
    public var label: String       // value to display
    public var value: CGFloat      // actual value
    public var lineCount: CGFloat
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _dbmFormat = "%3.0f"
  private var _dbmStep: CGFloat = 10
  private var _freqFormat = "%2.3f"
  private var _freqStep: CGFloat = 10_000
  
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
        // parse the properties
        // YES, add it if not already present
        if ApiModel.shared.panadapters[id: id] == nil {
          ApiModel.shared.panadapters.append( Panadapter(id) )
          StreamModel.shared.panadapterStreams.append( PanadapterStream(id) )
        }
        ApiModel.shared.panadapters[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        ApiModel.shared.panadapters.remove(id: id)
        StreamModel.shared.panadapterStreams.remove(id: id)
        log("Panadapter \(id.hex): REMOVED", .debug, #function, #file, #line)
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // unknown, log it and ignore the Key
        log("Panadapter \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
      case .antList:                antList = property.value.list
      case .average:                average = property.value.iValue
      case .band:                   band = property.value
      case .bandwidth:              bandwidth = property.value.mhzToHz
      case .bandZoomEnabled:        bandZoomEnabled = property.value.bValue
      case .center:                 center = property.value.mhzToHz
      case .clientHandle:           clientHandle = property.value.handle ?? 0
      case .daxIq:                  daxIqChannel = property.value.iValue
      case .daxIqChannel:           daxIqChannel = property.value.iValue
      case .fps:                    fps = property.value.iValue
      case .loopAEnabled:           loopAEnabled = property.value.bValue
      case .loopBEnabled:           loopBEnabled = property.value.bValue
      case .maxBw:                  maxBw = property.value.mhzToHz
      case .maxDbm:                 maxDbm = property.value.cgValue
      case .minBw:                  minBw = property.value.mhzToHz
      case .minDbm:                 minDbm = property.value.cgValue
      case .preamp:                 preamp = property.value
      case .rfGain:                 rfGain = property.value.iValue
      case .rxAnt:                  rxAnt = property.value
      case .segmentZoomEnabled:     segmentZoomEnabled = property.value.bValue
      case .waterfallId:            waterfallId = property.value.streamId ?? 0
      case .wide:                   wide = property.value.bValue
      case .weightedAverageEnabled: weightedAverageEnabled = property.value.bValue
      case .wnbEnabled:             wnbEnabled = property.value.bValue
      case .wnbLevel:               wnbLevel = property.value.iValue
      case .wnbUpdating:            wnbUpdating = property.value.bValue
      case .xvtrLabel:              xvtrLabel = property.value
        
      case .available, .capacity, .daxIqRate, .xPixels, .yPixels:     break // ignored by Panadapter
      case .n1mmSpectrumEnable, .n1mmAddress, .n1mmPort, .n1mmRadio:  break // not sent in status messages
      }
    }
    // is it initialized?∫
    if initialized == false && center != 0 && bandwidth != 0 && (minDbm != 0.0 || maxDbm != 0.0) {
      // NO, it is now
      initialized = true
      log("Panadapter \(id.hex): ADDED, center = \(center.hzToMhz), bandwidth = \(bandwidth.hzToMhz)", .debug, #function, #file, #line)
    }
  }
  
  public func setIsStreaming(_ value: Bool = true) {
    Task { await MainActor.run { isStreaming = value }}
  }
  
  public static func setPanadapterProperty(radio: Radio, id: PanadapterId, property: Property, value: Any) {
    switch property {
    case .antList:                sendCommand( radio, id, .antList, value)
    case .average:                sendCommand( radio, id, .average, value)
    case .band:                   sendCommand( radio, id, .band, value)
    case .bandwidth:              sendCommand( radio, id, .bandwidth, (value as! Hz).hzToMhz)
    case .bandZoomEnabled:        sendCommand( radio, id, .bandZoomEnabled, (value as! Bool).as1or0)
    case .center:                 sendCommand( radio, id, .center, (value as! Hz).hzToMhz)
    case .clientHandle:           sendCommand( radio, id, .clientHandle, value)
    case .daxIq:                  sendCommand( radio, id, .daxIqChannel, value)
    case .daxIqChannel:           sendCommand( radio, id, .daxIqChannel, value)
    case .fps:                    sendCommand( radio, id, .fps, value)
    case .loopAEnabled:           sendCommand( radio, id, .loopAEnabled, (value as! Bool).as1or0)
    case .loopBEnabled:           sendCommand( radio, id, .loopBEnabled, (value as! Bool).as1or0)
    case .maxBw:                  sendCommand( radio, id, .maxBw, (value as! Hz).hzToMhz)
    case .maxDbm:                 sendCommand( radio, id, .maxDbm, value)
    case .minBw:                  sendCommand( radio, id, .minBw, (value as! Hz).hzToMhz)
    case .minDbm:                 sendCommand( radio, id, .minDbm, value)
    case .preamp:                 sendCommand( radio, id, .preamp, value)
    case .rfGain:                 sendCommand( radio, id, .rfGain, value)
    case .rxAnt:                  sendCommand( radio, id, .rxAnt, value)
    case .segmentZoomEnabled:     sendCommand( radio, id, .segmentZoomEnabled, (value as! Bool).as1or0)
    case .waterfallId:            sendCommand( radio, id, .waterfallId, value)
    case .wide:                   sendCommand( radio, id, .wide, (value as! Bool).as1or0)
    case .weightedAverageEnabled: sendCommand( radio, id, .weightedAverageEnabled, (value as! Bool).as1or0)
    case .wnbEnabled:             sendCommand( radio, id, .wnbEnabled, (value as! Bool).as1or0)
    case .wnbLevel:               sendCommand( radio, id, .wnbLevel, value)
    case .wnbUpdating:            sendCommand( radio, id, .wnbUpdating, (value as! Bool).as1or0)
    case .xPixels:                sendCommand( radio, id, "xpixels", value)
    case .xvtrLabel:              sendCommand( radio, id, .xvtrLabel, value)
    case .yPixels:                sendCommand( radio, id, "ypixels", value)
      
    case .available, .capacity, .daxIqRate:                         break // ignored by Panadapter
    case .n1mmSpectrumEnable, .n1mmAddress, .n1mmPort, .n1mmRadio:  break // not sent in status messages
    }
    
    //    Task {
    //      switch property {
    //      case .band:
    //        await Model.shared.panadapters[id: id]?.parseProperties( [(key: property.rawValue, value: "\((value as! Bool).as1or0)")] )
    
    //      default:
    //        await Model.shared.panadapters[id: id]?.parseProperties( [(key: property.rawValue, value: "\(value)")] )
    //      }
    //    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Process the Reply to an Rf Gain Info command, reply format: <value>,<value>,...<value>
  /// - Parameters:
  ///   - seqNum:         the Sequence Number of the original command
  ///   - responseValue:  the response value
  ///   - reply:          the reply
  public func rfGainReplyHandler(_ command: String, sequenceNumber: SequenceNumber, responseValue: String, reply: String) {
    // Anything other than 0 is an error
    guard responseValue == Shared.kNoError else {
      // log it and ignore the Reply
      log("Panadapter, non-zero reply: \(command), \(responseValue), \(flexErrorString(errorCode: responseValue))", .warning, #function, #file, #line)
      return
    }
    // parse out the values
    let rfGainInfo = reply.valuesArray( delimiter: "," )
    rfGainLow = rfGainInfo[0].iValue
    rfGainHigh = rfGainInfo[1].iValue
    rfGainStep = rfGainInfo[2].iValue
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private Static methods
  
  /// Send a command to Set a Panadapter property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Waterfall
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: PanadapterId, _ token: Property, _ value: Any) {
//    radio.send("display panafall set " + "\(id.hex) " + token.rawValue + "=\(value)")
  }
  
  /// Send a command to Set a Panadapter property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Waterfall
  ///   - token:      a String used as the token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: PanadapterId, _ token: String, _ value: Any) {
    // NOTE: commands use this format when the Token received does not match the Token sent
    //      e.g. see EqualizerCommands.swift where "63hz" is received vs "63Hz" must be sent
//    radio.send("display panafall set " + "\(id.hex) " + token + "=\(value)")
  }
  
  /*
   "display pan set 0x" + _streamID.ToString("X") + " wnb=" + Convert.ToByte(value)
   "display pan set 0x" + _streamID.ToString("X") + " wnb_level=" + _wnb_level
   "display pan set 0x" + _streamID.ToString("X") + " rxant=" + _rxant
   "display pan set 0x" + _streamID.ToString("X") + " rfgain=" + _rfGain
   "display pan set 0x" + _streamID.ToString("X") + " daxiq_channel=" + _daxIQChannel
   "display pan set 0x" + _streamID.ToString("X") + " xpixels=" + _width
   "display pan set 0x" + _streamID.ToString("X") + " ypixels=" + _height
   "display pan set 0x" + _streamID.ToString("X") + " band=" + _band
   "display pan set 0x" + _streamID.ToString("X") + " fps=" + value
   "display pan set 0x" + _streamID.ToString("X") + " average=" + value
   "display pan set 0x" + _streamID.ToString("x") + " weighted_average=" + Convert.ToByte(_weightedAverage)
   "display pan set 0x" + _streamID.ToString("x") + " n1mm_spectrum_enable=" + Convert.ToByte(_loggerDisplayEnabled)
   "display pan set 0x" + _streamID.ToString("x") + " n1mm_address=" + _loggerDisplayIPAddress.ToString()
   "display pan set 0x" + _streamID.ToString("x") + " n1mm_port=" + _loggerDisplayPort
   "display pan set 0x" + _streamID.ToString("x") + " n1mm_radio=" + _loggerDisplayRadioNum
   "display pan set 0x" + _streamID.ToString("X") + " loopa=" + Convert.ToByte(_loopA)
   "display pan set 0x" + _streamID.ToString("X") + " loopb=" + Convert.ToByte(_loopB)
   "display pan remove 0x" + _streamID.ToString("X")

   "display panafall create x=100 y=100");
   "display panafall set 0x" + _stream_id.ToString("X") + " rxant=" + _rxant
   "display panafall set 0x" + _stream_id.ToString("X") + " rfgain=" + _rfGain
   "display panafall set 0x" + _stream_id.ToString("X") + " daxiq_channel=" + _daxIQChannel
   "display panafall set 0x" + _stream_id.ToString("X") + " xpixels=" + _width
   "display panafall set 0x" + _stream_id.ToString("X") + " ypixels=" + _height
   "display panafall set 0x" + _stream_id.ToString("X") + " fps=" + value
   "display panafall set 0x" + _stream_id.ToString("X") + " average=" + value
   "display panafall set 0x" + _stream_id.ToString("x") + " weighted_average=" + Convert.ToByte(_weightedAverage)
   "display panafall set 0x" + _stream_id.ToString("X") + " loopa=" + Convert.ToByte(_loopA)
   "display panafall set 0x" + _stream_id.ToString("X") + " loopb=" + Convert.ToByte(_loopB)
   "display panafall set 0x" + _stream_id.ToString("X") + " line_duration=" + _fallLineDurationMs.ToString()
   "display panafall set 0x" + _stream_id.ToString("X") + " black_level=" + _fallBlackLevel.ToString()
   "display panafall set 0x" + _stream_id.ToString("X") + " color_gain=" + _fallColorGain.ToString()
   "display panafall set 0x" + _stream_id.ToString("X") + " auto_black=" + Convert.ToByte(_autoBlackLevelEnable)
   "display panafall set 0x" + _stream_id.ToString("X") + " gradient_index=" + _fallGradientIndex.ToString()
   "display panafall remove 0x" + _stream_id.ToString("X")

   */
}
  
  
