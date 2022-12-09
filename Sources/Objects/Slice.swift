//
//  File.swift
//  
//
//  Created by Douglas Adams on 7/11/22.
//

import ComposableArchitecture
import Foundation

import Shared

@MainActor
public final class Slice: Identifiable, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: SliceId) {
    self.id = id
    // set filterLow & filterHigh to default values
    setupDefaultFilters(mode)
  }
  
  @Dependency(\.apiModel) var apiModel

  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public var autoPan: Bool = false
  @Published public var clientHandle: Handle = 0
  @Published public var daxClients: Int = 0
  @Published public var daxTxEnabled: Bool = false
  @Published public var detached: Bool = false
  @Published public var diversityChild: Bool = false
  @Published public var diversityIndex: Int = 0
  @Published public var diversityParent: Bool = false
  @Published public var inUse: Bool = false
  @Published public var modeList = ""
  @Published public var nr2: Int = 0
  @Published public var owner: Int = 0
  @Published public var panadapterId: PanadapterId = 0
  @Published public var postDemodBypassEnabled: Bool = false
  @Published public var postDemodHigh: Int = 0
  @Published public var postDemodLow: Int = 0
  @Published public internal(set) var qskEnabled: Bool = false
  @Published public var recordLength: Float = 0
  @Published public var rxAntList = [AntennaPort]()
  @Published public var sliceLetter: String?
  @Published public var txAntList = [AntennaPort]()
  @Published public var wide: Bool = false
  
  @Published public internal(set) var active: Bool = false
  @Published public internal(set) var agcMode: String = AgcMode.off.rawValue
  @Published public internal(set) var agcOffLevel: Int = 0
  @Published public internal(set) var agcThreshold: Double = 0
  @Published public internal(set) var anfEnabled: Bool = false
  @Published public internal(set) var anfLevel: Double = 0
  @Published public internal(set) var apfEnabled: Bool = false
  @Published public internal(set) var apfLevel: Int = 0
  @Published public internal(set) var audioGain: Double = 0
  @Published public internal(set) var audioMute: Bool = false
  @Published public internal(set) var audioPan: Double = 0
  @Published public internal(set) var daxChannel: Int = 0
  @Published public internal(set) var dfmPreDeEmphasisEnabled: Bool = false
  @Published public internal(set) var digitalLowerOffset: Int = 0
  @Published public internal(set) var digitalUpperOffset: Int = 0
  @Published public internal(set) var diversityEnabled: Bool = false
  @Published public internal(set) var filterHigh: Int = 0
  @Published public internal(set) var filterLow: Int = 0
  @Published public internal(set) var fmDeviation: Int = 0
  @Published public internal(set) var fmRepeaterOffset: Float = 0
  @Published public internal(set) var fmToneBurstEnabled: Bool = false
  @Published public internal(set) var fmToneFreq: Float = 0
  @Published public internal(set) var fmToneMode: String = ""
  @Published public internal(set) var frequency: Hz = 0
  @Published public internal(set) var locked: Bool = false
  @Published public internal(set) var loopAEnabled: Bool = false
  @Published public internal(set) var loopBEnabled: Bool = false
  @Published public internal(set) var mode: String = ""
  @Published public internal(set) var nbEnabled: Bool = false
  @Published public internal(set) var nbLevel: Double = 0
  @Published public internal(set) var nrEnabled: Bool = false
  @Published public internal(set) var nrLevel: Double = 0
  @Published public internal(set) var playbackEnabled: Bool = false
  @Published public internal(set) var recordEnabled: Bool = false
  @Published public internal(set) var repeaterOffsetDirection: String = ""
  @Published public internal(set) var rfGain: Int = 0
  @Published public internal(set) var ritEnabled: Bool = false
  @Published public internal(set) var ritOffset: Int = 0
  @Published public internal(set) var rttyMark: Int = 0
  @Published public internal(set) var rttyShift: Int = 0
  @Published public internal(set) var rxAnt: String = ""
  @Published public internal(set) var sampleRate: Int = 0
  @Published public internal(set) var splitId: SliceId?
  @Published public internal(set) var step: Int = 0
  @Published public internal(set) var stepList: String = "1, 10, 50, 100, 500, 1000, 2000, 3000"
  @Published public internal(set) var squelchEnabled: Bool = false
  @Published public internal(set) var squelchLevel: Int = 0
  @Published public internal(set) var txAnt: String = ""
  @Published public internal(set) var txEnabled: Bool = false
  @Published public internal(set) var txOffsetFreq: Float = 0
  @Published public internal(set) var wnbEnabled: Bool = false
  @Published public internal(set) var wnbLevel: Double = 0
  @Published public internal(set) var xitEnabled: Bool = false
  @Published public internal(set) var xitOffset: Int = 0

  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  public let id: SliceId
  public var initialized: Bool = false
  
  public var agcNames = AgcMode.names()
  public let daxChoices = Radio.kDaxChannels
  public var filters = [(low: Int, high: Int)]()

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
//        if ApiModel.shared.slices[id: id] == nil { ApiModel.shared.slices.append( Slice(id) ) }
//        // parse the properties
//        ApiModel.shared.slices[id: id]!.parse( Array(properties.dropFirst(1)) )
//        
//      } else {
//        // NO, remove it
//        ApiModel.shared.slices.remove(id: id)
//        log("Slice \(id): REMOVED", .debug, #function, #file, #line)
//      }
//    }
//  }

