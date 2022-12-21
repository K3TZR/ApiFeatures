//
//  ApiModel.swift
//  
//
//  Created by Douglas Adams on 11/14/22.
//

import Foundation
import ComposableArchitecture
import SwiftUI

import FlexErrors
import Listener
import Shared
import Tcp
import Udp

//public enum ConnectionError: String, Error {
//  case instantiation = "Failed to create Radio object"
//  case connection = "Failed to connect to Radio"
//  case replyError = "Reply with error"
//  case tcpConnect = "Tcp Failed to connect"
//  case udpBind = "Udp Failed to bind"
//  case wanConnect = "WanConnect Failed"
//  case wanValidation = "WanValidation Failed"
//}

// ----------------------------------------------------------------------------
// MARK: - Dependency decalarations

extension ApiModel: DependencyKey {
  public static let liveValue = ApiModel()
//  public static let previewValue = ApiModel()
  public static var previewValue: ApiModel {
    let model = ApiModel()
    model.equalizers.append(Equalizer("rxsc"))
    model.equalizers.append(Equalizer("txsc"))
    model.transmit.txFilterLow = 100
    model.transmit.txFilterHigh = 2000
    model.transmit.micSelection = "Mic2"
    model.profiles.append(Profile("mic"))
    model.profiles[id: "mic"]!.list = ["Profile1", "Profile2"]
    model.profiles[id: "mic"]!.current = "Profile2"
    model.profiles.append(Profile("tx"))
    model.profiles[id: "tx"]!.list = ["Profile3", "Profile4"]
    model.profiles[id: "tx"]!.current = "Profile4"
    model.radio = Radio(Packet())
    model.radio?.micList = ["Mic1", "Mic2", "Mic3"]
    model.atu.status = "BYP"
    return model
  }
}

extension DependencyValues {
  public var apiModel: ApiModel {
    get {self[ApiModel.self]}
    set {self[ApiModel.self] = newValue}
  }
}

@MainActor
public final class ApiModel: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (Singleton)
  
