//
//  Listener.swift
//  
//
//  Created by Douglas Adams on 11/26/22.
//

import Foundation
import ComposableArchitecture
import SwiftUI

//import LoginFeature
import Shared

extension Listener: DependencyKey {
  public static let liveValue = Listener()
//  public static let previewValue = Listener()
  public static var previewValue: Listener {
    let listener = Listener()
    
    let packet1 = Packet(source: .local,
                        nickname: "Dougs 6700",
                        serial: "1234-5678-9012-3456",
                        publicIp: "192.168.1.200",
                        status: "available",
                        guiClientStations: "")
    listener.processPacket(packet1)
    
    let packet2 = Packet(source: .local,
                    nickname: "Dougs 6300",
                    serial: "5678-9012-3456-7890",
                    publicIp: "192.168.1.201",
                    status: "available",
                    guiClientHandles: "0x12345678,,",
                    guiClientPrograms: "xSDR6000,,",
                    guiClientStations: "40 Meters,,",
                    guiClientIps: "192.168.1.222,,")
    listener.processPacket(packet2)
    
    let packet3 = Packet(source: .smartlink,
                    nickname: "Petes 6700",
                    serial: "9012-3456-7890-1234",
                    publicIp: "77.24.1.200",
                    status: "available",
                    guiClientStations: "")
    listener.processPacket(packet3)
    return listener
  }
}

extension DependencyValues {
  public var listener: Listener{
    get {self[Listener.self]}
    set {self[Listener.self] = newValue}
  }
}

@MainActor
public class Listener: ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Published properties
  
  @Published public var packets = IdentifiedArrayOf<Packet>()
//  @Published public var guiClients = IdentifiedArrayOf<GuiClient>()
  
  @Published public var pickableRadios = IdentifiedArrayOf<Pickable>()
  @Published public var pickableStations = IdentifiedArrayOf<Pickable>()
  
  // ----------------------------------------------------------------------------
  // MARK: - Public AsyncStreams
  
  public var clientStream: AsyncStream<ClientEvent> {
    AsyncStream { continuation in _clientStream = { clientEvent in continuation.yield(clientEvent) }
      continuation.onTermination = { @Sendable _ in } }}
  
//  public var packetStream: AsyncStream<PacketEvent> {
//    AsyncStream { continuation in _packetStream = { packetEvent in continuation.yield(packetEvent) }
//      continuation.onTermination = { @Sendable _ in } }}
  
  public var statusStream: AsyncStream<WanStatus> {
    AsyncStream { continuation in _statusStream = { status in continuation.yield(status) }
      continuation.onTermination = { @Sendable _ in } }}

  public var testStream: AsyncStream<TestResult> {
    AsyncStream { continuation in _testStream = { testResult in continuation.yield(testResult) }
      continuation.onTermination = { @Sendable _ in } }}

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _lanListener: LanListener?
  private var _wanListener: WanListener?
  
  private var _clientStream: (ClientEvent) -> Void = { _ in }