// ----------------------------------------------------------------------------
// MARK: - Public Instance methods

  /// Parse key/value pairs
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Slice \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .active:                   active = property.value.bValue ; apiModel.activeSlice = self
      case .agcMode:                  agcMode = property.value
      case .agcOffLevel:              agcOffLevel = property.value.iValue
      case .agcThreshold:             agcThreshold = property.value.dValue
      case .anfEnabled:               anfEnabled = property.value.bValue
      case .anfLevel:                 anfLevel = property.value.dValue
      case .apfEnabled:               apfEnabled = property.value.bValue
      case .apfLevel:                 apfLevel = property.value.iValue
      case .audioGain:                audioGain = property.value.dValue
      case .audioLevel:               audioGain = property.value.dValue
      case .audioMute:                audioMute = property.value.bValue
      case .audioPan:                 audioPan = property.value.dValue
      case .clientHandle:             clientHandle = property.value.handle ?? 0
      case .daxChannel:
        if daxChannel != 0 && property.value.iValue == 0 {
          // remove this slice from the AudioStream it was using
          //          if let daxRxAudioStream = radio.findDaxRxAudioStream(with: daxChannel) { daxRxAudioStream.slice = nil }
        }
        apiModel.slices[id: id]!.daxChannel = property.value.iValue
      case .daxTxEnabled:             daxTxEnabled = property.value.bValue
      case .detached:                 detached = property.value.bValue
      case .dfmPreDeEmphasisEnabled:  dfmPreDeEmphasisEnabled = property.value.bValue
      case .digitalLowerOffset:       digitalLowerOffset = property.value.iValue
      case .digitalUpperOffset:       digitalUpperOffset = property.value.iValue
      case .diversityEnabled:         diversityEnabled = property.value.bValue
      case .diversityChild:           diversityChild = property.value.bValue
      case .diversityIndex:           diversityIndex = property.value.iValue
      case .filterHigh:               filterHigh = property.value.iValue
      case .filterLow:                filterLow = property.value.iValue
      case .fmDeviation:              fmDeviation = property.value.iValue
      case .fmRepeaterOffset:         fmRepeaterOffset = property.value.fValue
      case .fmToneBurstEnabled:       fmToneBurstEnabled = property.value.bValue
      case .fmToneMode:               fmToneMode = property.value
      case .fmToneFreq:               fmToneFreq = property.value.fValue
      case .frequency:                frequency = property.value.mhzToHz
      case .inUse:                    inUse = property.value.bValue
      case .locked:                   locked = property.value.bValue
      case .loopAEnabled:             loopAEnabled = property.value.bValue
      case .loopBEnabled:             loopBEnabled = property.value.bValue
      case .mode:                     mode = property.value.uppercased() ; filters = Slice.filterDefaults[mode]!
      case .modeList:                 modeList = property.value
      case .nbEnabled:                nbEnabled = property.value.bValue
      case .nbLevel:                  nbLevel = property.value.dValue
      case .nrEnabled:                nrEnabled = property.value.bValue
      case .nrLevel:                  nrLevel = property.value.dValue
      case .nr2:                      nr2 = property.value.iValue
      case .owner:                    nr2 = property.value.iValue
      case .panadapterId:             panadapterId = property.value.streamId ?? 0
      case .playbackEnabled:          playbackEnabled = (property.value == "enabled") || (property.value == "1")
      case .postDemodBypassEnabled:   postDemodBypassEnabled = property.value.bValue
      case .postDemodLow:             postDemodLow = property.value.iValue
      case .postDemodHigh:            postDemodHigh = property.value.iValue
      case .qskEnabled:               qskEnabled = property.value.bValue
      case .recordEnabled:            recordEnabled = property.value.bValue
      case .repeaterOffsetDirection:  repeaterOffsetDirection = property.value
      case .rfGain:                   rfGain = property.value.iValue
      case .ritOffset:                ritOffset = property.value.iValue
      case .ritEnabled:               ritEnabled = property.value.bValue
      case .rttyMark:                 rttyMark = property.value.iValue
      case .rttyShift:                rttyShift = property.value.iValue
      case .rxAnt:                    rxAnt = property.value
      case .rxAntList:                rxAntList = property.value.list
      case .sampleRate:               sampleRate = property.value.iValue         // FIXME: ????? not in v3.2.15 source code
      case .sliceLetter:              sliceLetter = property.value
      case .squelchEnabled:           squelchEnabled = property.value.bValue
      case .squelchLevel:             squelchLevel = property.value.iValue
      case .step:                     step = property.value.iValue
      case .stepList:                 stepList = property.value
      case .txEnabled:                txEnabled = property.value.bValue
      case .txAnt:                    txAnt = property.value
      case .txAntList:                txAntList = property.value.list
      case .txOffsetFreq:             txOffsetFreq = property.value.fValue
      case .wide:                     wide = property.value.bValue
      case .wnbEnabled:               wnbEnabled = property.value.bValue
      case .wnbLevel:                 wnbLevel = property.value.dValue
      case .xitOffset:                xitOffset = property.value.iValue
      case .xitEnabled:               xitEnabled = property.value.bValue
        
        // the following are ignored here
      case .daxClients, .diversityParent, .recordTime: break
      case .ghost:                    break
      }
    }
    // is it initialized?
    if initialized == false && panadapterId != 0 && frequency != 0 && mode != "" {
      // NO, it is now
      initialized = true
      log("Slice \(id): ADDED, frequency = \( apiModel.slices[id: id]!.frequency), panadapter = \( apiModel.slices[id: id]!.panadapterId.hex)", .debug, #function, #file, #line)
    }
  }

