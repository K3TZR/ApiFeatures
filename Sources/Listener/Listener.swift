//
//  Listener.swift
//  ApiFeatures/Listener
//
//  Created by Douglas Adams on 11/26/22.
//

import Foundation
import IdentifiedCollections

import SettingsModel
import SharedModel

public typealias IdToken = String

@Observable
final public class Listener: Equatable {
  public static func == (lhs: Listener, rhs: Listener) -> Bool {
    lhs === rhs
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public Properties
  
  public var packets = IdentifiedArrayOf<Packet>()
  public var stations = IdentifiedArrayOf<Station>()
  public var guiClients = IdentifiedArrayOf<GuiClient>()
  
  public var smartlinkTestResult = SmartlinkTestResult()
  
  public var clientStream: AsyncStream<ClientEvent> {
    AsyncStream { continuation in _clientStream = { clientEvent in continuation.yield(clientEvent) }
      continuation.onTermination = { @Sendable _ in } }}
  
  //  public var packetStream: AsyncStream<PacketEvent> {
  //    AsyncStream { continuation in _packetStream = { packetEvent in continuation.yield(packetEvent) }
  //      continuation.onTermination = { @Sendable _ in } }}
  
  public var statusStream: AsyncStream<WanStatus> {
    AsyncStream { continuation in _statusStream = { status in continuation.yield(status) }
      continuation.onTermination = { @Sendable _ in } }}
  
//  public var testStream: AsyncStream<SmartlinkTestResult> {
//    AsyncStream { continuation in _testStream = { testResult in continuation.yield(testResult) }
//      continuation.onTermination = { @Sendable _ in } }}
  
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _localListener: LocalListener?
  private var _smartlinkListener: SmartlinkListener?
  
  private var _clientStream: (ClientEvent) -> Void = { _ in }
  //  private var _packetStream: (PacketEvent) -> Void = { _ in }
  var _statusStream: (WanStatus) -> Void = { _ in }
//  var _testStream: (SmartlinkTestResult) -> Void = { _ in }
  
  private let _formatter = DateFormatter()
  private let _settingsModel = SettingsModel.shared
  
  private enum UpdateStatus {
    case newPacket
    case timestampOnly
    case changedPacket
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (singleton)
  
  public static var shared = Listener()
  private init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func localMode(_ enable: Bool) {
    _localListener?.stop()
    _localListener = nil
    
    if enable {
      _localListener = LocalListener(self)
      _localListener!.start()
    } else {
      removePackets(condition: {$0.source == .local})
    }
  }
  
  public func smartlinkMode(_ enable: Bool, _ smartlinkUser: String = "", _ requireSmartlinkLogin: Bool = false) async -> Bool {
    _smartlinkListener?.stop()
    _smartlinkListener = nil
    
    if enable {
      _smartlinkListener = SmartlinkListener(self)
      if await _smartlinkListener!.start(smartlinkUser, requireSmartlinkLogin) == false {
        _smartlinkListener = nil
        return false
      }
      return true
    } else {
      removePackets(condition: {$0.source == .smartlink})
    }
    return true
  }
  
  public func startWan(_ user: String, _ pwd: String) async -> Bool {
    _smartlinkListener = SmartlinkListener(self)
    let status = await _smartlinkListener!.start(user: user, pwd: pwd)
    if status == false { _smartlinkListener = nil }
    return status
  }
  
  /// Send a Test message
  /// - Parameter serial:     radio serial number
  /// - Returns:              success / failure
  public func smartlinkTest(_ serial: String) {
    log("Smartlink Listener: test initiated to serial number, \(serial)", .debug, #function, #file, #line)
    // send a command to SmartLink to test the connection for the specified Radio
    _smartlinkListener?.sendTlsCommand("application test_connection serial=\(serial)")
  }
  
  /// Initiate a smartlink connection to a radio
  /// - Parameters:
  ///   - serialNumber:       the serial number of the Radio
  ///   - holePunchPort:      the negotiated Hole Punch port number
  /// - Returns:              a WanHandle
  public func smartlinkConnect(for serial: String, holePunchPort: Int) async throws -> String {
    
    return try await withCheckedThrowingContinuation{ continuation in
      _smartlinkListener?.awaitWanHandle = continuation
      log("Smartlink Listener: Connect sent to serial \(serial)", .debug, #function, #file, #line)
      // send a command to SmartLink to request a connection to the specified Radio
      _smartlinkListener?.sendTlsCommand("application connect serial=\(serial) hole_punch_port=\(holePunchPort))")
    }
  }
  
  /// Disconnect a smartlink Radio
  /// - Parameter serialNumber:         the serial number of the Radio
  public func smartlinkDisconnect(for serial: String) {
    log("Smartlink Listener: Disconnect sent to serial \(serial)", .debug, #function, #file, #line)
    // send a command to SmartLink to request disconnection from the specified Radio
    _smartlinkListener?.sendTlsCommand("application disconnect_users serial=\(serial)")
  }
  
  /// Disconnect a single smartlink Client
  /// - Parameters:
  ///   - serialNumber:         the serial number of the Radio
  ///   - handle:               the handle of the Client
  public func smartlinkDisconnectClient(for serial: String, handle: UInt32) {
    log("Smartlink Listener: Disconnect sent to serial \(serial), handle \(handle.hex)", .debug, #function, #file, #line)
    // send a command to SmartLink to request disconnection from the specified Radio
    _smartlinkListener?.sendTlsCommand("application disconnect_users serial=\(serial) handle=\(handle.hex)")
  }
  
  public func findSelection(for guiDefault: SettingsModel.DefaultConnection?, _ nonGuiDefault: SettingsModel.DefaultConnection?, _ isGui: Bool) -> String? {
    if isGui {
      guard guiDefault != nil else { return nil }
      for packet in packets where packet.serial == guiDefault!.serial && packet.source.rawValue == guiDefault!.source {
        return packet.serial + packet.publicIp
      }
      
    } else {
      guard nonGuiDefault != nil else { return nil }
      
      for packet in packets where packet.serial == nonGuiDefault!.serial
      && packet.source.rawValue == nonGuiDefault!.source
      && packet.guiClients.map({ $0.station }).contains(nonGuiDefault!.station!) {
        return packet.serial + packet.publicIp + nonGuiDefault!.station!
      }
    }
    return nil
  }
  
  public func sendGuiClientCompletion(_ guiClient: GuiClient) {
    _clientStream( ClientEvent(.completed, client: guiClient) )
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  
  func statusUpdate(_ status: WanStatus) {
    _statusStream(status)
  }
  
//  func testUpdate(_ result: SmartlinkTestResult) {
//    _testStream(result)
//  }
  
  /// Process an incoming DiscoveryPacket
  /// - Parameter newPacket: the packet
  func processPacket(_ newPacket: Packet) {
    
    // is it a Packet that has been seen previously?
    if let oldPacket = packets[id: newPacket.serial + newPacket.publicIp] {
      // KNOWN PACKET
      updatePacketData(oldPacket, newPacket)

//      if newPacket != oldPacket {
//        // CHANGED KNOWN packet
//        updatePacketData(oldPacket, newPacket)
//        log("\(newPacket.source == .local ? "Local" : "Smartlink") Listener: CHANGED packet, \(newPacket.nickname), \(newPacket.serial)", .info, #function, #file, #line)
//        
//      } else {
//        // UN-CHANGED KNOWN packet (timestamp update)
//        packets[id: newPacket.serial + newPacket.publicIp] = newPacket
//      }
      
    } else {
      // UNKNOWN packet
      updatePacketData(nil, newPacket)
      log("\(newPacket.source == .local ? "Local" : "Smartlink") Listener: NEW packet, \(newPacket.nickname), \(newPacket.serial)", .info, #function, #file, #line)
    }
  }
  
  private func updatePacketData(_ oldPacket: Packet?, _ newPacket: Packet ) {
    // update Packets collection
    packets[id: newPacket.serial + newPacket.publicIp] = newPacket
    
    // identify GuiClient changes
    if oldPacket == nil {
      for guiClient in newPacket.guiClients {
        
        stations.append(Station(packet: newPacket, station: guiClient.station))

        guiClients[id: guiClient.handle] = guiClient
        
        _clientStream( ClientEvent(.added, client: guiClient))
        log("Listener: guiClient ADDED, \(guiClient.station)", .info, #function, #file, #line)
      }
      
    } else {
      if oldPacket != nil {
        
        for guiClient in newPacket.guiClients {
          if !oldPacket!.guiClients.contains(guiClient){
            
            stations.append(Station(packet: newPacket, station: guiClient.station))

            guiClients[id: guiClient.handle] = guiClient

            _clientStream( ClientEvent(.added, client: guiClient))
            log("Listener: guiClient ADDED, \(guiClient.station)", .info, #function, #file, #line)
          }
        }
        for guiClient in oldPacket!.guiClients {
          if !newPacket.guiClients.contains(guiClient){
            
            stations.remove(id: oldPacket!.serial + oldPacket!.publicIp + guiClient.station)
            
            guiClients.remove(id: guiClient.handle)

            _clientStream( ClientEvent(.removed, client: guiClient))
            log("Listener: guiClient REMOVED, \(guiClient.station)", .info, #function, #file, #line)
          }
        }
      }
    }
    
//    for station in stations {
//      print("----->>>>> Station ", station.packet.nickname, station.station)
//    }
  }
  
  
  /// Remove one or more packets meeting the condition
  /// - Parameter condition: a closure defining the condition
  func removePackets(condition: @escaping (Packet) -> Bool) {
    _formatter.timeStyle = .long
    _formatter.dateStyle = .none
    for packet in packets where condition(packet) {
      packets.remove(packet)
      log("\(packet.source == .local ? "Local" : "Smartlink") Listener: packet REMOVED, \(packet.nickname) \(packet.serial) @ " + _formatter.string(from: packet.lastSeen), .info, #function, #file, #line)
    }
  }
  
  /// FIndthe first packet meeting the condition
  /// - Parameter condition: a closure defining the condition
  func findPacket(condition: @escaping (Packet) -> Bool) -> Packet? {
    for packet in packets where condition(packet) {
      return packet
    }
    return nil
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
}
