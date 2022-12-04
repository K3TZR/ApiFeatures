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

// ----------------------------------------------------------------------------
// MARK: - Dependency decalarations

extension StreamModel: DependencyKey {
  public static let liveValue = StreamModel.shared
}

extension DependencyValues {
  var streamModel: StreamModel {
    get { self[StreamModel.self] }
    set { self[StreamModel.self] = newValue }
  }
}

public final class StreamModel: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (Singleton)
  
  public static var shared = StreamModel()
  private init() {
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
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  /// Tell the Radio to remove a stream
  /// - Parameter id: a streamId
  func sendRemoveStream(id: StreamId) {
    // tell the Radio to remove the stream
    Task {
      await ApiModel.shared.radio?.send("stream remove \(id.hex)")
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Private methods (streams)

  private func streamHandler(_ vita: Vita) {
    Task {
      await MainActor.run { streamStatus[id: vita.classCode]?.packets += 1 }
    }
    switch vita.classCode {
    case .panadapter:
      if let object = StreamModel.shared.panadapterStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .waterfall:
      if let object = StreamModel.shared.waterfallStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxIq24, .daxIq48, .daxIq96, .daxIq192:
      if let object = StreamModel.shared.daxIqStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxAudio:
      if let object = StreamModel.shared.daxRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita)}
      if let object = StreamModel.shared.daxMicAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      if let object = StreamModel.shared.remoteRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .daxReducedBw:
      if let object = StreamModel.shared.daxRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      if let object = StreamModel.shared.daxMicAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
    case .meter:
      Task {
        await Meter.vitaProcessor(vita)
      }
      
    case .opus:
      if let object = StreamModel.shared.remoteRxAudioStreams[id: vita.streamId] { object.vitaProcessor(vita) }
      
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