//  public func setProperty(radio: Radio, property: Slice.Property, value: Any) {
//    switch property {
//    case .active:                   Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .agcMode:                  Slice.command(radio, id, property, value)
//    case .agcOffLevel:              Slice.command(radio, id, property, value)
//    case .agcThreshold:             Slice.command(radio, id, property, Int(value as! Double))
//    case .anfEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .anfLevel:                 Slice.command(radio, id, property, Int(value as! Double))
//    case .apfEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .apfLevel:                 Slice.command(radio, id, property, Int(value as! Double))
//    case .audioLevel:               Slice.command(radio, id, property, Int(value as! Double))
//    case .audioMute:                Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .audioPan:                 Slice.command(radio, id, property, Int(value as! Double))
//    case .daxChannel:               Slice.command(radio, id, property, value)
//    case .daxTxEnabled:             Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .dfmPreDeEmphasisEnabled:  Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .digitalLowerOffset:       Slice.command(radio, id, property, value)
//    case .digitalUpperOffset:       Slice.command(radio, id, property, value)
//    case .diversityEnabled:         Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .filterHigh:               Slice.filterCommand(radio, id, low: ApiModel.shared.slices[id: id]!.filterLow, high: value)
//    case .filterLow:                Slice.filterCommand(radio, id, low: value, high: ApiModel.shared.slices[id: id]!.filterHigh)
//    case .fmDeviation:              Slice.command(radio, id, property, value)
//    case .fmRepeaterOffset:         Slice.command(radio, id, property, value)
//    case .fmToneBurstEnabled:       Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .fmToneFreq:               Slice.command(radio, id, property, value)
//    case .fmToneMode:               Slice.command(radio, id, property, value)
//    case .frequency:                Slice.tuneCommand(radio, id, value, autoPan: ApiModel.shared.slices[id: id]!.autoPan)
//    case .locked:                   Slice.lockCommand(radio, id, (value as! Bool) ? "lock" : "unlock")
//    case .loopAEnabled:             Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .loopBEnabled:             Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .mode:                     Slice.command(radio, id, property, value)
//    case .nbEnabled:                Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .nbLevel:                  Slice.command(radio, id, property, Int(value as! Double))
//    case .nrEnabled:                Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .nrLevel:                  Slice.command(radio, id, property, Int(value as! Double))
//    case .playbackEnabled:          Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .postDemodBypassEnabled:   Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .qskEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .recordEnabled:            Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .repeaterOffsetDirection:  Slice.command(radio, id, property, value)
//    case .rfGain:                   Slice.command(radio, id, property, value)
//    case .ritEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .ritOffset:                Slice.command(radio, id, property, value)
//    case .rttyMark:                 Slice.command(radio, id, property, value)
//    case .rttyShift:                Slice.command(radio, id, property, value)
//    case .rxAnt:                    Slice.command(radio, id, property, value)
//    case .sampleRate:               Slice.command(radio, id, property, value)
//    case .squelchEnabled:           Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .squelchLevel:             Slice.command(radio, id, property, value)
//    case .step:                     Slice.command(radio, id, property, value)
//    case .stepList:                 Slice.command(radio, id, property, value)
//    case .txEnabled:                Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .txAnt:                    Slice.command(radio, id, property, value)
//    case .txOffsetFreq:             Slice.command(radio, id, property, value)
//    case .wnbEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .wnbLevel:                 Slice.command(radio, id, property, Int(value as! Double))
//    case .xitEnabled:               Slice.command(radio, id, property, (value as! Bool).as1or0)
//    case .xitOffset:                Slice.command(radio, id, property, value)
//      
//    case .clientHandle,.daxClients,.detached:                   break
//    case .diversityChild,.diversityIndex,.diversityParent:      break
//    case .ghost,.inUse,.modeList,.nr2,.owner:                   break
//    case .panadapterId,.postDemodHigh,.postDemodLow:            break
//    case .recordTime,.rxAntList,.sliceLetter,.txAntList,.wide:  break
//    case .audioGain:                                            break
//    }
//    
//    Task {
//      switch property {
//      case .nbEnabled, .nrEnabled, .anfEnabled, .wnbEnabled, .audioMute, .ritEnabled, .xitEnabled:
//        ApiModel.shared.slices[id: id]?.parse( [(key: property.rawValue, value: "\((value as! Bool).as1or0)")] )
//        
//       ApiModel.shared.slices[id: id]?.parse( [(key: property.rawValue, value: "\(value)")] )
//      case .active:
//        break
//      case .agcMode:
//        break
//      case .agcOffLevel:
//        break
//      case .agcThreshold:
//        break
//      case .anfLevel:
//        break
//      case .apfEnabled:
//        break
//      case .apfLevel:
//        break
//      case .audioGain:
//        break
//      case .audioLevel:
//        break
//      case .audioPan:
//        break
//      case .clientHandle:
//        break
//      case .daxChannel:
//        break
//      case .daxClients:
//        break
//      case .daxTxEnabled:
//        break
//      case .detached:
//        break
//      case .dfmPreDeEmphasisEnabled:
//        break
//      case .digitalLowerOffset:
//        break
//      case .digitalUpperOffset:
//        break
//      case .diversityEnabled:
//        break
//      case .diversityChild:
//        break
//      case .diversityIndex:
//        break
//      case .diversityParent:
//        break
//      case .filterHigh:
//        break
//      case .filterLow:
//        break
//      case .fmDeviation:
//        break
//      case .fmRepeaterOffset:
//        break
//      case .fmToneBurstEnabled:
//        break
//      case .fmToneMode:
//        break
//      case .fmToneFreq:
//        break
//      case .frequency:
//        break
//      case .ghost:
//        break
//      case .inUse:
//        break
//      case .locked:
//        break
//      case .loopAEnabled:
//        break
//      case .loopBEnabled:
//        break
//      case .mode:
//        break
//      case .modeList:
//        break
//      case .nbLevel:
//        break
//      case .nrLevel:
//        break
//      case .nr2:
//        break
//      case .owner:
//        break
//      case .panadapterId:
//        break
//      case .playbackEnabled:
//        break
//      case .postDemodBypassEnabled:
//        break
//      case .postDemodHigh:
//        break
//      case .postDemodLow:
//        break
//      case .qskEnabled:
//        break
//      case .recordEnabled:
//        break
//      case .recordTime:
//        break
//      case .repeaterOffsetDirection:
//        break
//      case .rfGain:
//        break
//      case .ritOffset:
//        break
//      case .rttyMark:
//        break
//      case .rttyShift:
//        break
//      case .rxAnt:
//        break
//      case .rxAntList:
//        break
//      case .sampleRate:
//        break
//      case .sliceLetter:
//        break
//      case .squelchEnabled:
//        break
//      case .squelchLevel:
//        break
//      case .step:
//        break
//      case .stepList:
//        break
//      case .txEnabled:
//        break
//      case .txAnt:
//        break
//      case .txAntList:
//        break
//      case .txOffsetFreq:
//        break
//      case .wide:
//        break
//      case .wnbLevel:
//        break
//      case .xitOffset:
//        break
//      }
//    }
//  }
}

