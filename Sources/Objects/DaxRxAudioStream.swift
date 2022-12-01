//
//  DaxRxAudioStream.swift
//  Api6000Components/Api6000/Objects
//
//  Created by Douglas Adams on 2/24/17.
//  Copyright © 2017 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation

import Shared

// DaxRxAudioStream
//      creates a DaxRxAudioStream instance to be used by a Client to support the
//      processing of a stream of Audio from the Radio to the client. DaxRxAudioStream
//      instances are added / removed by the incoming TCP messages. DaxRxAudioStream
//      instances periodically receive Audio in a UDP stream. They are collected
//      in the Model.daxRxAudioStreams collection.
public final class DaxRxAudioStream: Identifiable, Equatable, ObservableObject {
  // Equality
  public nonisolated static func == (lhs: DaxRxAudioStream, rhs: DaxRxAudioStream) -> Bool {
    lhs.id == rhs.id
  }

  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: DaxRxAudioStreamId) { self.id = id }
  
  // ------------------------------------------------------------------------------
  // MARK: - Public properties
  
  public let id: DaxRxAudioStreamId
  public var initialized = false
  @Published public var isStreaming = false

  @Published public var clientHandle: Handle = 0
  @Published public var ip = ""
  @Published public var slice: Slice?
  @Published public var daxChannel = 0
  @Published public var rxGain = 0
  
  public var delegate: StreamHandler?
  public private(set) var rxLostPacketCount = 0

  public enum Property: String {
    case clientHandle   = "client_handle"
    case daxChannel     = "dax_channel"
    case ip
    case slice
    case type
  }
  
  // ------------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _rxPacketCount      = 0
  private var _rxLostPacketCount  = 0
  private var _rxSequenceNumber   = -1
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Static methods

  /// Evaluate a Status messaage
  /// - Parameters:
  ///   - properties: properties in KeyValuesArray form
  ///   - inUse: bool indicating status
  public static func status(_ properties: KeyValuesArray) {
    // get the id
    if let id = properties[0].key.streamId {
      // add it if not already present
      if StreamModel.shared.daxRxAudioStreams[id: id] == nil { StreamModel.shared.daxRxAudioStreams.append( DaxRxAudioStream(id) ) }
      // parse the properties
      StreamModel.shared.daxRxAudioStreams[id: id]!.parse( Array(properties.dropFirst(1)) )
    }
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public Instance methods
  
  /// Parse key/value pairs
  /// - Parameter properties:       a KeyValuesArray
  public func parse(_ properties: KeyValuesArray) {
    for property in properties {
      // check for unknown keys
      guard let token = Property(rawValue: property.key) else {
        // unknown, log it and ignore the Key
        log("DaxRxAudioStream \(id.hex): unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // known keys, in alphabetical order
      switch token {
        
      case .clientHandle: clientHandle = property.value.handle ?? 0
      case .daxChannel:   daxChannel = property.value.iValue
      case .ip:           ip = property.value
      case .type:         break  // included to inhibit unknown token warnings
      case .slice:        break  // FIXME: ?????
//        // do we have a good reference to the GUI Client?
//        if let handle = radio.findHandle(for: radio.boundClientId) {
//          // YES,
//          self.slice = radio.findSlice(letter: property.value, guiClientHandle: handle)
//          let gain = rxGain
//          rxGain = 0
//          rxGain = gain
//        } else {
//          // NO, clear the Slice reference and carry on
//          slice = nil
//          continue
//        }
      }
    }
    // is it initialized?
    if initialized == false && clientHandle != 0 {
      // NO, it is now
      initialized = true
      log("DaxRxAudioStream \(id.hex): ADDED, handle = \(clientHandle.hex)", .debug, #function, #file, #line)
    }
  }

  
  
  
  
  
  
  
  
  
  
  /// Set a property
  /// - Parameters:
  ///   - radio:      the current radio
  ///   - id:         a DaxRxAudioStream Id
  ///   - property:   a DaxRxAudioStream Token
  ///   - value:      the new value
  public static func setProperty(radio: Radio, _ id: DaxRxAudioStreamId, property: Property, value: Any) {
    // FIXME: add commands
  }

  
  /// Send a command to Set a DaxRxAudioStream property
  /// - Parameters:
  ///   - radio:      a Radio instance
  ///   - id:         the Id for the specified DaxRxAudioStream
  ///   - token:      the parse token
  ///   - value:      the new value
  private static func sendCommand(_ radio: Radio, _ id: DaxRxAudioStreamId, _ token: Property, _ value: Any) {
    // FIXME: add commands
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Process the DaxAudioStream Vita struct
  /// - Parameters:
  ///   - vita:       a Vita struct
  ///
  public func vitaProcessor(_ vita: Vita) {
    if isStreaming == false {
      isStreaming = true
      // log the start of the stream
      log("DaxRxAudio: stream STARTED, \(id.hex)", .info, #function, #file, #line)
    }
    // is this the first packet?
    if _rxSequenceNumber == -1 {
      _rxSequenceNumber = vita.sequence
      _rxPacketCount = 1
      _rxLostPacketCount = 0
    } else {
      _rxPacketCount += 1
    }
    
    switch (_rxSequenceNumber, vita.sequence) {
      
    case (let expected, let received) where received < expected:
      // from a previous group, ignore it
      log("DaxRxAudioStream, delayed frame(s) ignored: expected \(expected), received \(received)", .warning, #function, #file, #line)
      return
      
    case (let expected, let received) where received > expected:
      _rxLostPacketCount += 1
      
      // from a later group, jump forward
      let lossPercent = String(format: "%04.2f", (Float(_rxLostPacketCount)/Float(_rxPacketCount)) * 100.0 )
      log("DaxRxAudioStream, missing frame(s) skipped: expected \(expected), received \(received), loss = \(lossPercent) %", .warning, #function, #file, #line)
      
      _rxSequenceNumber = received
      fallthrough
      
    default:
      // received == expected
      // calculate the next Sequence Number
      _rxSequenceNumber = (_rxSequenceNumber + 1) % 16
      
      if vita.classCode == .daxReducedBw {
        delegate?.streamHandler( DaxRxReducedAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / 2, daxChannel: daxChannel) )
        
      } else {
        delegate?.streamHandler( DaxRxAudioFrame(payload: vita.payloadData, numberOfSamples: vita.payloadSize / (4 * 2), daxChannel: daxChannel) )
      }
    }
  }
}

/// Struct containing DaxRxAudioStream data
public struct DaxRxAudioFrame {
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var numberOfSamples  : Int
  public var daxChannel       : Int
  public var leftAudio        = [Float]()
  public var rightAudio       = [Float]()
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a DaxRxAudioFrame
  /// - Parameters:
  ///   - payload:            pointer to the Vita packet payload
  ///   - numberOfSamples:    number of Samples in the payload
  public init(payload: [UInt8], numberOfSamples: Int, daxChannel: Int = -1) {
    
    self.numberOfSamples = numberOfSamples
    self.daxChannel = daxChannel
    
    // allocate the samples arrays
    self.leftAudio = [Float](repeating: 0, count: numberOfSamples)
    self.rightAudio = [Float](repeating: 0, count: numberOfSamples)
    
    payload.withUnsafeBytes { (payloadPtr) in
      // 32-bit Float stereo samples
      // get a pointer to the data in the payload
      let wordsPtr = payloadPtr.bindMemory(to: UInt32.self)
      
      // allocate temporary data arrays
      var dataLeft = [UInt32](repeating: 0, count: numberOfSamples)
      var dataRight = [UInt32](repeating: 0, count: numberOfSamples)
      
      // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
      for i in 0..<numberOfSamples {
        dataLeft[i] = CFSwapInt32BigToHost(wordsPtr[2*i])
        dataRight[i] = CFSwapInt32BigToHost(wordsPtr[(2*i) + 1])
      }
      // copy the data as is -- it is already floating point
      memcpy(&leftAudio, &dataLeft, numberOfSamples * 4)
      memcpy(&rightAudio, &dataRight, numberOfSamples * 4)
    }
  }
}

/// Struct containing DaxRxAudioStream data (reduced BW)
public struct DaxRxReducedAudioFrame {
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var numberOfSamples  : Int
  public var daxChannel       : Int
  public var leftAudio        = [Float]()
  public var rightAudio       = [Float]()
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a DaxRxReducedAudioFrame
  /// - Parameters:
  ///   - payload:            pointer to the Vita packet payload
  ///   - numberOfSamples:    number of Samples in the payload
  public init(payload: [UInt8], numberOfSamples: Int, daxChannel: Int = -1) {
    let oneOverMax: Float = 1.0 / Float(Int16.max)
    
    self.numberOfSamples = numberOfSamples
    self.daxChannel = daxChannel
    
    // allocate the samples arrays
    self.leftAudio = [Float](repeating: 0, count: numberOfSamples)
    self.rightAudio = [Float](repeating: 0, count: numberOfSamples)
    
    payload.withUnsafeBytes { (payloadPtr) in
      // Int16 Mono Samples
      // get a pointer to the data in the payload
      let wordsPtr = payloadPtr.bindMemory(to: Int16.self)
      
      // allocate temporary data arrays
      var dataLeft = [Float](repeating: 0, count: numberOfSamples)
      var dataRight = [Float](repeating: 0, count: numberOfSamples)
      
      // Swap the byte ordering of the samples & place it in the dataFrame left and right samples
      for i in 0..<numberOfSamples {
        let uIntVal = CFSwapInt16BigToHost(UInt16(bitPattern: wordsPtr[i]))
        let intVal = Int16(bitPattern: uIntVal)
        
        let floatVal = Float(intVal) * oneOverMax
        
        dataLeft[i] = floatVal
        dataRight[i] = floatVal
      }
      // copy the data as is -- it is already floating point
      memcpy(&leftAudio, &dataLeft, numberOfSamples * 4)
      memcpy(&rightAudio, &dataRight, numberOfSamples * 4)
    }
  }
}