//  private var _packetStream: (PacketEvent) -> Void = { _ in }
  var _statusStream: (WanStatus) -> Void = { _ in }
  var _testStream: (TestResult) -> Void = { _ in }

  private let _formatter = DateFormatter()
  
  private enum UpdateStatus {
    case newPacket
    case timestampOnly
    case changedPacket
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization (singleton)
  
  public init() {}
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func setConnectionMode(_ mode: ConnectionMode, _ smartlinkEmail: String = "", _ forceWanLogin: Bool = false) async -> Bool {
    if mode == .smartlink || mode == .none {
      _lanListener?.stop()
      _lanListener = nil
    }
    if mode == .local || mode == .none {
      _wanListener?.stop()
      _wanListener = nil
    }
    removeAll()
    
    switch mode {
      
    case .both:
      // Local & Smartlink
      _lanListener = LanListener(self)
      _lanListener!.start()
      _wanListener = WanListener(self)
      if await _wanListener!.start(smartlinkEmail, forceWanLogin) == false {
        _wanListener = nil
        return false
      }
      return true
      
    case .local:
      // Local only
      _lanListener = LanListener(self)
      _lanListener!.start()
      return true
      
    case .smartlink:
      // Smartlink only
      _wanListener = WanListener(self)
      if await _wanListener!.start(smartlinkEmail, forceWanLogin) == false {
        _wanListener = nil
        return false
      }
      return true
      
    case .none:
      // neither
      return true
    }
  }
  
  public func startWan(_ user: String, _ pwd: String) async -> Bool {
    _wanListener = WanListener(self)
    let status = await _wanListener!.start(user: user, pwd: pwd)
    if status == false { _wanListener = nil }
    return status
  }
  
  /// Send a Test message
  /// - Parameter serial:     radio serial number
  /// - Returns:              success / failure
  public func sendWanTest(_ serial: String) {
    log("Wan Listener: test initiated to serial number, \(serial)", .debug, #function, #file, #line)
    // send a command to SmartLink to test the connection for the specified Radio
    _wanListener?.sendTlsCommand("application test_connection serial=\(serial)")
  }
  
  /// Initiate a smartlink connection to a radio
  /// - Parameters:
  ///   - serialNumber:       the serial number of the Radio
  ///   - holePunchPort:      the negotiated Hole Punch port number
  /// - Returns:              a WanHandle
  public func sendWanConnect(for serial: String, holePunchPort: Int) async throws -> String {
    
    return try await withCheckedThrowingContinuation{ continuation in
      _wanListener?.activeContinuation = continuation
      log("Wan Listener: Connect sent to serial \(serial)", .debug, #function, #file, #line)
      // send a command to SmartLink to request a connection to the specified Radio
      _wanListener?.sendTlsCommand("application connect serial=\(serial) hole_punch_port=\(holePunchPort))")
    }
  }
  
  /// Disconnect a smartlink Radio
  /// - Parameter serialNumber:         the serial number of the Radio
  public func sendWanDisconnect(for serial: String) {
    log("Wan Listener: Disconnect sent to serial \(serial)", .debug, #function, #file, #line)
    // send a command to SmartLink to request disconnection from the specified Radio
    _wanListener?.sendTlsCommand("application disconnect_users serial=\(serial)")
  }
  
  /// Disconnect a single smartlink Client
  /// - Parameters:
  ///   - serialNumber:         the serial number of the Radio
  ///   - handle:               the handle of the Client
  public func sendWanDisconnectClient(for serial: String, handle: Handle) {
    log("Wan Listener: Disconnect sent to serial \(serial), handle \(handle.hex)", .debug, #function, #file, #line)
    // send a command to SmartLink to request disconnection from the specified Radio
    _wanListener?.sendTlsCommand("application disconnect_users serial=\(serial) handle=\(handle.hex)")
  }
  
  public func findPacket(for guiDefault: DefaultValue?, _ nonGuiDefault: DefaultValue?, _ isGui: Bool) -> Packet? {
    if isGui {
      guard guiDefault != nil else { return nil }
      for packet in packets where packet.serial == guiDefault!.serial && packet.source.rawValue == guiDefault!.source {
        return packet
      }

    } else {
      guard nonGuiDefault != nil else { return nil }
      for packet in packets where packet.serial == nonGuiDefault!.serial
      && packet.source.rawValue == nonGuiDefault!.source
      && packet.guiClientStations.contains(nonGuiDefault!.station!) {
        return packet
      }
    }
    return nil
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  
  func statusUpdate(_ status: WanStatus) {
    _statusStream(status)
  }
  
  func testUpdate(_ result: TestResult) {
    _testStream(result)
  }

  
  
  /// Process an incoming DiscoveryPacket
  /// - Parameter newPacket: the packet
  func processPacket(_ newPacket: Packet) {
    
    // is it a Radio that has been seen previously?
    if let oldPacket = packets[id: newPacket.serial + newPacket.publicIp] {
      // KNOWN RADIO, check the GuiClients
      
      // has it changed?
      if newPacket.isDifferent(from: oldPacket) {
        // YES, update packets & Gui Clients
        parsePacket(newPacket, oldPacket)
        return
        
      } else {
        // KNOWN RADIO, no change, update the timestamp
        addUpdatePacket(newPacket, status: .timestampOnly)
        return
      }
    }
    // UNKNOWN RADIO, update packets & Gui Clients
    parsePacket(newPacket)
  }
  
  func parsePacket(_ newPacket: Packet, _ oldPacket: Packet? = nil) {
    // parse the received Gui Clients
    let receivedGuiClients = parseGuiClients(newPacket)
    
    // identify and report any changes
    checkGuiClients(receivedGuiClients, oldPacket, newPacket)
    
    // add/update packets & guiClients
    addUpdatePacket(newPacket, status: oldPacket == nil ? .newPacket : .changedPacket)
  }
  
  /// Identify added and removed Gui Clients
  /// - Parameter newGuiClients: the latest GuiClients parse
  func checkGuiClients(_ receivedGuiClients: IdentifiedArrayOf<GuiClient>, _ oldPacket: Packet? = nil, _ newPacket: Packet) {
    
    if oldPacket == nil {
      for guiClient in receivedGuiClients {
        newPacket.guiClients.append(guiClient)
        _clientStream( ClientEvent(.added, client: guiClient))
        log("Listener: guiClient ADDED, \(guiClient.station)", .info, #function, #file, #line)
      }
      
    } else {
      for guiClient in receivedGuiClients.elements.added(to: newPacket.guiClients.elements) {
        newPacket.guiClients.append(guiClient)
        _clientStream( ClientEvent(.added, client: guiClient))
        log("Listener: guiClient ADDED, \(guiClient.station)", .info, #function, #file, #line)
      }
      
      for guiClient in receivedGuiClients.elements.removed(from: newPacket.guiClients.elements) {
        newPacket.guiClients.remove(guiClient)
        _clientStream( ClientEvent(.removed, client: guiClient))
        log("\(oldPacket!.source == .local ? "Lan" : "Wan") Listener: guiClient REMOVED, \(guiClient.station)", .info, #function, #file, #line)
      }
    }
  }
  
  /// Remove one or more packets meeting the condition
  /// - Parameter condition: a closure defining the condition
  func removePackets(condition: @escaping (Packet) -> Bool) {
    _formatter.timeStyle = .long
    _formatter.dateStyle = .none
    for packet in packets where condition(packet) {
      packets.remove(packet)
      log("\(packet.source == .local ? "Lan" : "Wan") Listener: packet REMOVED, \(packet.nickname) \(packet.serial) @ " + _formatter.string(from: packet.lastSeen), .info, #function, #file, #line)
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
  
  /// Produce an IdentifiedArray of Radios that can be picked
  func getPickableRadios() -> IdentifiedArrayOf<Pickable> {
    var pickables = IdentifiedArrayOf<Pickable>()
    for packet in packets {
      pickables.append( Pickable(id: UUID(),
                                 packet: packet,
                                 station: packet.guiClientStations))
    }
    return pickables
  }
  
  /// Produce an IdentifiedArray of Stations that can be picked
  func getPickableStations() -> IdentifiedArrayOf<Pickable> {
    var pickables = IdentifiedArrayOf<Pickable>()
    for packet in packets {
      for guiClient in packet.guiClients {
        pickables.append( Pickable(id: UUID(),
                                   packet: packet,
                                   station: guiClient.station))
      }
    }
    return pickables
  }
  
  /// Determine if a GuiClient is fully populated
  /// - Parameter client: the guiClient
//  public func checkCompletion(_ client: GuiClient?) {
//    if let client {
//      
//      // log & notify if all essential properties are present
//      if client.handle != 0 && client.clientId != nil && client.program != "" && client.station != "" {
//        log("Packets: guiClient COMPLETED: \(client.handle.hex), \(client.station), \(client.program), \(client.clientId!)", .info, #function, #file, #line)
//        _clientStream( ClientEvent(.completed, client: client) )
//      }
//    }
//  }
//  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Parse the GuiClient CSV fields in a packet
  private func parseGuiClients(_ packet: Packet) -> IdentifiedArrayOf<GuiClient> {
    var guiClients = IdentifiedArrayOf<GuiClient>()
    
    guard packet.guiClientPrograms != "" && packet.guiClientStations != "" && packet.guiClientHandles != "" else { return guiClients }
    
    let programs  = packet.guiClientPrograms.components(separatedBy: ",")
    let stations  = packet.guiClientStations.components(separatedBy: ",")
    let handles   = packet.guiClientHandles.components(separatedBy: ",")
    let ips       = packet.guiClientIps.components(separatedBy: ",")
    
    guard programs.count == handles.count && stations.count == handles.count && ips.count == handles.count else { return guiClients }
    
    for i in 0..<handles.count {
      // add/update if valid fields
      if let handle = handles[i].handle, stations[i] != "", programs[i] != "" , ips[i] != "" {
        // add/update the collection
        guiClients[id: handle] = GuiClient(handle: handle,
                                           station: stations[i],
                                           program: programs[i],
                                           ip: ips[i])
      }
    }
    return guiClients
  }
  
  private func addUpdatePacket(_ packet: Packet, status: UpdateStatus) {
    packets[id: packet.serial + packet.publicIp] = packet
    switch status {
    case .timestampOnly:    return
    case .newPacket, .changedPacket:
      pickableRadios = getPickableRadios()
      pickableStations = getPickableStations()
      log("\(packet.source == .local ? "Lan" : "Wan") Listener: packet \(status == .newPacket ? "ADDED" : "UPDATED"), \(packet.nickname) \(packet.serial)", .info, #function, #file, #line)
    }
  }
  
  private func removeAll() {
        packets = IdentifiedArrayOf<Packet>()
        pickableRadios = IdentifiedArrayOf<Pickable>()
        pickableStations = IdentifiedArrayOf<Pickable>()
  }
}

// ----------------------------------------------------------------------------
// MARK: - Array Extensions

extension Array where Element: Hashable {
  func removed(from other: [Element]) -> [Element] {
    let thisSet = Set(self)
    let otherSet = Set(other)
    return Array(otherSet.subtracting(thisSet))
  }
  
  func added(to other: [Element]) -> [Element] {
    let thisSet = Set(self)
    let otherSet = Set(other)
    return Array(thisSet.subtracting(otherSet))
  }
}