// ----------------------------------------------------------------------------
// MARK: - Private methods

extension Slice {
  /// Set the default Filter widths
  /// - Parameters:
  ///   - mode:       demod mode
  ///
  private func setupDefaultFilters(_ mode: String) {
    if let modeValue = Mode(rawValue: mode) {
      switch modeValue {
        
      case .CW:
        filterLow = 450
        filterHigh = 750
      case .RTTY:
        filterLow = -285
        filterHigh = 115
      case .AM, .SAM:
        filterLow = -3_000
        filterHigh = 3_000
      case .FM, .NFM, .DFM:
        filterLow = -8_000
        filterHigh = 8_000
      case .LSB, .DIGL:
        filterLow = -2_400
        filterHigh = -300
      case .USB, .DIGU:
        filterLow = 300
        filterHigh = 2_400
      }
    }
  }

  /// Send a command to Set a Slice property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified Slice
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func command(_ radio: Radio, _ id: SliceId, _ token: Slice.Property, _ value: Any) {
    radio.send("slice set " + "\(id) " + token.rawValue + "=\(value)")
  }
  
  private static func filterCommand(_ radio: Radio, _ id: SliceId, low: Any, high: Any) {
    radio.send("filt \(id) " + "\(low) \(high)")
  }
  
  public static func tuneCommand(_ radio: Radio, _ id: SliceId, _ value: Any, autoPan: Bool = false) {
    radio.send("slice tune " + "\(id) \(value) " + "autopan" + "=\(autoPan.as1or0)")
  }
  /// Set a Slice Lock property on the Radio
  /// - Parameters:
  ///   - value:      the new value (lock / unlock)
  public static func lockCommand(_ radio: Radio, _ id: SliceId, _ lockState: String) {
    radio.send("slice " + lockState + " \(id)")
  }
}

