//
//  UdpStream.swift
//  Api6000Components/UdpStreams
//
//  Created by Douglas Adams on 8/15/15.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

import Shared

// ----------------------------------------------------------------------------
// MARK: - Public structs and enums

public enum UdpStatusType {
  case didUnBind
  case failedToBind
  case readError
}

public struct UdpStatus: Identifiable, Equatable {
  public static func == (lhs: UdpStatus, rhs: UdpStatus) -> Bool {
    lhs.id == rhs.id
  }

  public init(_ statusType: UdpStatusType, receivePort: UInt16, sendPort: UInt16, error: Error? = nil) {
    self.statusType = statusType
    self.receivePort = receivePort
    self.sendPort = sendPort
    self.error = error
  }

  public var id = UUID()
  public var statusType: UdpStatusType = .didUnBind
  public var receivePort: UInt16 = 0
  public var sendPort: UInt16 = 0
  public var error: Error?
}

///  UDP Stream Class implementation
///      manages all Udp communication with a Radio
public final class Udp: NSObject, GCDAsyncUdpSocketDelegate {
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  private var _inBoundStreams: (Vita) -> Void = { _ in }
  private var _statusStream: (UdpStatus) -> Void = { _ in }

  public var sendIp = ""
  public var sendPort: UInt16 = 4991 // default port number

  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  var _isRegistered = false
//  let _processQ = DispatchQueue(label: "Stream.processQ", qos: .userInteractive)
  var _socket: GCDAsyncUdpSocket!
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties

  private var _isBound = false
  private var _receivePort: UInt16 = 0
  private let _receiveQ = DispatchQueue(label: "UdpStream.ReceiveQ", qos: .userInteractive)
//  private let _registerQ = DispatchQueue(label: "UdpStream.RegisterQ")
  
  private let kMaxBindAttempts = 20
//  private let kPingCmd = "client ping handle"
//  private let kPingDelay: UInt32 = 50
//  private let kRegistrationDelay: UInt32 = 250_000 // (250 microseconds)
    
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (singleton)
  
  public static var shared = Udp()
  
  /// Initialize a Stream Manager
  /// - Parameters:
  ///   - receivePort: a port number
  private init(receivePort: UInt16 = 4991) {
    self._receivePort = receivePort
    
    super.init()
    
    // get an IPV4 socket
    _socket = GCDAsyncUdpSocket(delegate: self, delegateQueue: _receiveQ)
    _socket.setIPv4Enabled(true)
    _socket.setIPv6Enabled(false)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Bind to a UDP Port
  /// - Parameters:
  ///   - packet: a DiscoveredPacket
//  public func bind(_ packet: Packet) -> (UInt16, UInt16)? {
  public func bind(_ isWan: Bool, _ publicIp: String, _ requiresHolePunch: Bool, _ holePunchPort: Int, _ publicUdpPort: Int?) -> (UInt16, UInt16)? {
    var success               = false
    var portToUse             : UInt16 = 0
    var tries                 = kMaxBindAttempts
    
    // identify the port
    switch (isWan, requiresHolePunch) {
      
    case (true, true):        // isWan w/hole punch
      portToUse = UInt16(holePunchPort)
      sendPort = UInt16(holePunchPort)
      tries = 1  // isWan w/hole punch
      
    case (true, false):       // isWan
      portToUse = UInt16(publicUdpPort!)
      sendPort = UInt16(publicUdpPort!)
      
    default:                  // local
      portToUse = _receivePort
    }
    
    // Find a UDP port, scan from the default Port Number up looking for an available port
    for _ in 0..<tries {
      do {
        try _socket.bind(toPort: portToUse)
        success = true
        
      } catch {
        // try the next Port Number
        portToUse += 1
      }
      if success { break }
    }
    
    // was a port bound?
    if success {
      // YES, save the actual port & ip in use
      _receivePort = portToUse
      
      
      sendPort = portToUse
      
      
      sendIp = publicIp
      _isBound = true

      // a UDP bind has been established
      beginReceiving()
      
      return (_receivePort, sendPort)
    
    } else {
      return nil
    }
  }
  
  /// Begin receiving UDP data
  public func beginReceiving() {
    do {
      // Begin receiving
      try _socket.beginReceiving()
      
    } catch let error {
      // read error
      _statusStream( UdpStatus( .readError, receivePort: _receivePort, sendPort: sendPort, error: error ))
    }
  }
  
  /// Unbind from the UDP port
  public func unbind() {
    _isBound = false
    
    // tell the receive socket to close
    _socket.close()
    
    _isRegistered = false
    
    _statusStream( UdpStatus(.didUnBind, receivePort: _receivePort, sendPort: sendPort, error: nil ))
  }
  
  /// Send Data to the Radio using UDP on the current ip & port
  /// - Parameters:
  ///   - data:               a Data
  public func send(_ data: Data) {
    _socket.send(data, toHost: sendIp, port: sendPort, withTimeout: -1, tag: 0)
  }

  /// Send a command String (as Data) to the Radio using UDP on the current ip & port
  /// - Parameters:
  ///   - data:               a Data
  public func send(_ command: String) {
    if let data = command.data(using: String.Encoding.ascii, allowLossyConversion: false) {
      send(data)
    }
  }
  
  public func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
    if let vita = Vita.decode(from: data) {
      // TODO: Packet statistics - received, dropped
      
      // a VITA packet was received therefore registration was successful
      if _isRegistered == false {
        _isRegistered = true
        log("Udp: REGISTERED", .debug, #function, #file, #line)
      }
      // stream the received data
      _inBoundStreams( vita )
    }
  }

  public func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) {
    // FIXME:
  }
}

// ----------------------------------------------------------------------------
// MARK: - Stream definition extension

extension Udp {
  
  /// A stream of received UDP streams
  public var inboundStreams: AsyncStream<Vita> {
    AsyncStream { continuation in
      _inBoundStreams = { vita in
        continuation.yield(vita)
      }
      continuation.onTermination = { @Sendable _ in
      }
    }
  }
  
  /// A stream of UDP status changes
  public var statusStream: AsyncStream<UdpStatus> {
    AsyncStream { continuation in
      _statusStream = { status in
        continuation.yield(status)
      }
      continuation.onTermination = { @Sendable _ in
      }
    }
  }
}
