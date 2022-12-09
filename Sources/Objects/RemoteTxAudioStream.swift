//
//  RemoteTxAudioStream.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 2/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Foundation

import Shared
import Udp

// RemoteTxAudioStream
//      creates a RemoteTxAudioStream instance to be used by a Client to support the
//      processing of a stream of Audio to the Radio. RemoteTxAudioStream instances
//      are added / removed by the incoming TCP messages. RemoteTxAudioStream instances
//      periodically send Audio in a UDP stream. They are collected in the
//      Model.RemoteTxAudioStreams collection..
public final class RemoteTxAudioStream: Identifiable, Equatable, ObservableObject, AudioStreamHandler {
  // Equality
  public nonisolated static func == (lhs: RemoteTxAudioStream, rhs: RemoteTxAudioStream) -> Bool {
    lhs.id == rhs.id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: RemoteTxAudioStreamId) { self.id = id }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id : RemoteTxAudioStreamId
  public var initialized = false
  @Published public var isStreaming = false

  @Published public var clientHandle: Handle = 0
  @Published public var compression = ""
  @Published public var ip = ""
  
  public enum Property: String {
    case clientHandle = "client_handle"
    case compression
    case ip
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
//  public static func status(_ properties: KeyValuesArray) {
//    // get the id
//    if let id = properties[0].key.streamId {
//      // add it if not already present
//      if streamModel.remoteTxAudioStreams[id: id] == nil { streamModel.remoteTxAudioStreams.append( RemoteTxAudioStream(id) ) }
//      // parse the properties
//      streamModel.remoteTxAudioStreams[id: id]!.parse( Array(properties.dropFirst(2)) )
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods

  ///  Parse  key/value pairs
  /// - Parameter properties: a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    // process each key/value pair
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("RemoteTxAudioStream \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known Keys, in alphabetical order
      switch token {
        
        // Note: only supports "opus", not sure why the compression property exists (future?)
        
      case .clientHandle: clientHandle = property.value.handle ?? 0
      case .compression:  compression = property.value.lowercased()
      case .ip:           ip = property.value
      }
    }
    // is it initialized?
    if initialized == false && clientHandle != 0 {
      // NO, it is now
      initialized = true
      log("RemoteTxAudioStream \(id.hex): ADDED, handle = \(clientHandle.hex)", .debug, #function, #file, #line)
    }
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods

  private var _txSequenceNumber = 0
  private var _vita: Vita?
  

  /// Send Tx Audio to the Radio
  /// - Parameters:
  ///   - buffer:             array of encoded audio samples
  /// - Returns:              success / failure
  @MainActor public func sendAudio(buffer: [UInt8], samples: Int) {
    guard Interlock.shared.state == "TRANSMITTING" else { return }
    
    if isStreaming == false {
      isStreaming = true
      // log the start of the stream
      log("RemoteTxAudioStream \(id.hex): STARTED", .info, #function, #file, #line)
    }

    // FIXME: This assumes Opus encoded audio
    if compression == "opus" {
      // get an OpusTx Vita
      if _vita == nil { _vita = Vita(type: .opusTx, streamId: id) }
      
      // create new array for payload (interleaved L/R samples)
      _vita!.payloadData = buffer
      
      // set the length of the packet
      _vita!.payloadSize = samples                                              // 8-Bit encoded samples
      _vita!.packetSize = _vita!.payloadSize + MemoryLayout<VitaHeader>.size    // payload size + header size
      
      // set the sequence number
      _vita!.sequence = _txSequenceNumber
      
      // encode the Vita class as data and send to radio
      if let vitaData = Vita.encodeAsData(_vita!) { Udp.shared.send(vitaData) }
      
      // increment the sequence number (mod 16)
      _txSequenceNumber = (_txSequenceNumber + 1) % 16
      
    } else {
      log("RemoteTxAudioStream, compression != opus: frame ignored", .warning, #function, #file, #line)
    }
  }

  
  
  
  
  
  
  
  

  
  /// Send a command to Set a RemoteTxAudioStream property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified RemoteTxAudioStream
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: RemoteTxAudioStreamId, _ token: Property, _ value: Any) {
    // FIXME: add commands
  }
}

