//
//  Transmit.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import ComposableArchitecture

import Shared

/// Transmit Class implementation
///
///      creates a Transmit instance to be used by a Client to support the
///      processing of the Transmit-related activities. Transmit structs are added,
///      removed and updated by the incoming TCP messages.
///
@MainActor
public final class Transmit: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init() {}
  
  @Dependency(\.apiModel) var apiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public internal(set) var initialized = false
  
  @Published public var carrierLevel = 0
  @Published public var companderEnabled = false
  @Published public var companderLevel = 0
  @Published public var cwBreakInDelay = 0
  @Published public var cwBreakInEnabled = false
  @Published public var cwIambicEnabled = false
  @Published public var cwIambicMode = 0
  @Published public var cwlEnabled = false
  @Published public var cwMonitorGain = 0
  @Published public var cwMonitorPan = 0
  @Published public var cwPitch = 0
  @Published public var cwSidetoneEnabled = false
  @Published public var cwSpeed = 0
  @Published public var cwSwapPaddles = false
  @Published public var cwSyncCwxEnabled = false
  @Published public var daxEnabled = false
  @Published public var frequency: Hz = 0
  @Published public var hwAlcEnabled = false
  @Published public var inhibit = false
  @Published public var maxPowerLevel = 0
  @Published public var meterInRxEnabled = false
  @Published public var micAccEnabled = false
  @Published public var micBiasEnabled = false
  @Published public var micBoostEnabled = false
  @Published public var micLevel = 0
  @Published public var micSelection = ""
  @Published public var rawIqEnabled = false
  @Published public var rfPower = 0
  @Published public var speechProcessorEnabled = false
  @Published public var speechProcessorLevel = 0
  @Published public var ssbMonitorGain = 0
  @Published public var ssbMonitorPan = 0
  @Published public var tune = false
  @Published public var tunePower = 0
  @Published public var txAntenna = ""
  @Published public var txFilterChanges = false
  @Published public var txFilterHigh = 0
  @Published public var txFilterLow = 0
  @Published public var txInWaterfallEnabled = false
  @Published public var txMonitorAvailable = false
  @Published public var txMonitorEnabled = false
  @Published public var txRfPowerChanges = false
  @Published public var txSliceMode = ""
  @Published public var voxEnabled = false
  @Published public var voxDelay = 0
  @Published public var voxLevel = 0
  
  public enum Property: String {
    case amCarrierLevel           = "am_carrier_level"              // "am_carrier"
    case companderEnabled         = "compander"
    case companderLevel           = "compander_level"
    case cwBreakInDelay           = "break_in_delay"
    case cwBreakInEnabled         = "break_in"
    case cwIambicEnabled          = "iambic"
    case cwIambicMode             = "iambic_mode"                   // "mode"
    case cwlEnabled               = "cwl_enabled"
    case cwMonitorGain            = "mon_gain_cw"
    case cwMonitorPan             = "mon_pan_cw"
    case cwPitch                  = "pitch"
    case cwSidetoneEnabled        = "sidetone"
    case cwSpeed                  = "speed"                         // "wpm"
    case cwSwapPaddles            = "swap_paddles"                  // "swap"
    case cwSyncCwxEnabled         = "synccwx"
    case daxEnabled               = "dax"
    case frequency                = "freq"
    case hwAlcEnabled             = "hwalc_enabled"
    case inhibit
    case maxPowerLevel            = "max_power_level"
    case meterInRxEnabled         = "met_in_rx"
    case micAccEnabled            = "mic_acc"                       // "acc"
    case micBoostEnabled          = "mic_boost"                     // "boost"
    case micBiasEnabled           = "mic_bias"                      // "bias"
    case micLevel                 = "mic_level"                     // "miclevel"
    case micSelection             = "mic_selection"                 // "input"
    case rawIqEnabled             = "raw_iq_enable"
    case rfPower                  = "rfpower"
    case speechProcessorEnabled   = "speech_processor_enable"
    case speechProcessorLevel     = "speech_processor_level"
    case ssbMonitorGain           = "mon_gain_sb"
    case ssbMonitorPan            = "mon_pan_sb"
    case tune
    case tunePower                = "tunepower"
    case txAntenna                = "tx_antenna"
    case txFilterChanges          = "tx_filter_changes_allowed"
    case txFilterHigh             = "hi"                            // "filter_high"
    case txFilterLow              = "lo"                            // "filter_low"
    case txInWaterfallEnabled     = "show_tx_in_waterfall"
    case txMonitorAvailable       = "mon_available"
    case txMonitorEnabled         = "sb_monitor"                    // "mon"
    case txRfPowerChanges         = "tx_rf_power_changes_allowed"
    case txSliceMode              = "tx_slice_mode"
    case voxEnabled               = "vox_enable"
    case voxDelay                 = "vox_delay"
    case voxLevel                 = "vox_level"
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse a Transmit status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Transmit: unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .amCarrierLevel:         carrierLevel = property.value.iValue
      case .companderEnabled:       companderEnabled = property.value.bValue
      case .companderLevel:         companderLevel = property.value.iValue
      case .cwBreakInEnabled:       cwBreakInEnabled = property.value.bValue
      case .cwBreakInDelay:         cwBreakInDelay = property.value.iValue
      case .cwIambicEnabled:        cwIambicEnabled = property.value.bValue
      case .cwIambicMode:           cwIambicMode = property.value.iValue
      case .cwlEnabled:             cwlEnabled = property.value.bValue
      case .cwMonitorGain:          cwMonitorGain = property.value.iValue
      case .cwMonitorPan:           cwMonitorPan = property.value.iValue
      case .cwPitch:                cwPitch = property.value.iValue
      case .cwSidetoneEnabled:      cwSidetoneEnabled = property.value.bValue
      case .cwSpeed:                cwSpeed = property.value.iValue
      case .cwSwapPaddles:          cwSwapPaddles = property.value.bValue
      case .cwSyncCwxEnabled:       cwSyncCwxEnabled = property.value.bValue
      case .daxEnabled:             daxEnabled = property.value.bValue
      case .frequency:              frequency = property.value.mhzToHz
      case .hwAlcEnabled:           hwAlcEnabled = property.value.bValue
      case .inhibit:                inhibit = property.value.bValue
      case .maxPowerLevel:          maxPowerLevel = property.value.iValue
      case .meterInRxEnabled:       meterInRxEnabled = property.value.bValue
      case .micAccEnabled:          micAccEnabled = property.value.bValue
      case .micBoostEnabled:        micBoostEnabled = property.value.bValue
      case .micBiasEnabled:         micBiasEnabled = property.value.bValue
      case .micLevel:               micLevel = property.value.iValue
      case .micSelection:           micSelection = property.value
      case .rawIqEnabled:           rawIqEnabled = property.value.bValue
      case .rfPower:                rfPower = property.value.iValue
      case .speechProcessorEnabled: speechProcessorEnabled = property.value.bValue
      case .speechProcessorLevel:   speechProcessorLevel = property.value.iValue
      case .ssbMonitorGain:         ssbMonitorGain = property.value.iValue
      case .ssbMonitorPan:          ssbMonitorPan = property.value.iValue
      case .txAntenna:              txAntenna = property.value
      case .txFilterChanges:        txFilterChanges = property.value.bValue
      case .txFilterHigh:           txFilterHigh = property.value.iValue
      case .txFilterLow:            txFilterLow = property.value.iValue
      case .txInWaterfallEnabled:   txInWaterfallEnabled = property.value.bValue
      case .txMonitorAvailable:     txMonitorAvailable = property.value.bValue
      case .txMonitorEnabled:       txMonitorEnabled = property.value.bValue
      case .txRfPowerChanges:       txRfPowerChanges = property.value.bValue
      case .txSliceMode:            txSliceMode = property.value
      case .tune:                   tune = property.value.bValue
      case .tunePower:              tunePower = property.value.iValue
      case .voxEnabled:             voxEnabled = property.value.bValue
      case .voxDelay:               voxDelay = property.value.iValue
      case .voxLevel:               voxLevel = property.value.iValue
      }
    }
    // is it initialized?
    if initialized == false {
      // NO, it is now
      initialized = true
      log("Transmit: initialized", .debug, #function, #file, #line)
    }
  }
  

  public func parseAndSend(_ property: Property, _ value: String = "") {
    var newValue = value
    
    // alphabetical order
    switch property {
      
    case .amCarrierLevel:         newValue = value
    case .companderEnabled:       newValue = (!companderEnabled).as1or0
    case .companderLevel:         newValue = value
    case .cwBreakInEnabled:       newValue = (!cwBreakInEnabled).as1or0
    case .cwBreakInDelay:         newValue = value
    case .cwIambicEnabled:        newValue = (!cwIambicEnabled).as1or0
//    case .cwIambicMode:           cwIambicMode = property.value.iValue
//    case .cwlEnabled:             cwlEnabled = property.value.bValue
    case .cwMonitorGain:          newValue = value
    case .cwMonitorPan:           newValue = value
//    case .cwPitch:                cwPitch = property.value.iValue
    case .cwSidetoneEnabled:      newValue = (!cwSidetoneEnabled).as1or0
    case .cwSpeed:                newValue = value
//    case .cwSwapPaddles:          cwSwapPaddles = property.value.bValue
//    case .cwSyncCwxEnabled:       cwSyncCwxEnabled = property.value.bValue
    case .daxEnabled:             newValue = value
//    case .frequency:              frequency = property.value.mhzToHz
//    case .hwAlcEnabled:           hwAlcEnabled = property.value.bValue
//    case .inhibit:                inhibit = property.value.bValue
//    case .maxPowerLevel:          maxPowerLevel = property.value.iValue
    case .meterInRxEnabled:       newValue = (!meterInRxEnabled).as1or0
    case .micAccEnabled:          newValue = value
    case .micBoostEnabled:        newValue = (!micBoostEnabled).as1or0
    case .micBiasEnabled:         newValue = (!micBiasEnabled).as1or0
    case .micLevel:               newValue = value
    case .micSelection:           newValue = value
//    case .rawIqEnabled:           rawIqEnabled = property.value.bValue
    case .rfPower:                newValue = value
    case .speechProcessorEnabled: newValue = value
    case .speechProcessorLevel:   newValue = value
    case .ssbMonitorGain:         newValue = value
    case .ssbMonitorPan:          newValue = value
//    case .txAntenna:              txAntenna = property.value
//    case .txFilterChanges:        txFilterChanges = property.value.bValue
    case .txFilterHigh:           newValue = value
    case .txFilterLow:            newValue = value
//    case .txInWaterfallEnabled:   txInWaterfallEnabled = property.value.bValue
//    case .txMonitorAvailable:     txMonitorAvailable = property.value.bValue
    case .txMonitorEnabled:       newValue = value
//    case .txRfPowerChanges:       txRfPowerChanges = property.value.bValue
//    case .txSliceMode:            txSliceMode = property.value
    case .tune:                   newValue = (!tune).as1or0
    case .tunePower:              newValue = value
    case .voxEnabled:             newValue = (!voxEnabled).as1or0
    case .voxDelay:               newValue = value
    case .voxLevel:               newValue = value
    default:
      break
    }
    
    parse([(property.rawValue, newValue)])
    send(property, newValue)
  }
  
  public func send(_ property: Property, _ value: String) {
      // Known tokens, in alphabetical order
      switch property {
        
      case .amCarrierLevel:         transmitCmd("set", "am_carrier", "=", value)
      case .companderEnabled:       transmitCmd("set", property, "=", value)
      case .companderLevel:         transmitCmd("set", property, "=", value)
      case .cwBreakInEnabled:       cwCmd(property, " ", value)
      case .cwBreakInDelay:         cwCmd(property, " ", value)
      case .cwIambicEnabled:        cwCmd(property, " ", value)
      case .cwIambicMode:           cwCmd(property, " ", value)
//      case .cwlEnabled:             cwlEnabled = property.value.bValue
      case .cwMonitorGain:          transmitCmd("set", property, "=", value)
      case .cwMonitorPan:           transmitCmd("set", property, "=", value)
      case .cwPitch:                cwCmd(property, " ", value)
      case .cwSidetoneEnabled:      cwCmd(property, " ", value)
      case .cwSpeed:                cwCmd("wpm", " ", value)
//      case .cwSwapPaddles:          cwSwapPaddles = property.value.bValue
//      case .cwSyncCwxEnabled:       cwSyncCwxEnabled = property.value.bValue
      case .daxEnabled:             transmitCmd("set", property, "=", value)
//      case .frequency:              frequency = property.value.mhzToHz
//      case .hwAlcEnabled:           hwAlcEnabled = property.value.bValue
//      case .inhibit:                inhibit = property.value.bValue
//      case .maxPowerLevel:          maxPowerLevel = property.value.iValue
      case .meterInRxEnabled:       transmitCmd("set", property, "=", value)
      case .micAccEnabled:          micCmd("acc", " ", value)
      case .micBoostEnabled:        micCmd("boost", " ", value)
      case .micBiasEnabled:         micCmd("bias", " ", value)
      case .micLevel:               transmitCmd("set", "miclevel", "=", value)
      case .micSelection:           micCmd("input", " ", value.uppercased())
//      case .rawIqEnabled:           rawIqEnabled = property.value.bValue
      case .rfPower:                transmitCmd("set", property, "=", value)
      case .speechProcessorEnabled: transmitCmd("set", property, "=", value)
      case .speechProcessorLevel:   transmitCmd("set", property, "=", value)
      case .ssbMonitorGain:         transmitCmd("set", property, "=", value)
//      case .ssbMonitorPan:          ssbMonitorPan = property.value.iValue
//      case .txAntenna:              txAntenna = property.value
//      case .txFilterChanges:        txFilterChanges = property.value.bValue
      case .txFilterHigh:           transmitCmd("set", "filter_high", "=", value)
      case .txFilterLow:            transmitCmd("set", "filter_low", "=", value)
//      case .txInWaterfallEnabled:   txInWaterfallEnabled = property.value.bValue
//      case .txMonitorAvailable:     txMonitorAvailable = property.value.bValue
      case .txMonitorEnabled:       transmitCmd("set", "mon", "=", value)
//      case .txRfPowerChanges:       txRfPowerChanges = property.value.bValue
//      case .txSliceMode:            txSliceMode = property.value
      case .tune:                   transmitCmd("tune", "", "", value)
      case .tunePower:              transmitCmd("set", property, "=", value)
      case .voxEnabled:             transmitCmd("set", property, "=", value)
      case .voxDelay:               transmitCmd("set", property, "=", value)
      case .voxLevel:               transmitCmd("set", property, "=", value)
      default:
        break
      }
  }
  
  public func sendMox(_ value: Bool) {
    apiModel.send("xmit \(value.as1or0)")
  }
  
  public func sendAtu(_ token: String, _ value: String) {
    apiModel.send("atu set " + token + "=\(value)")
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Send a command to Set a property
  /// - Parameters:
  ///   - token:      the parse token
  ///   - separator:  String used between token and value
  ///   - value:      the new value
  private func transmitCmd(_ verb: String, _ token: Property, _ separator: String, _ value: Any) {
    apiModel.send("transmit " + verb + " " + token.rawValue + separator + "\(value)")
  }
  private func transmitCmd(_ verb: String, _ token: String, _ separator: String, _ value: Any) {
    apiModel.send("transmit " + verb + " " + token + separator + "\(value)")
  }
  private func micCmd(_ token: String, _ separator: String, _ value: Any) {
    apiModel.send("mic " + token + separator + "\(value)")
  }
  private func cwCmd(_ token: Property, _ separator: String, _ value: Any) {
    apiModel.send("cw " + token.rawValue + separator + "\(value)")
  }
  private func cwCmd(_ token: String, _ separator: String, _ value: Any) {
    apiModel.send("cw " + token + separator + "\(value)")
  }

}

  /*
   transmit set show_tx_in_waterfall=" + Convert.ToByte(_showTxInWaterfall));
   transmit set max_power_level=" + _maxPowerLevel);
   transmit set rfpower=" + _rfPower);
   transmit set tunepower=" + _tunePower);
   transmit set am_carrier=" + _amCarrierLevel);
   transmit set miclevel=" + _micLevel);
   transmit set hwalc_enabled=" + Convert.ToByte(_hwalcEnabled));
   transmit set filter_low=" + _txFilterLow + " filter_high=" + _txFilterHigh);
   transmit tune " + Convert.ToByte(_txTune));
   transmit set mon=" + Convert.ToByte(_txMonitor));
   transmit set mon_gain_cw=" + _txCWMonitorGain);
   transmit set mon_gain_sb=" + _txSBMonitorGain);
   transmit set mon_pan_cw=" + _txCWMonitorPan);
   transmit set mon_pan_sb=" + _txSBMonitorPan);
   transmit set inhibit=" + Convert.ToByte(_txInhibit));
   transmit set met_in_rx=" + Convert.ToByte(_met_in_rx));
   transmit set compander=" + Convert.ToByte(_companderOn));
   transmit set compander_level=" + _companderLevel);
   transmit set dax=" + Convert.ToByte(_daxOn));
   transmit set vox_enable=" + Convert.ToByte(_simpleVOXEnable));
   transmit set vox_level=" + _simpleVOXLevel);
   transmit set vox_delay=" + _simpleVOXDelay);
   transmit set speech_processor_enable=" + Convert.ToByte(_speechProcessorEnable));
   transmit set speech_processor_level=" + Convert.ToByte(_speechProcessorLevel));}
   
   mic boost " + Convert.ToByte(_micBoost));
   mic bias " + Convert.ToByte(_micBias));
   mic input " + _micInput.ToUpper());
   mic acc " + Convert.ToByte(_accOn));
   
   cw pitch " + _cwPitch);
   cw key immediate " + Convert.ToByte(state));
   cw wpm " + _cwSpeed);
   cw break_in_delay " + _cwDelay);
   cw break_in " + Convert.ToByte(_cwBreakIn));
   cw sidetone " + Convert.ToByte(_cwSidetone));
   cw iambic " + Convert.ToByte(_cwIambic));
   cw mode 0");
   cw mode 1");
   cw cwl_enabled " + Convert.ToByte(_cwl_enabled));
   cw swap " + Convert.ToByte(_cwSwapPaddles));
   cw synccwx " + Convert.ToByte(_syncCWX));
   */