//  public static var shared = ApiModel()
  public init() {
    subscribeToMessages()
    subscribeToTcpStatus()
    subscribeToUdpStatus()
  }
  
  @Dependency(\.streamModel) var streamModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  @Published public var clientInitialized: Bool = false
  @Published public var radio: Radio?
  @Published public var activeEqualizer: Equalizer?
  @Published public var activeSlice: Slice?
  @Published public var activeStation: String?
  @Published public var activePacket: Packet?
  @Published public var activePanadapter: Panadapter?
  
  // Dynamic Models
  @Published public var amplifiers = IdentifiedArrayOf<Amplifier>()
  @Published public var bandSettings = IdentifiedArrayOf<BandSetting>()
  @Published public var equalizers = IdentifiedArrayOf<Equalizer>()
  @Published public var memories = IdentifiedArrayOf<Memory>()
  @Published public var meters = IdentifiedArrayOf<Meter>()
  @Published public var panadapters = IdentifiedArrayOf<Panadapter>()
  @Published public var profiles = IdentifiedArrayOf<Profile>()
  @Published public var slices = IdentifiedArrayOf<Slice>()
  @Published public var tnfs = IdentifiedArrayOf<Tnf>()
  @Published public var usbCables = IdentifiedArrayOf<UsbCable>()
  @Published public var waterfalls = IdentifiedArrayOf<Waterfall>()
  @Published public var xvtrs = IdentifiedArrayOf<Xvtr>()
  
  // Static Models
  @Published public var atu = Atu()
  @Published public var cwx = Cwx()
  @Published public var gps = Gps()
  @Published public var interlock = Interlock()
  @Published public var transmit = Transmit()
  @Published public var wan = Wan()
  @Published public var waveform = Waveform()

  
  @Published public var meterStreamId: StreamId = 0
  
  
  
  
  /// Send a command to the Radio (hardware)
  /// - Parameters:
  ///   - command:        a Command String
  ///   - flag:           use "D"iagnostic form
  ///   - callback:       a callback function (if any)
  public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil, continuation: CheckedContinuation<String, Error>? = nil) {
    // tell TcpCommands to send the command
    let sequenceNumber = Tcp.shared.send(command, diagnostic: flag)
    
    // register to be notified when reply received
    addReplyHandler( sequenceNumber, replyTuple: (replyTo: callback, command: command, continuation: continuation) )
  }
  
  public func findMeter(_ shortName: Meter.ShortName) -> Meter? {
    // find the Meters with the specified Name (if any)
    let selectedMeters = meters.filter { $0.name == shortName.rawValue }
    guard selectedMeters.count >= 1 else { return nil }
    
    // return the first one
    return selectedMeters[0]
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  public var replyHandlers = [SequenceNumber: ReplyTuple]()
  
  enum ObjectType: String {
    case amplifier
    case atu
    case bandSetting = "band"
    case client
    case cwx
    case daxIqStream = "dax_iq"
    case daxMicAudioStream = "dax_mic"
    case daxRxAudioStream = "dax_rx"
    case daxTxAudioStream = "dax_tx"
    case display
    case equalizer = "eq"
    case gps
    case interlock
    case memory
    case meter
    case panadapter = "pan"
    case profile
    case radio
    case remoteRxAudioStream = "remote_audio_rx"
    case remoteTxAudioStream = "remote_audio_tx"
    case slice
    case stream
    case tnf
    case transmit
    case usbCable = "usb_cable"
    case wan
    case waterfall
    case waveform
    case xvtr
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods (connection)
  
  /// Connect to a Radio
  /// - Parameters:
  ///   - selection: a Picker selection
  ///   - isGui: type of connection
  ///   - disconnectHandle: handle to another connection to be disconnected (if any)
  ///   - station: station name
  ///   - program: program name
  ///   - testerMode: whether Tester is active
  public func connectTo(selection: Pickable, isGui: Bool, disconnectHandle: Handle?, station: String, program: String) async throws {
    var wanHandle: String?
    
    let currentPacket = selection.packet
    
    // Instantiate a Radio
    radio = Radio(selection.packet,
                  connectionType: isGui ? .gui : .nonGui,
                  stationName: station,
                  programName: program,
                  disconnectHandle: disconnectHandle)
    // connect to it
    guard radio != nil else { throw ConnectionError.instantiation }
    log("Api: Radio instantiated for \(selection.packet.nickname), \(selection.packet.source == .smartlink ? "SMARTLINK" : "LOCAL")", .debug, #function, #file, #line)

    guard radio!.connect(selection.packet) else { throw ConnectionError.connection }
    log("Api: Tcp connection established ", .debug, #function, #file, #line)

    if disconnectHandle != nil {
      // pending disconnect
      radio!.send("client disconnect \(disconnectHandle!.hex)")
    }

    // wait for the first Status message with my handle
    await radio!.awaitClientConnected(selection.packet.source)
    log("Api: First status message received", .debug, #function, #file, #line)

    // is this a Wan connection?
    if selection.packet.source == .smartlink {
      // YES, send Wan Connect message & wait for the reply
      wanHandle = try await Listener.shared.sendWanConnect(for: selection.packet.serial, holePunchPort: selection.packet.negotiatedHolePunchPort)
      // put the wanHandle into the packet
      currentPacket.wanHandle = wanHandle!
      log("Api: wanHandle received", .debug, #function, #file, #line)

      // send Wan Validate & wait for the reply
      log("Api: Wan validate sent for handle=\(wanHandle!)", .debug, #function, #file, #line)
      _ = try await radio!.sendAwaitReply("wan validate handle=\(wanHandle!)")
      log("Api: Wan validation received", .debug, #function, #file, #line)
    }
    // bind UDP
    let ports = Udp.shared.bind(selection.packet.source == .smartlink,
                                selection.packet.publicIp,
                                selection.packet.requiresHolePunch,
                                selection.packet.negotiatedHolePunchPort,
                                selection.packet.publicUdpPort)
    
    guard ports != nil else { Tcp.shared.disconnect() ; throw ConnectionError.udpBind }
    log("Api: UDP bound, receive port = \(ports!.0), send port = \(ports!.1)", .debug, #function, #file, #line)

    // is this a Wan connection?
    if selection.packet.source == .smartlink {
      // send Wan Register (no reply)
      Udp.shared.send( "client udp_register handle=" + radio!.connectionHandle!.hex )
      log("Api: UDP registration sent", .debug, #function, #file, #line)
      
      // send Client Ip & wait for the reply
      let reply = try await radio!.sendAwaitReply("client ip")
      log("Api: Client ip = \(reply)", .debug, #function, #file, #line)
    }

    // send the initial commands
    radio!.sendInitialCommands()
    log("Api: initial commands sent", .info, #function, #file, #line)

    radio!.startPinging()
    log("Api: pinging \(selection.packet.publicIp)", .info, #function, #file, #line)

    // set the UDP port for a Local connection
    if selection.packet.source == .local {
      radio!.send("client udpport " + "\(Udp.shared.sendPort)")
      log("Api: Client Udp port set to \(Udp.shared.sendPort)", .info, #function, #file, #line)
    }
    
    activePacket = currentPacket
  }
  
  public func resetClientInitialized() {
    clientInitialized = false
  }
  
  /// Disconnect the current Radio and remove all its objects / references
  /// - Parameter reason: an optional reason
  public func disconnect(_ reason: String? = nil) {
    log("Api: Disconnect, \((reason == nil ? "User initiated" : reason!))", reason == nil ? .debug : .warning, #function, #file, #line)

    radio?.clientInitialized = false
    
    // stop pinging (if active)
    radio?.stopPinging()
    log("Api: Pinging STOPPED", .debug, #function, #file, #line)

    radio?.nickname = ""
    radio?.smartSdrMB = ""
    radio?.psocMbtrxVersion = ""
    radio?.psocMbPa100Version = ""
    radio?.fpgaMbVersion = ""
    
    // clear lists
    radio?.antennaList.removeAll()
    radio?.micList.removeAll()
    radio?.rfGainList.removeAll()
    radio?.sliceList.removeAll()
    
    radio?.connectionHandle = nil

    // stop udp
    Udp.shared.unbind()
    log("Api: Disconnect, UDP unbound", .debug, #function, #file, #line)

//    streamModel.unSubscribeToStreams()
    
    Tcp.shared.disconnect()

    // remove all of radio's objects
    removeAllObjects()
    log("Api: Disconnect, Objects removed", .debug, #function, #file, #line)
  }

  /// Determine if status is for this client
  /// - Parameters:
  ///   - properties:     a KeyValuesArray
  ///   - clientHandle:   the handle of ???
  /// - Returns:          true if a mtch
  func isForThisClient(_ properties: KeyValuesArray) -> Bool {
    var clientHandle : Handle = 0
  
    if let connectionHandle = radio?.connectionHandle {      
      // find the handle property
      for property in properties.dropFirst(2) where property.key == "client_handle" {
        clientHandle = property.value.handle ?? 0
      }
      return clientHandle == connectionHandle
    }
    return false
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods (Parse)
  
  func parse(_ type: ObjectType, _ statusMessage: String) async {
    
    switch type {
    case .amplifier:            amplifierStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .atu:                  atu.parse( Array(statusMessage.keyValuesArray().dropFirst(1) ))
    case .bandSetting:          bandSettingStatus(Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(Shared.kRemoved))
    case .client:               preProcessClient(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kDisconnected))
    case .cwx:                  cwx.parse( Array(statusMessage.keyValuesArray().dropFirst(1) ))
    case .display:              preProcessDisplay(statusMessage)
    case .equalizer:            equalizerStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .gps:                  gps.parse( Array(statusMessage.keyValuesArray(delimiter: "#").dropFirst(1)) )
    case .interlock:            preProcessInterlock(statusMessage)
    case .memory:               memoryStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .meter:                meterStatus(statusMessage.keyValuesArray(delimiter: "#"), !statusMessage.contains(Shared.kRemoved))
    case .profile:              profileStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse), statusMessage)
    case .radio:                radio?.parse(statusMessage.keyValuesArray())
    case .slice:                sliceStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse))
    case .stream:               streamModel.preProcessStream(statusMessage)
    case .tnf:                  tnfStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .transmit:             preProcessTransmit(statusMessage)
    case .usbCable:             usbCableStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .wan:                  wan.parse( Array(statusMessage.keyValuesArray().dropFirst(1)) )
    case .waveform:             waveform.parse( Array(statusMessage.keyValuesArray(delimiter: "=").dropFirst(1)) )
    case .xvtr:                 xvtrStatus(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse))
      
    case .panadapter, .waterfall: break                                                   // handled by "display"
    case .daxIqStream, .daxMicAudioStream, .daxRxAudioStream, .daxTxAudioStream:  break   // handled by "stream"
    case .remoteRxAudioStream, .remoteTxAudioStream:  break                               // handled by "stream"
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods (ReplyHandler)
  
  public func addReplyHandler(_ seqNumber: UInt, replyTuple: ReplyTuple) {
    self.replyHandlers[seqNumber] = replyTuple
  }
  
  public func removeReplyHandler(_ seqNumber: UInt) {
    self.replyHandlers[seqNumber] = nil
  }
  
  public func setActiveStation(_ station: String?) {
    self.activeStation = station
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods (Misc)
  
  /// Remove all Radio objects
  func removeAllObjects() {
    
    // FIXME: these may not be necessary
    radio = nil
    activeEqualizer = nil
    activeSlice = nil
    activeStation = nil
    activePacket = nil
    activePanadapter = nil
    log("ApiModel: removed Model properties", .debug, #function, #file, #line)

    removeAll(of: .amplifier)
    removeAll(of: .bandSetting)
    removeAll(of: .daxIqStream)
    removeAll(of: .daxMicAudioStream)
    removeAll(of: .daxRxAudioStream)
    removeAll(of: .daxTxAudioStream)
    removeAll(of: .equalizer)
    removeAll(of: .memory)
    removeAll(of: .meter)
    removeAll(of: .panadapter)
    removeAll(of: .profile)
    removeAll(of: .remoteRxAudioStream)
    removeAll(of: .remoteTxAudioStream)
    removeAll(of: .slice)
    removeAll(of: .tnf)
    removeAll(of: .usbCable)
    removeAll(of: .waterfall)
    removeAll(of: .xvtr)
    
    replyHandlers.removeAll()
    log("ApiModel: removed all reply handlers", .debug, #function, #file, #line)
    
  }
  
  func removeAll(of type: ObjectType) {
    switch type {
    case .amplifier:            amplifiers.removeAll()
    case .bandSetting:          bandSettings.removeAll()
    case .daxIqStream:          streamModel.daxIqStreams.removeAll()
    case .daxMicAudioStream:    streamModel.daxMicAudioStreams.removeAll()
    case .daxRxAudioStream:     streamModel.daxRxAudioStreams.removeAll()
    case .daxTxAudioStream:     streamModel.daxTxAudioStreams.removeAll()
    case .equalizer:            equalizers.removeAll()
    case .memory:               memories.removeAll()
    case .meter:                meters.removeAll()
    case .panadapter:
      panadapters.removeAll()
      streamModel.panadapterStreams.removeAll()
    case .profile:              profiles.removeAll()
    case .remoteRxAudioStream:  streamModel.remoteRxAudioStreams.removeAll()
    case .remoteTxAudioStream:  streamModel.remoteTxAudioStreams.removeAll()
    case .slice:                slices.removeAll()
    case .tnf:                  tnfs.removeAll()
    case .usbCable:             usbCables.removeAll()
    case .waterfall:
      waterfalls.removeAll()
      streamModel.waterfallStreams.removeAll()
    case .xvtr:                 xvtrs.removeAll()
    default:            break
    }
    log("ApiModel: removed all \(type.rawValue) objects", .debug, #function, #file, #line)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods (Object Status)
  
  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
  private func amplifierStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.objectId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if amplifiers[id: id] == nil { amplifiers.append( Amplifier(id) ) }
        // parse the properties
        amplifiers[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        amplifiers.remove(id: id)
        log("Amplifier \(id.hex): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func bandSettingStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.objectId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if bandSettings[id: id] == nil { bandSettings.append( BandSetting(id) ) }
        // parse the properties
        bandSettings[id: id]!.parse( Array(properties.dropFirst(1)) )
      } else {
        // NO, remove it
        bandSettings.remove(id: id)
        log("BandSetting \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func equalizerStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    let id = properties[0].key
    if id == "tx" || id == "rx" { return } // legacy equalizer ids, ignore
    // is it in use?
    if inUse {
      // YES, add it if not already present
      if equalizers[id: id] == nil { equalizers.append( Equalizer(id) ) }
      // parse the properties
      equalizers[id: id]!.parse( Array(properties.dropFirst(1)) )

    } else {
      // NO, remove it
      equalizers.remove(id: id)
      log("Equalizer \(id): REMOVED", .debug, #function, #file, #line)
    }
  }

  private func memoryStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.objectId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if memories[id: id] == nil { memories.append( Memory(id) ) }
        // parse the properties
        memories[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        memories.remove(id: id)
        log("Memory \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func meterStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = UInt32(properties[0].key.components(separatedBy: ".")[0], radix: 10) {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if meters[id: id] == nil { meters.append( Meter(id) ) }
        // parse the properties
        meters[id: id]!.parse( properties )
        
      } else {
        // NO, remove it
        meters.remove(id: id)
        log("Meter \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func panadapterStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.streamId {
      // is it in use?
      if inUse {
        // parse the properties
        // YES, add it if not already present
        if panadapters[id: id] == nil {
          panadapters.append( Panadapter(id) )
          streamModel.panadapterStreams.append( PanadapterStream(id) )
        }
        panadapters[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        panadapters.remove(id: id)
        streamModel.panadapterStreams.remove(id: id)
        log("Panadapter \(id.hex): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func profileStatus(_ properties: KeyValuesArray, _ inUse: Bool, _ statusMessage: String) {
    // get the id
    let id = properties[0].key
    // is it in use?
    if inUse {
      // YES, add it if not already present
      if profiles[id: id] == nil { profiles.append( Profile(id) ) }
      // parse the properties
      profiles[id: id]!.parse( statusMessage )
      
    } else {
      // NO, remove it
      profiles.remove(id: id)
      log("Profile \(id): REMOVED", .debug, #function, #file, #line)
    }
  }

  private func sliceStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.objectId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if slices[id: id] == nil { slices.append( Slice(id) ) }
        // parse the properties
        slices[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        slices.remove(id: id)
        log("Slice \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func tnfStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = UInt32(properties[0].key, radix: 10) {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if tnfs[id: id] == nil { tnfs.append( Tnf(id) ) }
        // parse the properties
        tnfs[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        tnfs.remove(id: id)
        log("Tnf \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  private func usbCableStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    let id = properties[0].key
    // is it in use?
    if inUse {
      // YES, add it if not already present
      if usbCables[id: id] == nil { usbCables.append( UsbCable(id) ) }
      // parse the properties
      usbCables[id: id]!.parse( Array(properties.dropFirst(1)) )

    } else {
      // NO, remove it
      usbCables.remove(id: id)
      log("USBCable \(id): REMOVED", .debug, #function, #file, #line)
    }
  }

  private func waterfallStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[0].key.streamId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if waterfalls[id: id] == nil { waterfalls.append( Waterfall(id) ) }
        // parse the properties
        waterfalls[id: id]!.parse( Array(properties.dropFirst(1)) )
        streamModel.waterfallStreams.append( WaterfallStream(id) )
        
      } else {
        // NO, remove it
        waterfalls.remove(id: id)
        streamModel.waterfallStreams.remove(id: id)
        log("Waterfall \(id.hex): REMOVED", .info, #function, #file, #line)
      }
    }
  }

  private func xvtrStatus(_ properties: KeyValuesArray, _ inUse: Bool) {
    // get the id
    if let id = properties[1].key.streamId {
      // is it in use?
      if inUse {
        // YES, add it if not already present
        if xvtrs[id: id] == nil { xvtrs.append( Xvtr(id) ) }
        // parse the properties
        xvtrs[id: id]!.parse( Array(properties.dropFirst(1)) )
        
      } else {
        // NO, remove it
        xvtrs.remove(id: id)
        log("Xvtr \(id): REMOVED", .debug, #function, #file, #line)
      }
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods (Pre-Process)
  
  private func preProcessClient(_ properties: KeyValuesArray, _ inUse: Bool = true) {
    // is there a valid handle"
    if let handle = properties[0].key.handle {
      switch properties[1].key {
        
      case Shared.kConnected:       parseConnection(properties: properties, handle: handle)
      case Shared.kDisconnected:    parseDisconnection(properties: properties, handle: handle)
      default:                      break
      }
    }
  }
  
  private func preProcessDisplay(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Waterfall or Panadapter?
    switch properties[0].key {
    case ObjectType.panadapter.rawValue:  panadapterStatus(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    case ObjectType.waterfall.rawValue:   waterfallStatus(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    default: break
    }
  }
  
  private func preProcessInterlock(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Interlock?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   bandSettingStatus(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    default:                                interlock.parse(properties) ; interlockStateChange(interlock.state)
    }
  }
    
  private func preProcessTransmit(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Transmit?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   bandSettingStatus(Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(Shared.kRemoved))
    default:                                transmit.parse( Array(properties.dropFirst() ))
    }
  }
  
  /// Process the Vita struct containing Meter data
  /// - Parameters:
  ///   - vita:        a Vita struct
  public func meterVitaProcessor(_ vita: Vita) {
    let kDbDbmDbfsSwrDenom: Float = 128.0   // denominator for Db, Dbm, Dbfs, Swr
    let kDegDenom: Float = 64.0             // denominator for Degc, Degf
    
    var meterIds = [UInt32]()
    meterStreamId = vita.streamId

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
          if let meter = meters[id: id] {
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
              meters[id: id]?.value = value
            }
          }
        }
      }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods (Helper)
  
  /// Parse a client connect status message
  /// - Parameters:
  ///   - properties: message properties as a KeyValuesArray
  ///   - handle: the radio's connection handle
  private func parseConnection(properties: KeyValuesArray, handle: Handle) {
    var clientId = ""
    var program = ""
    var station = ""
    var isLocalPtt = false
    
    enum Property: String {
      case clientId = "client_id"
      case localPttEnabled = "local_ptt"
      case program
      case station
    }
    
    // if handle is mine, this client is fully initialized
    if handle == radio?.connectionHandle { clientInitialized = true }
    
    // parse remaining properties
    for property in properties.dropFirst(2) {
      
      // check for unknown properties
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore this Key
        log("ApiModel: unknown client property, \(property.key)=\(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known properties, in alphabetical order
      switch token {
        
      case .clientId:         clientId = property.value
      case .localPttEnabled:  isLocalPtt = property.value.bValue
      case .program:          program = property.value.trimmingCharacters(in: .whitespaces)
      case .station:          station = property.value.replacingOccurrences(of: "\u{007f}", with: "").trimmingCharacters(in: .whitespaces)
      }
    }
    
    // is this GuiClient already in GuiClients?
    if let guiClient = Listener.shared.guiClients[id: handle] {
      
      // are all fields populated?
      if clientId.isEmpty || program.isEmpty || station.isEmpty {
        return
      }
      //      else {
      //        print("-----> NOT EMPTY", clientId, program, station)
      //      }
      
      // are all fields the same as previous?
      if clientId == guiClient.clientId ?? "" && program == guiClient.program && station == guiClient.station {
        return
      }
      //      else {
      //        print("-----> NOT SAME", "\(clientId) <-> \(guiClient.clientId ?? ""), \(program) <-> \(guiClient.program), \(station) <-> \(guiClient.station)")
      //      }
      
      // YES, update it
//      Task(priority: .low) {
//        await MainActor.run {
          Listener.shared.guiClients[id: handle]!.clientId = guiClient.clientId
          Listener.shared.guiClients[id: handle]!.program = guiClient.program
          Listener.shared.guiClients[id: handle]!.station = guiClient.station
          Listener.shared.guiClients[id: handle]!.isLocalPtt = guiClient.isLocalPtt
//        }
//      }
      
      // log the update if it changed
      log("ApiModel: guiClient UPDATED, \(handle.hex), \(station), \(program), \(clientId)", .info, #function, #file, #line)
      
      // log & notify if all essential properties are present
      Listener.shared.checkCompletion(Listener.shared.guiClients[id: handle]!)
      
    } else {
      let newGuiClient = GuiClient(handle: handle,
                                   station: station,
                                   program: program,
                                   clientId: clientId,
                                   isLocalPtt: isLocalPtt,
                                   isThisClient: handle == radio!.connectionHandle)
//      Task(priority: .low) {
//        await MainActor.run {
          // NO, add it
          Listener.shared.guiClients[id: handle] = newGuiClient
          
          // log the addition
          log("ApiModel: guiClient ADDED, \(newGuiClient.handle.hex), \(newGuiClient.station), \(newGuiClient.program), \(newGuiClient.clientId ?? "nil")", .info, #function, #file, #line)
          
          // log & notify if all essential properties are present
          Listener.shared.checkCompletion(Listener.shared.guiClients[id: handle]!)
//        }
//      }
    }
    
  }
  
  /// Parse a client disconnect status message
  /// - Parameters:
  ///   - properties: message properties as a KeyValuesArray
  ///   - handle: the radio's connection handle
  private func parseDisconnection(properties: KeyValuesArray, handle: Handle) {
    var reason = ""
    
    enum Property: String {
      case duplicateClientId        = "duplicate_client_id"
      case forced
      case wanValidationFailed      = "wan_validation_failed"
    }
    
    // is it me?
    if handle == radio?.connectionHandle {
      // YES, parse remaining properties
      for property in properties.dropFirst(2) {
        // check for unknown property
        guard let token = Property(rawValue: property.key) else {
          // log it and ignore this Key
          log("ApiModel: unknown client disconnection property, \(property.key)=\(property.value)", .warning, #function, #file, #line)
          continue
        }
        // Known properties, in alphabetical order
        switch token {
          
        case .duplicateClientId:    if property.value.bValue { reason = "Duplicate ClientId" }
        case .forced:               if property.value.bValue { reason = "Forced" }
        case .wanValidationFailed:  if property.value.bValue { reason = "Wan validation failed" }
        }
      }
      disconnect(reason)

    } else {
      // NO
      //      print("-----> Client disconnected, properties = \(properties), handle = \(handle.hex)")
    }
  }
  
  /// Change the MOX property when an Interlock state change occurs
  /// - Parameter state:            a new Interloack state
  private func interlockStateChange(_ state: String) {
    let currentMox = radio?.mox
    
    // if PTT_REQUESTED or TRANSMITTING
    if state == Interlock.States.pttRequested.rawValue || state == Interlock.States.transmitting.rawValue {
      // and mox not on, turn it on
      if currentMox == false { radio?.mox = true }
      
      // if READY or UNKEY_REQUESTED
    } else if state == Interlock.States.ready.rawValue || state == Interlock.States.unKeyRequested.rawValue {
      // and mox is on, turn it off
      if currentMox == true { radio?.mox = false  }
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods (subscriptions)

//  /// Close the stream
//  private func unSubscribeToStreams() {
//    log("Api: stream subscription CANCELLED", .debug, #function, #file, #line)
//    _streamSubscription?.cancel()
//  }

  /// Process the AsyncStream of inbound TCP messages
  private func subscribeToMessages()  {
    Task(priority: .low) {
      log("Api: TcpMessage subscription STARTED", .debug, #function, #file, #line)
      for await tcpMessage in Tcp.shared.inboundMessagesStream {
        radio?.tcpInbound(tcpMessage.text)
      }
      log("Api: TcpMessage subscription STOPPED", .debug, #function, #file, #line)
    }
  }
  
  /// Process the AsyncStream of TCP status changes
  private func subscribeToTcpStatus() {
    Task(priority: .low) {
      log("Api: TcpStatus subscription STARTED", .debug, #function, #file, #line)
      for await status in Tcp.shared.statusStream {
        radio?.tcpStatus(status)
      }
      log("Api: TcpStatus subscription STOPPED", .debug, #function, #file, #line)
    }
  }
  
  /// Process the AsyncStream of UDP status changes
  private func subscribeToUdpStatus() {
    Task(priority: .low) {
      log("Api: UdpStatus subscription STARTED", .debug, #function, #file, #line)
      for await status in Udp.shared.statusStream {
        radio?.udpStatus(status)
      }
      log("Api: UdpStatus subscription STOPPED", .debug, #function, #file, #line)
    }
  }
}
