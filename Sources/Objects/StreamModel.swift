//
//  StreamModel.swift
//  
//
//  Created by Douglas Adams on 9/18/22.
//

import Foundation
import ComposableArchitecture
import SwiftUI

import Shared
import Udp

public class VitaStatus: Identifiable, ObservableObject {
  @Published public var type: Vita.PacketClassCodes
  @Published public var packets = 0
  @Published public var errors = 0
  
  public var id: Vita.PacketClassCodes { type }
  
  public init(_ type: Vita.PacketClassCodes)
  {
    self.type = type
  }
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
// MARK: - Dependency decalarations

extension StreamModel: DependencyKey {
  public static let liveValue = StreamModel()
}

extension DependencyValues {
  public var streamModel: StreamModel {
    get { self[StreamModel.self] }
    set { self[StreamModel.self] = newValue }
  }
}

public final class StreamModel: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (Singleton)
  
//  public static var shared = StreamModel()
  public init() {
    streamStatus[id: Vita.PacketClassCodes.daxIq24] = VitaStatus(Vita.PacketClassCodes.daxIq24)
    streamStatus[id: Vita.PacketClassCodes.daxIq48] = VitaStatus(Vita.PacketClassCodes.daxIq48)
    streamStatus[id: Vita.PacketClassCodes.daxIq96] = VitaStatus(Vita.PacketClassCodes.daxIq96)
    streamStatus[id: Vita.PacketClassCodes.daxIq192] = VitaStatus(Vita.PacketClassCodes.daxIq192)
    streamStatus[id: Vita.PacketClassCodes.daxAudio] = VitaStatus(Vita.PacketClassCodes.daxAudio)
    streamStatus[id: Vita.PacketClassCodes.daxReducedBw] = VitaStatus(Vita.PacketClassCodes.daxReducedBw)
    streamStatus[id: Vita.PacketClassCodes.meter] = VitaStatus(Vita.PacketClassCodes.meter)
    streamStatus[id: Vita.PacketClassCodes.opus] = VitaStatus(Vita.PacketClassCodes.opus)
    streamStatus[id: Vita.PacketClassCodes.panadapter] = VitaStatus(Vita.PacketClassCodes.panadapter)
    streamStatus[id: Vita.PacketClassCodes.waterfall] = VitaStatus(Vita.PacketClassCodes.waterfall)
    
    subscribeToStreams()
  }
  
  @Dependency(\.apiModel) var apiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  @Published public var streamStatus = IdentifiedArrayOf<VitaStatus>()
  