// ----------------------------------------------------------------------------
// MARK: - Static properties

extension Slice {
  static let kMinOffset = -99_999 // frequency offset range
  static let kMaxOffset = 99_999
  static let filterDefaults =     // Values of filters (by mode) (low, high)
  [
    "AM":   [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "SAM":  [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "CW":   [(450,500), (450,525), (450,550), (450,600), (450,700), (450,850), (450,1250), (450,1450), (450,1950), (450,3450)],
    "USB":  [(300,1500), (300,1700), (300,1900), (300,2100), (300,2400), (300,2700), (300,3000), (300,3200), (300,3600), (300,4300)],
    "LSB":  [(-1500,-300), (-1700,-300), (-1900,-300), (-2100,-300), (-2400,-300), (-2700,-300), (-3000,-300), (-3200,-300), (-3600,-300), (-4300,-300)],
    "FM":   [(-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000)],
    "NFM":  [(-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000), (-8000,8000)],
    "DFM":  [(-1500,1500), (-2000,2000), (-2800,2800), (-3000,3000), (-4000,4000), (-5000,5000), (-6000,6000), (-7000,7000), (-8000,8000), (-10000,10000)],
    "DIGU": [(300,1500), (300,1700), (300,1900), (300,2100), (300,2400), (300,2700), (300,3000), (300,3200), (300,3600), (300,4300)],
    "DIGL": [(-1500,-300), (-1700,-300), (-1900,-300), (-2100,-300), (-2400,-300), (-2700,-300), (-3000,-300), (-3200,-300), (-3600,-300), (-4300,-300)],
    "RTTY": [(-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115), (-285, 115)]
  ]
}

// ----------------------------------------------------------------------------
// MARK: - Public enums and structs

extension Slice {
  
  public enum Offset: String {
    case up
    case down
    case simplex
  }
  public enum AgcMode: String, CaseIterable {
    case off
    case slow
    case med
    case fast
    
    static func names() -> [String] {
      return [AgcMode.off.rawValue, AgcMode.slow.rawValue, AgcMode.med.rawValue, AgcMode.fast.rawValue]
    }
  }
  public enum Mode: String, CaseIterable {
    case AM
    case SAM
    case CW
    case USB
    case LSB
    case FM
    case NFM
    case DFM
    case DIGU
    case DIGL
    case RTTY
    //    case dsb
    //    case dstr
    //    case fdv
  }
  
  public enum Property: String, Equatable {
    case active
    case agcMode                    = "agc_mode"
    case agcOffLevel                = "agc_off_level"
    case agcThreshold               = "agc_threshold"
    case anfEnabled                 = "anf"
    case anfLevel                   = "anf_level"
    case apfEnabled                 = "apf"
    case apfLevel                   = "apf_level"
    case audioGain                  = "audio_gain"
    case audioLevel                 = "audio_level"
    case audioMute                  = "audio_mute"
    case audioPan                   = "audio_pan"
    case clientHandle               = "client_handle"
    case daxChannel                 = "dax"
    case daxClients                 = "dax_clients"
    case daxTxEnabled               = "dax_tx"
    case detached
    case dfmPreDeEmphasisEnabled    = "dfm_pre_de_emphasis"
    case digitalLowerOffset         = "digl_offset"
    case digitalUpperOffset         = "digu_offset"
    case diversityEnabled           = "diversity"
    case diversityChild             = "diversity_child"
    case diversityIndex             = "diversity_index"
    case diversityParent            = "diversity_parent"
    case filterHigh                 = "filter_hi"
    case filterLow                  = "filter_lo"
    case fmDeviation                = "fm_deviation"
    case fmRepeaterOffset           = "fm_repeater_offset_freq"
    case fmToneBurstEnabled         = "fm_tone_burst"
    case fmToneMode                 = "fm_tone_mode"
    case fmToneFreq                 = "fm_tone_value"
    case frequency                  = "rf_frequency"
    case ghost
    case inUse                      = "in_use"
    case locked                     = "lock"
    case loopAEnabled               = "loopa"
    case loopBEnabled               = "loopb"
    case mode
    case modeList                   = "mode_list"
    case nbEnabled                  = "nb"
    case nbLevel                    = "nb_level"
    case nrEnabled                  = "nr"
    case nrLevel                    = "nr_level"
    case nr2
    case owner
    case panadapterId               = "pan"
    case playbackEnabled            = "play"
    case postDemodBypassEnabled     = "post_demod_bypass"
    case postDemodHigh              = "post_demod_high"
    case postDemodLow               = "post_demod_low"
    case qskEnabled                 = "qsk"
    case recordEnabled              = "record"
    case recordTime                 = "record_time"
    case repeaterOffsetDirection    = "repeater_offset_dir"
    case rfGain                     = "rfgain"
    case ritEnabled                 = "rit_on"
    case ritOffset                  = "rit_freq"
    case rttyMark                   = "rtty_mark"
    case rttyShift                  = "rtty_shift"
    case rxAnt                      = "rxant"
    case rxAntList                  = "ant_list"
    case sampleRate                 = "sample_rate"
    case sliceLetter                = "index_letter"
    case squelchEnabled             = "squelch"
    case squelchLevel               = "squelch_level"
    case step
    case stepList                   = "step_list"
    case txEnabled                  = "tx"
    case txAnt                      = "txant"
    case txAntList                  = "tx_ant_list"
    case txOffsetFreq               = "tx_offset_freq"
    case wide
    case wnbEnabled                 = "wnb"
    case wnbLevel                   = "wnb_level"
    case xitEnabled                 = "xit_on"
    case xitOffset                  = "xit_freq"
  }
  
  /*
   "slice m " + StringHelper.DoubleToString(clicked_freq_MHz, "f6") + " pan=0x" + _streamID.ToString("X")
   "slice create"
   "slice set " + _index + " active=" + Convert.ToByte(_active)
   "slice set " + _index + " rxant=" + _rxant
   "slice set" + _index + " rfgain=" + _rfGain
   "slice set " + _index + " txant=" + _txant
   "slice set " + _index + " mode=" + _demodMode
   "slice set " + _index + " dax=" + _daxChannel
   "slice set " + _index + " rtty_mark=" + _rttyMark
   "slice set " + _index + " rtty_shift=" + _rttyShift
   "slice set " + _index + " digl_offset=" + _diglOffset
   "slice set " + _index + " digu_offset=" + _diguOffset
   "slice set " + _index + " audio_pan=" + _audioPan
   "slice set " + _index + " audio_level=" + _audioGain
   "slice set " + _index + " audio_mute=" + Convert.ToByte(value)
   "slice set " + _index + " anf=" + Convert.ToByte(value)
   "slice set " + _index + " apf=" + Convert.ToByte(value)
   "slice set " + _index + " anf_level=" + _anf_level
   "slice set " + _index + " apf_level=" + _apf_level
   "slice set " + _index + " diversity=" + Convert.ToByte(value)
   "slice set " + _index + " wnb=" + Convert.ToByte(value)
   "slice set " + _index + " nb=" + Convert.ToByte(value)
   "slice set " + _index + " wnb_level=" + _wnb_level)
   "slice set " + _index + " nb_level=" + _nb_level
   "slice set " + _index + " nr=" + Convert.ToByte(_nr_on)
   "slice set " + _index + " nr_level=" + _nr_level
   "slice set " + _index + " agc_mode=" + AGCModeToString(_agc_mode)
   "slice set " + _index + " agc_threshold=" + _agc_threshold
   "slice set " + _index + " agc_off_level=" + _agc_off_level
   "slice set " + _index + " tx=" + Convert.ToByte(_isTransmitSlice)
   "slice set " + _index + " loopa=" + Convert.ToByte(_loopA)
   "slice set " + _index + " loopb=" + Convert.ToByte(_loopB)
   "slice set " + _index + " rit_on=" + Convert.ToByte(_ritOn)
   "slice set " + _index + " rit_freq=" + _ritFreq
   "slice set " + _index + " xit_on=" + Convert.ToByte(_xitOn)
   "slice set " + _index + " xit_freq=" + _xitFreq
   "slice set " + _index + " step=" + _tuneStep
   "slice set " + _index + " record=" + Convert.ToByte(_record_on)
   "slice set " + _index + " play=" + Convert.ToByte(_playOn)
   "slice set " + _index + " fm_tone_mode=" + FMToneModeToString(_toneMode)
   "slice set " + _index + " fm_tone_value=" + _fmToneValue
   "slice set " + _index + " fm_deviation=" + _fmDeviation
   "slice set " + _index + " dfm_pre_de_emphasis=" + Convert.ToByte(_dfmPreDeEmphasis)
   "slice set " + _index + " squelch=" + Convert.ToByte(_squelchOn)
   "slice set " + _index + " squelch_level=" + _squelchLevel
   "slice set " + _index + " tx_offset_freq=" + StringHelper.DoubleToString(_txOffsetFreq, "f6")
   "slice set " + _index + " fm_repeater_offset_freq=" + StringHelper.DoubleToString(_fmRepeaterOffsetFreq, "f6")
   "slice set " + _index + " repeater_offset_dir=" + FMTXOffsetDirectionToString(_repeaterOffsetDirection)
   "slice set " + _index + " fm_tone_burst=" + Convert.ToByte(_fmTX1750)
   "slice remove " + _index
   "slice waveform_cmd " + _index + " " + s
   */
}
