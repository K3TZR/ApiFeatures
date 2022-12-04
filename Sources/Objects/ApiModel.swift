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

public enum ConnectionError: String, Error {
  case instantiation = "Failed to create Radio object"
  case connection = "Failed to connect to Radio"
  case replyError = "Reply with error"
  case tcpConnect = "Tcp Failed to connect"
  case udpBind = "Udp Failed to bind"
  case wanConnect = "WanConnect Failed"
  case wanValidation = "WanValidation Failed"
}

// ----------------------------------------------------------------------------
// MARK: - Dependency decalarations

extension ApiModel: DependencyKey {
  public static let liveValue = ApiModel.shared
}

extension DependencyValues {
  public var apiModel: ApiModel {
    get { self[ApiModel.self] }
    set { self[ApiModel.self] = newValue }
  }
}
@MainActor
public final class ApiModel: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (Singleton)
  
  public static var shared = ApiModel()
  private init() {
    subscribeToMessages()
    subscribeToTcpStatus()
    subscribeToUdpStatus()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
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
    
    await MainActor.run {
      ApiModel.shared.activePacket = selection.packet
      
      // Instantiate a Radio
      ApiModel.shared.radio = Radio(selection.packet,
                                     connectionType: isGui ? .gui : .nonGui,
                                     stationName: station,
                                     programName: program,
                                     disconnectHandle: disconnectHandle)
    }
    // connect to it
    guard ApiModel.shared.radio != nil else { throw ConnectionError.instantiation }
    log("Api: Radio instantiated for \(selection.packet.nickname), \(selection.packet.source == .smartlink ? "SMARTLINK" : "LOCAL")", .debug, #function, #file, #line)

    guard ApiModel.shared.radio!.connect(selection.packet) else { throw ConnectionError.connection }
    log("Api: Tcp connection established ", .debug, #function, #file, #line)

    if disconnectHandle != nil {
      // pending disconnect
      ApiModel.shared.radio!.send("client disconnect \(disconnectHandle!.hex)")
    }

    // wait for the first Status message with my handle
    await ApiModel.shared.radio!.awaitClientConnected(selection.packet.source)
    log("Api: First status message received", .debug, #function, #file, #line)

    // is this a Wan connection?
    if selection.packet.source == .smartlink {
      // YES, send Wan Connect message & wait for the reply
      wanHandle = try await Listener.shared.sendWanConnect(for: selection.packet.serial, holePunchPort: selection.packet.negotiatedHolePunchPort)
      // put the wanHandle into the packet
      ApiModel.shared.activePacket?.wanHandle = wanHandle!
      log("Api: wanHandle received", .debug, #function, #file, #line)

      // send Wan Validate & wait for the reply
      log("Api: Wan validate sent for handle=\(wanHandle!)", .debug, #function, #file, #line)
      _ = try await ApiModel.shared.radio!.sendAwaitReply("wan validate handle=\(wanHandle!)")
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
      Udp.shared.send( "client udp_register handle=" + ApiModel.shared.radio!.connectionHandle!.hex )
      log("Api: UDP registration sent", .debug, #function, #file, #line)
      
      // send Client Ip & wait for the reply
      let reply = try await ApiModel.shared.radio!.sendAwaitReply("client ip")
      log("Api: Client ip = \(reply)", .debug, #function, #file, #line)
    }

    // send the initial commands
    ApiModel.shared.radio!.sendInitialCommands()
    log("Api: initial commands sent", .info, #function, #file, #line)

    ApiModel.shared.radio!.startPinging()
    log("Api: pinging \(selection.packet.publicIp)", .info, #function, #file, #line)

    // set the UDP port for a Local connection
    if selection.packet.source == .local {
      ApiModel.shared.radio!.send("client udpport " + "\(Udp.shared.sendPort)")
      log("Api: Client Udp port set to \(Udp.shared.sendPort)", .info, #function, #file, #line)
    }
  }
  
  /// Disconnect the current Radio and remove all its objects / references
  /// - Parameter reason: an optional reason
  @MainActor public func disconnect(_ reason: String? = nil) {
    log("Api: Disconnect, \((reason == nil ? "User initiated" : reason!))", reason == nil ? .debug : .warning, #function, #file, #line)

    ApiModel.shared.radio?.clientInitialized = false
    
    // stop pinging (if active)
    ApiModel.shared.radio?.stopPinging()
    log("Api: Pinging STOPPED", .debug, #function, #file, #line)

    ApiModel.shared.radio?.nickname = ""
    ApiModel.shared.radio?.smartSdrMB = ""
    ApiModel.shared.radio?.psocMbtrxVersion = ""
    ApiModel.shared.radio?.psocMbPa100Version = ""
    ApiModel.shared.radio?.fpgaMbVersion = ""
    
    // clear lists
    ApiModel.shared.radio?.antennaList.removeAll()
    ApiModel.shared.radio?.micList.removeAll()
    ApiModel.shared.radio?.rfGainList.removeAll()
    ApiModel.shared.radio?.sliceList.removeAll()
    
    ApiModel.shared.radio?.connectionHandle = nil

    // stop udp
    Udp.shared.unbind()
    log("Api: Disconnect, UDP unbound", .debug, #function, #file, #line)

//    StreamModel.shared.unSubscribeToStreams()
    
    Tcp.shared.disconnect()

    // remove all of radio's objects
    ApiModel.shared.removeAllObjects()
    log("Api: Disconnect, Objects removed", .debug, #function, #file, #line)
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods (Parse)
  
  func parse(_ type: ObjectType, _ statusMessage: String) async {
    
    switch type {
    case .amplifier:            Amplifier.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .atu:                  Atu.shared.parse( Array(statusMessage.keyValuesArray().dropFirst(1) ))
    case .bandSetting:          BandSetting.status(Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(Shared.kRemoved))
    case .client:               preProcessClient(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kDisconnected))
    case .cwx:                  Cwx.shared.parse( Array(statusMessage.keyValuesArray().dropFirst(1) ))
    case .display:              preProcessDisplay(statusMessage)
    case .equalizer:            Equalizer.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .gps:                  Gps.shared.parse( Array(statusMessage.keyValuesArray(delimiter: "#").dropFirst(1)) )
    case .interlock:            preProcessInterlock(statusMessage)
    case .memory:               Memory.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .meter:                Meter.status(statusMessage.keyValuesArray(delimiter: "#"), !statusMessage.contains(Shared.kRemoved))
    case .profile:              Profile.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse), statusMessage)
    case .radio:                radio?.parse(statusMessage.keyValuesArray())
    case .slice:                Slice.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse))
    case .stream:               preProcessStream(statusMessage)
    case .tnf:                  Tnf.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .transmit:             preProcessTransmit(statusMessage)
    case .usbCable:             UsbCable.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kRemoved))
    case .wan:                  Wan.shared.parse( Array(statusMessage.keyValuesArray().dropFirst(1)) )
    case .waveform:             Waveform.shared.parse( Array(statusMessage.keyValuesArray(delimiter: "=").dropFirst(1)) )
    case .xvtr:                 Xvtr.status(statusMessage.keyValuesArray(), !statusMessage.contains(Shared.kNotInUse))
      
    case .panadapter, .waterfall: break                                                   // handled by "display"
    case .daxIqStream, .daxMicAudioStream, .daxRxAudioStream, .daxTxAudioStream:  break   // handled by "stream"
    case .remoteRxAudioStream, .remoteTxAudioStream:  break                               // handled by "stream"
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods (ReplyHandler)
  
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
    
    removeAll(of: .amplifier)
    removeAll(of: .bandSetting)
    removeAll(of: .daxIqStream)
    removeAll(of: .daxMicAudioStream)
    removeAll(of: .daxRxAudioStream)
    removeAll(of: .daxTxAudioStream)
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
    
    // FIXME: these may not be necessary
    ApiModel.shared.radio = nil
    ApiModel.shared.activeEqualizer = nil
    ApiModel.shared.activeSlice = nil
    ApiModel.shared.activeStation = nil
    ApiModel.shared.activePacket = nil
    ApiModel.shared.activePanadapter = nil
    log("ApiModel: removed Model properties", .debug, #function, #file, #line)
  }
  
  func removeAll(of type: ObjectType) {
    switch type {
    case .amplifier:            amplifiers.removeAll()
    case .bandSetting:          bandSettings.removeAll()
    case .daxIqStream:          StreamModel.shared.daxIqStreams.removeAll()
    case .daxMicAudioStream:    StreamModel.shared.daxMicAudioStreams.removeAll()
    case .daxRxAudioStream:     StreamModel.shared.daxRxAudioStreams.removeAll()
    case .daxTxAudioStream:     StreamModel.shared.daxTxAudioStreams.removeAll()
    case .memory:               memories.removeAll()
    case .meter:                ApiModel.shared.meters.removeAll()
    case .panadapter:
      panadapters.removeAll()
      StreamModel.shared.panadapterStreams.removeAll()
    case .profile:              profiles.removeAll()
    case .remoteRxAudioStream:  StreamModel.shared.remoteRxAudioStreams.removeAll()
    case .remoteTxAudioStream:  StreamModel.shared.remoteTxAudioStreams.removeAll()
    case .slice:                slices.removeAll()
    case .tnf:                  tnfs.removeAll()
    case .usbCable:             usbCables.removeAll()
    case .waterfall:
      waterfalls.removeAll()
      StreamModel.shared.waterfallStreams.removeAll()
    case .xvtr:                 xvtrs.removeAll()
    default:            break
    }
    log("ApiModel: removed all \(type.rawValue) objects", .debug, #function, #file, #line)
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
    case ObjectType.panadapter.rawValue:  Panadapter.status(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    case ObjectType.waterfall.rawValue:   Waterfall.status(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    default: break
    }
  }
  
  private func preProcessInterlock(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Interlock?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   BandSetting.status(Array(statusMessage.keyValuesArray().dropFirst()), !statusMessage.contains(Shared.kRemoved) )
    default:                                Interlock.shared.parse(properties) ; interlockStateChange(Interlock.shared.state)
    }
  }
  
  private func preProcessStream(_ statusMessage: String) {
    enum Property: String {
      case daxIq            = "dax_iq"
      case daxMic           = "dax_mic"
      case daxRx            = "dax_rx"
      case daxTx            = "dax_tx"
      case remoteRx         = "remote_audio_rx"
      case remoteTx         = "remote_audio_tx"
    }
    
    let properties = statusMessage.keyValuesArray()
    
    // is the 1st KeyValue a StreamId?
    if let id = properties[0].key.streamId {
      
      // is it a removal?
      if statusMessage.contains(Shared.kRemoved) {
        // REMOVAL, what type of stream?
        if StreamModel.shared.daxIqStreams[id: id] != nil {
          StreamModel.shared.daxIqStreams.remove(id: id)
          log("DaxIqStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if StreamModel.shared.daxMicAudioStreams[id: id] != nil {
          StreamModel.shared.daxMicAudioStreams.remove(id: id)
          log("DaxMicAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if StreamModel.shared.daxRxAudioStreams[id: id] != nil {
          StreamModel.shared.daxRxAudioStreams.remove(id: id)
          log("DaxRxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if StreamModel.shared.daxTxAudioStreams[id: id] != nil {
          StreamModel.shared.daxTxAudioStreams.remove(id: id)
          log("DaxTxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if StreamModel.shared.remoteRxAudioStreams[id: id] != nil {
          StreamModel.shared.remoteRxAudioStreams.remove(id: id)
          log("RemoteRxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if StreamModel.shared.remoteTxAudioStreams[id: id] != nil {
          StreamModel.shared.remoteTxAudioStreams.remove(id: id)
          log("RemoteTxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
        }
        
      } else {
        // NORMAL STATUS, is it for me?
        if isForThisClient(properties, connectionHandle: radio?.connectionHandle) {
          // YES
          guard properties.count > 1 else {
            log("ApiModel: invalid Stream message: \(statusMessage)", .warning, #function, #file, #line)
            return
          }
          guard let token = Property(rawValue: properties[1].value) else {
            // log it and ignore the Key
            log("ApiModel: unknown Stream type: \(properties[1].value)", .warning, #function, #file, #line)
            return
          }
          switch token {
            
          case .daxIq:      DaxIqStream.status(properties)
          case .daxMic:     DaxMicAudioStream.status(properties)
          case .daxRx:      DaxRxAudioStream.status(properties)
          case .daxTx:      DaxTxAudioStream.status(properties)
          case .remoteRx:   RemoteRxAudioStream.status(properties)
          case .remoteTx:   RemoteTxAudioStream.status(properties)
          }
        }
      }
    } else {
      log("ApiModel: invalid Stream message: \(statusMessage)", .warning, #function, #file, #line)
    }
  }
  
  private func preProcessTransmit(_ statusMessage: String) {
    let properties = statusMessage.keyValuesArray()
    // Band Setting or Transmit?
    switch properties[0].key {
    case ObjectType.bandSetting.rawValue:   BandSetting.status(Array(statusMessage.keyValuesArray().dropFirst(1) ), !statusMessage.contains(Shared.kRemoved))
    default:                                Transmit.shared.parse( Array(properties.dropFirst() ))
    }
  }
  
  /// Determine if status is for this client
  /// - Parameters:
  ///   - properties:     a KeyValuesArray
  ///   - clientHandle:   the handle of ???
  /// - Returns:          true if a mtch
  func isForThisClient(_ properties: KeyValuesArray, connectionHandle: Handle?) -> Bool {
    var clientHandle : Handle = 0
    
    guard connectionHandle != nil else { return false }
    
    // FIXME: probably not needed
    // allow a Tester app to see all Streams
//    guard _testerMode == false else { return true }
    
    // find the handle property
    for property in properties.dropFirst(2) where property.key == "client_handle" {
      clientHandle = property.value.handle ?? 0
    }
    return clientHandle == connectionHandle
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
        ApiModel.shared.radio?.tcpInbound(tcpMessage.text)
      }
      log("Api: TcpMessage subscription STOPPED", .debug, #function, #file, #line)
    }
  }
  
  /// Process the AsyncStream of TCP status changes
  private func subscribeToTcpStatus() {
    Task(priority: .low) {
      log("Api: TcpStatus subscription STARTED", .debug, #function, #file, #line)
      for await status in Tcp.shared.statusStream {
        ApiModel.shared.radio?.tcpStatus(status)
      }
      log("Api: TcpStatus subscription STOPPED", .debug, #function, #file, #line)
    }
  }
  
  /// Process the AsyncStream of UDP status changes
  private func subscribeToUdpStatus() {
    Task(priority: .low) {
      log("Api: UdpStatus subscription STARTED", .debug, #function, #file, #line)
      for await status in Udp.shared.statusStream {
        ApiModel.shared.radio?.udpStatus(status)
      }
      log("Api: UdpStatus subscription STOPPED", .debug, #function, #file, #line)
    }
  }
}
