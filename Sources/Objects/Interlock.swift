//
//  Interlock.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 8/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import ComposableArchitecture
import Foundation

import Shared

// Interlock
//      creates an Interlock instance to be used by a Client to support the
//      processing of interlocks. Interlock instances are added, removed and
//      updated by the incoming TCP messages.
@MainActor
public final class Interlock: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization

  public init() {}

  @Dependency(\.apiModel) var apiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties

  public internal(set) var initialized  = false

  @Published public var accTxEnabled = false
  @Published public var accTxDelay = 0
  @Published public var accTxReqEnabled = false
  @Published public var accTxReqPolarity = false
  @Published public var amplifier = ""
  @Published public var rcaTxReqEnabled = false
  @Published public var rcaTxReqPolarity = false
  @Published public var reason = ""
  @Published public var source = ""
  @Published public var state = ""
  @Published public var timeout = 0
  @Published public var txAllowed = false
  @Published public var txClientHandle: Handle = 0
  @Published public var txDelay = 0
  @Published public var tx1Enabled = false
  @Published public var tx1Delay = 0
  @Published public var tx2Enabled = false
  @Published public var tx2Delay = 0
  @Published public var tx3Enabled = false
  @Published public var tx3Delay = 0

  public enum Property: String {
    case accTxEnabled       = "acc_tx_enabled"
    case accTxDelay         = "acc_tx_delay"
    case accTxReqEnabled    = "acc_txreq_enable"
    case accTxReqPolarity   = "acc_txreq_polarity"
    case amplifier
    case rcaTxReqEnabled    = "rca_txreq_enable"
    case rcaTxReqPolarity   = "rca_txreq_polarity"
    case reason
    case source
    case state
    case timeout
    case txAllowed          = "tx_allowed"
    case txClientHandle     = "tx_client_handle"
    case txDelay            = "tx_delay"
    case tx1Enabled         = "tx1_enabled"
    case tx1Delay           = "tx1_delay"
    case tx2Enabled         = "tx2_enabled"
    case tx2Delay           = "tx2_delay"
    case tx3Enabled         = "tx3_enabled"
    case tx3Delay           = "tx3_delay"
  }
  public enum States: String {
    case receive            = "RECEIVE"
    case ready              = "READY"
    case notReady           = "NOT_READY"
    case pttRequested       = "PTT_REQUESTED"
    case transmitting       = "TRANSMITTING"
    case txFault            = "TX_FAULT"
    case timeout            = "TIMEOUT"
    case stuckInput         = "STUCK_INPUT"
    case unKeyRequested     = "UNKEY_REQUESTED"
  }
  public enum PttSources: String {
    case software           = "SW"
    case mic                = "MIC"
    case acc                = "ACC"
    case rca                = "RCA"
  }
  public enum Reasons: String {
    case rcaTxRequest       = "RCA_TXREQ"
    case accTxRequest       = "ACC_TXREQ"
    case badMode            = "BAD_MODE"
    case tooFar             = "TOO_FAR"
    case outOfBand          = "OUT_OF_BAND"
    case paRange            = "PA_RANGE"
    case clientTxInhibit    = "CLIENT_TX_INHIBIT"
    case xvtrRxOnly         = "XVTR_RX_OLY"
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods

  /// Parse status message
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // NO, process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Interlock: unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {

      case .accTxEnabled:     accTxEnabled = property.value.bValue
      case .accTxDelay:       accTxDelay = property.value.iValue
      case .accTxReqEnabled:  accTxReqEnabled = property.value.bValue
      case .accTxReqPolarity: accTxReqPolarity = property.value.bValue
      case .amplifier:        amplifier = property.value
      case .rcaTxReqEnabled:  rcaTxReqEnabled = property.value.bValue
      case .rcaTxReqPolarity: rcaTxReqPolarity = property.value.bValue
      case .reason:           reason = property.value
      case .source:           source = property.value
      case .state:            state = property.value
      case .timeout:          timeout = property.value.iValue
      case .txAllowed:        txAllowed = property.value.bValue
      case .txClientHandle:   txClientHandle = property.value.handle ?? 0
      case .txDelay:          txDelay = property.value.iValue
      case .tx1Delay:         tx1Delay = property.value.iValue
      case .tx1Enabled:       tx1Enabled = property.value.bValue
      case .tx2Delay:         tx2Delay = property.value.iValue
      case .tx2Enabled:       tx2Enabled = property.value.bValue
      case .tx3Delay:         tx3Delay = property.value.iValue
      case .tx3Enabled:       tx3Enabled = property.value.bValue
      }
    }
    // is it initialized?
    if initialized == false {
      // NO, it is now
      initialized = true
      log("Interlock: initialized", .debug, #function, #file, #line)
    }
  }
  
  
  
  public func setOnly(_ property: Property, _ value: String = "") {
    parse([(property.rawValue, value)])
  }

  public func sendOnly(_ property: Property) {
    // Known tokens, in alphabetical order
    switch property {
    case .accTxDelay:     interlockCmd(.accTxDelay, accTxDelay)
    case .txDelay:        interlockCmd(.txDelay, txDelay)
    case .tx1Delay:       interlockCmd(.tx1Delay, tx1Delay)
    case .tx2Delay:       interlockCmd(.tx2Delay, tx2Delay)
    case .tx3Delay:       interlockCmd(.tx3Delay, tx3Delay)
    case .timeout:        interlockCmd(.timeout, timeout)
    default:              break
    }
  }

  
  public func setAndSend(_ property: Property, _ value: String = "") {
    var newValue = value
    
    // alphabetical order
    switch property {
      
    case .accTxEnabled:             newValue = value
    case .accTxDelay:               newValue = value
    case .accTxReqEnabled:          newValue = value
    case .accTxReqPolarity:         newValue = value
    case .amplifier:                newValue = value
    case .rcaTxReqEnabled:          newValue = value
    case .rcaTxReqPolarity:         newValue = value
    case .reason:                   newValue = value
    case .source:                   newValue = value
    case .state:                    newValue = value
    case .timeout:                  newValue = value
    case .txAllowed:                newValue = value
    case .txClientHandle:           newValue = value
    case .txDelay:                  newValue = value
    case .tx1Delay:                 newValue = value
    case .tx1Enabled:               newValue = value
    case .tx2Delay:                 newValue = value
    case .tx2Enabled:               newValue = value
    case .tx3Delay:                 newValue = value
    case .tx3Enabled:               newValue = value
      
    }
    parse([(property.rawValue, newValue)])
    send(property, newValue)
  }

  public func send(_ property: Property, _ value: String) {
      // Known tokens, in alphabetical order
      switch property {
        
      case .accTxEnabled:           interlockCmd(.accTxEnabled, value)
      case .accTxDelay:             interlockCmd(.accTxDelay, value)
      case .accTxReqEnabled:        interlockCmd(.accTxReqEnabled, value)
      case .accTxReqPolarity:       interlockCmd(.accTxReqPolarity, value)
      case .amplifier:              interlockCmd(.amplifier, value)
      case .rcaTxReqEnabled:        interlockCmd(.rcaTxReqEnabled, value)
      case .rcaTxReqPolarity:       interlockCmd(.rcaTxReqPolarity, value)
      case .reason:                 interlockCmd(.reason, value)
      case .source:                 interlockCmd(.source, value)
      case .state:                  interlockCmd(.state, value)
      case .timeout:                interlockCmd(.timeout, value)
      case .txAllowed:              interlockCmd(.txAllowed, value)
      case .txClientHandle:         interlockCmd(.txClientHandle, value)
      case .txDelay:                interlockCmd(.txDelay, value)
      case .tx1Delay:               interlockCmd(.tx1Delay, value)
      case .tx1Enabled:             interlockCmd(.tx1Enabled, value)
      case .tx2Delay:               interlockCmd(.tx2Delay, value)
      case .tx2Enabled:             interlockCmd(.tx2Enabled, value)
      case .tx3Delay:               interlockCmd(.tx3Delay, value)
      case .tx3Enabled:             interlockCmd(.tx3Enabled, value)
      }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private Static methods

  /// Send a command to Set an InterlockToken property
  /// - Parameters:
  ///   - token:      the parse token
  ///   - value:      the new value
  private func interlockCmd(_ token: Property, _ value: Any) {
    apiModel.send("interlock " + token.rawValue + "=\(value)")
  }
  
  /*
   "interlock timeout=" + _interlockTimeout
   "interlock rca_txreq_enable=" + Convert.ToByte(_txreqRCAEnabled)
   "interlock acc_txreq_enable=" + Convert.ToByte(_txreqACCEnabled)
   "interlock rca_txreq_polarity=" + Convert.ToByte(_txreqRCAPolarity)
   "interlock acc_txreq_polarity=" + Convert.ToByte(_txreqACCPolarity)
   "interlock tx_delay=" + _delayTX
   "interlock tx1_enabled=" + Convert.ToByte(_tx1Enabled)
   "interlock tx2_enabled=" + Convert.ToByte(_tx2Enabled)
   "interlock tx3_enabled=" + Convert.ToByte(_tx3Enabled)
   "interlock acc_tx_enabled=" + Convert.ToByte(_txACCEnabled)
   "interlock tx1_delay=" + _tx1Delay
   "interlock tx2_delay=" + _tx2Delay
   "interlock tx3_delay=" + _tx3Delay
   "interlock acc_tx_delay=" + _txACCDelay

   */
}