  @Published public var daxIqStreams = IdentifiedArrayOf<DaxIqStream>()
  @Published public var daxRxAudioStreams = IdentifiedArrayOf<DaxRxAudioStream>()
  @Published public var daxTxAudioStreams = IdentifiedArrayOf<DaxTxAudioStream>()
  @Published public var daxMicAudioStreams = IdentifiedArrayOf<DaxMicAudioStream>()
  @Published public var panadapterStreams = IdentifiedArrayOf<PanadapterStream>()
  @Published public var remoteRxAudioStreams = IdentifiedArrayOf<RemoteRxAudioStream>()
  @Published public var remoteTxAudioStreams = IdentifiedArrayOf<RemoteTxAudioStream>()
  @Published public var waterfallStreams = IdentifiedArrayOf<WaterfallStream>()
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _streamSubscription: Task<(), Never>? = nil
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Close the stream
  public func unSubscribeToStreams() {
    log("Api: stream subscription CANCELLED", .debug, #function, #file, #line)
    _streamSubscription?.cancel()
  }

  /// Remove a RemoteRxAudioStream
  /// - Parameter handle: a Client Handle
  public func removeRemoteRxAudioStream(_ handle: Handle?) {
    if let handle {
      for stream in remoteRxAudioStreams where stream.clientHandle == handle {
        remoteRxAudioStreams[id: stream.id]?.setDelegate(nil)
        sendRemoveStream(id: stream.id)
      }
    }
  }
  
  /// Remove a RemoteTxAudioStream
  /// - Parameter handle: a Client Handle
  public func removeRemoteTxAudioStream(_ handle: Handle?) {
    if let handle {
      for stream in remoteTxAudioStreams where stream.clientHandle == handle {
        sendRemoveStream(id: stream.id)
      }
    }
  }
  
  public func preProcessStream(_ statusMessage: String) {
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
        if daxIqStreams[id: id] != nil {
          daxIqStreams.remove(id: id)
          log("DaxIqStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if daxMicAudioStreams[id: id] != nil {
          daxMicAudioStreams.remove(id: id)
          log("DaxMicAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if daxRxAudioStreams[id: id] != nil {
          daxRxAudioStreams.remove(id: id)
          log("DaxRxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if daxTxAudioStreams[id: id] != nil {
          daxTxAudioStreams.remove(id: id)
          log("DaxTxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if remoteRxAudioStreams[id: id] != nil {
          remoteRxAudioStreams.remove(id: id)
          log("RemoteRxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
          
        } else if remoteTxAudioStreams[id: id] != nil {
          remoteTxAudioStreams.remove(id: id)
          log("RemoteTxAudioStream \(id.hex): REMOVED", .debug, #function, #file, #line)
        }
        
      } else {
        Task {
          // NORMAL STATUS, is it for me?
          if await apiModel.isForThisClient(properties) {
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
              
            case .daxIq:      daxIqStreamStatus(properties)
            case .daxMic:     daxMicAudioStreamStatus(properties)
            case .daxRx:      daxRxAudioStreamStatus(properties)
            case .daxTx:      daxTxAudioStreamStatus(properties)
            case .remoteRx:   remoteRxAudioStreamStatus(properties)
            case .remoteTx:   remoteTxAudioStreamStatus(properties)
            }
          }
        }
      }
    } else {
      log("ApiModel: invalid Stream message: \(statusMessage)", .warning, #function, #file, #line)
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Tell the Radio to remove a stream
  /// - Parameter id: a streamId
  func sendRemoveStream(id: StreamId) {
    // tell the Radio to remove the stream
    Task {
      await apiModel.radio?.send("stream remove \(id.hex)")
    }
  }

  /// Determine if status is for this client
  /// - Parameters:
  ///   - properties:     a KeyValuesArray
  ///   - clientHandle:   the handle of ???
  /// - Returns:          true if a mtch
//  func isForThisClient(_ properties: KeyValuesArray) -> Bool {
//    var clientHandle : Handle = 0
//
//    guard connectionHandle != nil else { return false }
//
//    // FIXME: probably not needed
//    // allow a Tester app to see all Streams
////    guard _testerMode == false else { return true }
//
//    // find the handle property
//    for property in properties.dropFirst(2) where property.key == "client_handle" {
//      clientHandle = property.value.handle ?? 0
//    }
//    return clientHandle == connectionHandle
//  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods (streams)

  private func streamHandler(_ vita: Vita) {
    Task {
      await MainActor.run { streamStatus[id: vita.classCode]?.packets += 1 }
    }
    switch vita.classCode {
    case .panadapter:
      if let object = panadapterStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .waterfall:
      if let object = waterfallStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
      if let object = daxIqStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxAudio:
      if let object = daxRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita)}
      if let object = daxMicAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      if let object = remoteRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxReducedBw:
      if let object = daxRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      if let object = daxMicAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .meter:
      Task {
        await MainActor.run { apiModel.meterVitaProcessor(vita) }
      }
      
    case .opus:
      if let object = remoteRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    default:
      // log the error
      log("Api: unknown Vita class code: \(vita.classCode.description()) Stream Id = \(vita.streamId.hex)", .error, #function, #file, #line)
    }
  }

  /// Process the AsyncStream of UDP streams
  private func subscribeToStreams()  {
    _streamSubscription = Task(priority: .high) {
      log("Api: UDP stream subscription STARTED", .debug, #function, #file, #line)
      for await vita in Udp.shared.inboundStreams {
        streamHandler(vita)
      }
      log("Api: UDP stream  subscription STOPPED", .debug, #function, #file, #line)
    }
  }

  

  
  

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
  private func daxIqStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if daxIqStreams[id: id] == nil { daxIqStreams.append( DaxIqStream(id) ) }
      // parse the properties
      daxIqStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
    }
  }

  private func daxMicAudioStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if daxMicAudioStreams[id: id] == nil { daxMicAudioStreams.append( DaxMicAudioStream(id) ) }
      // parse the properties
      daxMicAudioStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
    }
  }

  private func daxTxAudioStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if daxTxAudioStreams[id: id] == nil { daxTxAudioStreams.append( DaxTxAudioStream(id) ) }
      // parse the properties
      daxTxAudioStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
    }
  }

  private func daxRxAudioStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if daxRxAudioStreams[id: id] == nil { daxRxAudioStreams.append( DaxRxAudioStream(id) ) }
      // parse the properties
      daxRxAudioStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
    }
  }

  private func remoteRxAudioStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if remoteRxAudioStreams[id: id] == nil { remoteRxAudioStreams.append( RemoteRxAudioStream(id) ) }
      // parse the properties
      remoteRxAudioStreams[id: id]!.parse( Array(properties.dropFirst(2)) )
    }
  }

  private func remoteTxAudioStreamStatus(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if remoteTxAudioStreams[id: id] == nil { remoteTxAudioStreams.append( RemoteTxAudioStream(id) ) }
      // parse the properties
      remoteTxAudioStreams[id: id]!.parse( Array(properties.dropFirst(2)) )
    }
  }

  
  
  
  
  
  /*
   "stream set 0x" + _streamId.ToString("X") + " daxiq_rate=" + _sampleRate
   "stream remove 0x" + _streamId.ToString("X")
   "stream set 0x" + _txStreamID.ToString("X") + " tx=" + Convert.ToByte(_transmit)
   "stream create type=dax_rx dax_channel=" + channel
   "stream create type=dax_mic"
   "stream create type=dax_tx"
   "stream create type=dax_iq daxiq_channel=" + channel
   "stream create type=remote_audio_rx"
   "stream create type=remote_audio_rx compression=opus"
   "stream create type=remote_audio_rx compression=none"
   "stream create type=remote_audio_tx"
   */
}
