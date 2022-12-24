//
//  Radio.swift
//  Api6000Components/Api6000
//
//  Created by Douglas Adams on 1/12/22.
//

import ComposableArchitecture
import Foundation
import SwiftUI

import FlexErrors
import Shared
import Tcp
import Udp

@MainActor
public final class Radio: Equatable, ObservableObject {
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public nonisolated static func == (lhs: Radio, rhs: Radio) -> Bool { lhs === rhs }
  
  public nonisolated static let kDaxChannels = ["None", "1", "2", "3", "4", "5", "6", "7", "8"]
  public nonisolated static let kDaxIqChannels = ["None", "1", "2", "3", "4"]
  
  @AppStorage("guiClientId") public var guiClientId: String?
  public var clientInitialized = false
  
  // FIXME: needs to be dynamic
  public var packet: Packet?
  public var pingerEnabled = true
  @Published public var connectionHandle: Handle?
  public var hardwareVersion: String?
  
  @Published public internal(set) var antennaList = [AntennaPort]()
  public internal(set) var alpha = false
  public internal(set) var atuPresent = false
  public internal(set) var availablePanadapters = 0
  public internal(set) var availableSlices = 0
  public internal(set) var backlight = 0
  public internal(set) var bandPersistenceEnabled = false
  public internal(set) var binauralRxEnabled = false
  @Published public var boundClientId: String?
  public internal(set) var calFreq: MHz = 0
  public internal(set) var callsign = ""
  public internal(set) var chassisSerial = ""
  public internal(set) var daxIqAvailable = 0
  public internal(set) var daxIqCapacity = 0
  public internal(set) var enforcePrivateIpEnabled = false
  public internal(set) var extPresent = false
  public internal(set) var filterCwAutoEnabled = false
  public internal(set) var filterDigitalAutoEnabled = false
  public internal(set) var filterVoiceAutoEnabled = false
  public internal(set) var filterCwLevel = 0
  public internal(set) var filterDigitalLevel = 0
  public internal(set) var filterVoiceLevel = 0
  public internal(set) var fpgaMbVersion = ""
  public internal(set) var freqErrorPpb = 0
  public internal(set) var frontSpeakerMute = false
  public internal(set) var fullDuplexEnabled = false
  public internal(set) var gateway = ""
  public internal(set) var gpsPresent = false
  public internal(set) var gpsdoPresent = false
  public internal(set) var headphoneGain = 0
  public internal(set) var headphoneMute = false
  public internal(set) var ipAddress = ""
  public internal(set) var lineoutGain = 0
  public internal(set) var lineoutMute = false
  public internal(set) var localPtt = false
  public internal(set) var location = ""
  public internal(set) var locked = false
  public internal(set) var lowLatencyDigital = false
  public internal(set) var macAddress = ""
  @Published public internal(set) var micList = [MicrophonePort]()
  @Published public internal(set) var mox = false
  public internal(set) var muteLocalAudio = false
  public internal(set) var netmask = ""
  public internal(set) var nickname = ""
  public internal(set) var numberOfScus = 0
  public internal(set) var numberOfSlices = 0
  public internal(set) var numberOfTx = 0
  public internal(set) var oscillator = ""
  public internal(set) var picDecpuVersion = ""
  public internal(set) var program = ""
  public internal(set) var psocMbPa100Version = ""
  public internal(set) var psocMbtrxVersion = ""
  public internal(set) var radioAuthenticated = false
  public internal(set) var radioModel = ""
  public internal(set) var radioOptions = ""
  public internal(set) var region = ""
  public internal(set) var radioScreenSaver = ""
  public internal(set) var remoteOnEnabled = false
  @Published public internal(set) var rfGainList = [RfGainValue]()
  public internal(set) var rttyMark = 0
  public internal(set) var serverConnected = false
  public internal(set) var setting = ""
  @Published public internal(set) var sliceList = [SliceId]()
  public internal(set) var smartSdrMB = ""
  public internal(set) var snapTuneEnabled = false
  public internal(set) var softwareVersion = ""
  public internal(set) var startCalibration = false
  public internal(set) var state = ""
  public internal(set) var staticGateway = ""
  public internal(set) var staticIp = ""
  public internal(set) var staticNetmask = ""
  public internal(set) var station = ""
  public internal(set) var tnfsEnabled = false
  public internal(set) var tcxoPresent = false
  @Published public internal(set) var uptime = 0
  
  public enum PendingDisconnect: Equatable {
    case none
    case some (handle: Handle)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal properties
  
  let _appName: String
  var _clientId: String?
  let _connectionType: ConnectionType
  var _disconnectHandle: Handle?
  let _domain: String
  var _lowBandwidthConnect = false
  var _lowBandwidthDax = false
  let _parseQ = DispatchQueue(label: "Radio.parseQ", qos: .userInteractive)
  var _pinger: Pinger?
  var _programName: String?
//  var _radioInitialized = false
  var _stationName: String?
  //  weak var _testerDelegate: TesterDelegate?
  
  var _activeContinuation: CheckedContinuation<(), Error>?
  var _activeCheckedContinuation: CheckedContinuation<(), Never>?
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ packet: Packet, connectionType: ConnectionType = .gui, stationName: String? = nil, programName: String? = nil, lowBandwidthConnect: Bool = false, lowBandwidthDax: Bool = false, disconnectHandle: Handle? = nil) {
    
    self.packet = packet
    _connectionType = connectionType
    _lowBandwidthConnect = lowBandwidthConnect
    _lowBandwidthDax = lowBandwidthDax
    _stationName = stationName
    _programName = programName
    _disconnectHandle = disconnectHandle
    
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "net.k3tzr.Radio"
    let separator = bundleIdentifier.lastIndex(of: ".")!
    _appName = String(bundleIdentifier.suffix(from: bundleIdentifier.index(separator, offsetBy: 1)))
    _domain = String(bundleIdentifier.prefix(upTo: separator))
  }
  
  @Dependency(\.apiModel) var apiModel
  @Dependency(\.streamModel) var streamModel

  /// Parse the inBound Tcp stream
  /// - Parameter message:      message text
  public func tcpInbound(_ message: String) {
    // pass to the Tester (if any)
    //    _testerDelegate?.tcpInbound(message)
    
    // switch on the first character of the text
    switch message.prefix(1) {
      
    case "H", "h":  connectionHandle = String(message.dropFirst()).handle ; log("Radio: connectionHandle = \(connectionHandle?.hex ?? "missing")", .debug, #function, #file, #line)
    case "M", "m":  parseMessage( message.dropFirst() )
    case "R", "r":  parseReply( message )
    case "S", "s":  parseStatus( message.dropFirst() )
    case "V", "v":  hardwareVersion = String(message.dropFirst()) ; log("Radio: hardwareVersion = \(hardwareVersion ?? "missing")", .debug, #function, #file, #line)
    default:        log("Radio: unexpected message = \(message)", .warning, #function, #file, #line)
    }
  }
  
  /// Connect to this Radio
  /// - Parameter params:     a struct of parameters
  /// - Returns:              success / failure
  public func connect(_ packet: Packet) -> Bool {
    return Tcp.shared.connect(packet.source == .smartlink,
                              packet.requiresHolePunch,
                              packet.negotiatedHolePunchPort,
                              packet.publicTlsPort,
                              packet.port,
                              packet.publicIp,
                              packet.localInterfaceIP)
  }
  
  /// Disconnect from the Radio
  public func disconnect() {
    Tcp.shared.disconnect()
  }
  
  /// Send a command to the Radio (hardware)
  /// - Parameters:
  ///   - command:        a Command String
  ///   - flag:           use "D"iagnostic form
  ///   - callback:       a callback function (if any)
  public func send(_ command: String, diagnostic flag: Bool = false, replyTo callback: ReplyHandler? = nil, continuation: CheckedContinuation<String, Error>? = nil) {
    // tell TcpCommands to send the command
    let sequenceNumber = Tcp.shared.send(command, diagnostic: flag)
    
    // register to be notified when reply received
//    ApiModel.shared.addReplyHandler( sequenceNumber, replyTuple: (replyTo: callback, command: command, continuation: continuation) )
    apiModel.addReplyHandler( sequenceNumber, replyTuple: (replyTo: callback, command: command, continuation: continuation) )
  }
  
  /// Send data to the Radio (hardware)
  /// - Parameters:
  ///   - data:        data
  public func sendUdp(data: Data) {
    // tell Udp to send the data
    Udp.shared.send(data)
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Internal methods
  
  public func tcpStatus(_ status: TcpStatus) {
    switch status.statusType {
      
    case .didConnect:
      log("Tcp: socket connected to \(status.host) on port \(status.port)", .debug, #function, #file, #line)
    case .didSecure:
      log("Tcp: TLS socket did secure", .debug, #function, #file, #line)
    case .didDisconnect:
      log("Tcp: socket disconnected \(status.reason ?? "User initiated"), \(status.error == nil ? "" : "with error \(status.error!.localizedDescription)")", status.error == nil ? .debug : .warning, #function, #file, #line)
      
      apiModel.disconnect(status.reason)
    }
  }
  
  public func udpStatus(_ status: UdpStatus) {
    switch status.statusType {
      
    case .didUnBind:
      log("Udp: unbound from port, \(status.receivePort)", .debug, #function, #file, #line)
      
    case .failedToBind:
      log("Radio: UDP failed to bind, " + (status.error?.localizedDescription ?? "unknown error"), .warning, #function, #file, #line)
    case .readError:
      log("Radio: UDP read error, " + (status.error?.localizedDescription ?? "unknown error"), .warning, #function, #file, #line)
    }
  }
  
  /// executed after an IP Address has been obtained
  //  func connectionCompletion() {
  //    log("Radio: connectionCompletion for \(packet!.nickname)", .debug, #function, #file, #line)
  //
  //    // normal connection?
  //    if _disconnectHandle == nil {
  //      // YES, send the initial commands
  //      sendInitialCommands()
  //
  //      // set the UDP port for a Local connection
  //      if packet!.source == .local { send("client udpport " + "\(_udp.sendPort)") }
  //
  //    } else {
  //      // NO, pending disconnect
  //      send("client disconnect \(_disconnectHandle!.hex)")
  //
  //      // give client disconnection time to happen
  //      sleep(1)
  //      _tcp.disconnect()
  //      sleep(1)
  //
  //      // reconnect
  //      _disconnectHandle = nil
  //      clientInitialized = false
  //      _ = _tcp.connect(packet!)
  //    }
  //  }
  
  public func awaitClientConnected(_ source: PacketSource) async {
    return await withCheckedContinuation{ continuation in
      _activeCheckedContinuation = continuation
      log("Radio: waiting for \(source.rawValue) Client connection", .debug, #function, #file, #line)
    }
  }
  
  //  public func sendWanValidate(_ wanHandle: String) async throws {
  //    return try await withCheckedThrowingContinuation{ continuation in
  //      _activeContinuation = continuation
  //      log("Radio: Wan validate sent for handle=\(wanHandle)", .debug, #function, #file, #line)
  //
  //      send("wan validate handle=\(wanHandle)")
  //    }
  //  }
  
  
  
  
  public func sendAwaitReply(_ command: String, replyTo callback: ReplyHandler? = nil) async throws -> String {
    return try await withCheckedThrowingContinuation{ continuation in
      //      _activeContinuation = continuation
      send(command, replyTo: callback, continuation: continuation)
      return
    }
  }
  
  
  
  
  
  /// Send commands to configure the connection
  func sendInitialCommands() {
    
    if _connectionType == .gui && guiClientId == nil {
      send("client gui")
    }
    if _connectionType == .gui && guiClientId != nil {
      send("client gui \(guiClientId!)")
    }
    send("client program " + (_programName != nil ? _programName! : "MacProgram"))
    if _connectionType == .gui { send("client station " + (_stationName != nil ? _stationName! : "Mac")) }
    if _connectionType == .nonGui && _clientId != nil { bindToGuiClient(_clientId!) }
    if _lowBandwidthConnect { requestLowBandwidthConnect() }
    requestInfo()
    requestVersion()
    requestAntennaList()
    requestMicList()
    requestGlobalProfile()
    requestTxProfile()
    requestMicProfile()
    requestDisplayProfile()
    requestSubAll()
    requestMtuLimit(1_500)
    requestLowBandwidthDax(_lowBandwidthDax)
    requestUptime()
  }
  
  func startPinging() {
    // start pinging the Radio
    if pingerEnabled {
      // tell the Radio to expect pings
      send("keepalive enable")
      // start pinging the Radio
      _pinger = Pinger()
    }
  }
  
  public func stopPinging() {
    _pinger?.stopPinging(reason: "User initiated")
    _pinger = nil
  }
}

extension Radio {
  // ----------------------------------------------------------------------------
  // MARK: - ReplyHandlers
  
  /// Parse Replies
  /// - Parameters:
  ///   - commandSuffix:      a Reply Suffix
  @MainActor func parseReply(_ message: String) {
    
    let replySuffix = message.dropFirst()
    
    // separate it into its components
    let components = replySuffix.components(separatedBy: "|")
    // ignore incorrectly formatted replies
    if components.count < 2 {
      log("Radio: incomplete reply, r\(replySuffix)", .warning, #function, #file, #line)
      return
    }
    
    // get the sequence number, reply and any additional data
    let seqNum = components[0].sequenceNumber
    let reply = components[1]
    let otherData = components.count < 3 ? "" : components[2]
    
    // is the sequence number in the reply handlers?
//    if let replyTuple = ApiModel.shared.replyHandlers[ seqNum ] {
    if let replyTuple = apiModel.replyHandlers[ seqNum ] {
      // YES
      let command = replyTuple.command
      
      // Remove the object from the notification list
//      ApiModel.shared.removeReplyHandler(components[0].sequenceNumber)
      apiModel.removeReplyHandler(components[0].sequenceNumber)

      // Anything other than kNoError is an error, log it and ignore the Reply
      guard reply == kNoError else {
        // ignore non-zero reply from "client program" command
        if !command.hasPrefix("client program ") {
          log("Radio: reply >\(reply)<, to c\(seqNum), \(command), \(flexErrorString(errorCode: reply)), \(otherData)", .error, #function, #file, #line)
        }
        return
      }
      
      // process replies to the internal "sendCommands"?
      switch command {
        
      case "client gui":    parseGuiReply( otherData.keyValuesArray() )
        //      case "client ip":     connectionCompletion()
      case "slice list":    sliceList = otherData.valuesArray().compactMap { UInt32($0, radix: 10) }
      case "ant list":      antennaList = otherData.valuesArray( delimiter: "," )
      case "info":          parseInfoReply( (otherData.replacingOccurrences(of: "\"", with: "")).keyValuesArray(delimiter: ",") )
      case "mic list":      micList = otherData.valuesArray(  delimiter: "," )
      case "radio uptime":  uptime = Int(otherData) ?? 0
      case "version":       parseVersionReply( otherData.keyValuesArray(delimiter: "#") )
        
      default: break
        //        if command.hasPrefix("wan validate") {
        //          if reply == Shared.kNoError {
        //            _activeContinuation?.resume()
        //          } else {
        //            _activeContinuation?.resume(throwing: ConnectionError.wanValidation)
        //          }
        //        }
      }
      
      // did the sender supply a continuation?
      if let continuation = replyTuple.continuation {
        // YES, resume it
        if reply == Shared.kNoError {
          continuation.resume(returning: otherData)
        } else {
          continuation.resume(throwing: ConnectionError.replyError)
        }
      }
      
      // did the sender supply a callback?
      if let handler = replyTuple.replyTo {
        // YES, call the sender's Handler
        handler(command, seqNum, reply, otherData)
      }
    } else {
      log("Radio: reply >\(reply)<, unknown sequence number c\(seqNum), \(flexErrorString(errorCode: reply)), \(otherData)", .error, #function, #file, #line)
    }
  }
}

extension Radio {
  /// Parse a Message.
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  func parseMessage(_ msg: Substring) {
    // separate it into its components
    let components = msg.components(separatedBy: "|")
    
    // ignore incorrectly formatted messages
    if components.count < 2 {
      log("Radio: incomplete message = c\(msg)", .warning, #function, #file, #line)
      return
    }
    let msgText = components[1]
    
    // log it
    log("Radio: message = \(msgText)", flexErrorLevel(errorCode: components[0]), #function, #file, #line)
    
    // FIXME: Take action on some/all errors?
  }
  
  /// Parse a Status
  /// - Parameters:
  ///   - commandSuffix:      a Command Suffix
  public func parseStatus(_ commandSuffix: Substring) {
    
    // separate it into its components ( [0] = <apiHandle>, [1] = <remainder> )
    let components = commandSuffix.components(separatedBy: "|")
    
    // ignore incorrectly formatted status
    guard components.count > 1 else {
      log("Radio: incomplete status = c\(commandSuffix)", .warning, #function, #file, #line)
      return
    }
    
    // find the space & get the msgType
    let spaceIndex = components[1].firstIndex(of: " ")!
    let statusType = String(components[1][..<spaceIndex])
    
    // everything past the msgType is in the remainder
    let messageIndex = components[1].index(after: spaceIndex)
    let statusMessage = String(components[1][messageIndex...])
    
    // Check for unknown Object Types
    guard let objectType = ApiModel.ObjectType(rawValue: statusType)  else {
      // log it and ignore the message
      log("Radio: unknown status token = \(statusType)", .warning, #function, #file, #line)
      return
    }
    
    // is this status message the first for our handle?
    if clientInitialized == false && components[0].handle == connectionHandle {
      // YES, set the API state to finish the UDP initialization
      clientInitialized = true
      _activeCheckedContinuation!.resume()
    }
    
    Task {
      await apiModel.parse(objectType, statusMessage)
    }
  }
  
  /// Parse the Reply to a Client Gui command
  /// - Parameters:
  ///   - properties:          a KeyValuesArray
  func parseGuiReply(_ properties: KeyValuesArray) {
    for property in properties {
      // save the returned ID
      guiClientId = property.key
      break
    }
  }
  
  /// Parse the Reply to an Info command
  ///   executed on the parseQ
  ///
  /// - Parameters:
  ///   - properties:          a KeyValuesArray
  func parseInfoReply(_ properties: KeyValuesArray) {
    enum Property: String {
      case atuPresent               = "atu_present"
      case callsign
      case chassisSerial            = "chassis_serial"
      case gateway
      case gps
      case ipAddress                = "ip"
      case location
      case macAddress               = "mac"
      case model
      case netmask
      case name
      case numberOfScus             = "num_scu"
      case numberOfSlices           = "num_slice"
      case numberOfTx               = "num_tx"
      case options
      case region
      case screensaver
      case softwareVersion          = "software_ver"
    }
    
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Radio: unknown info property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known keys, in alphabetical order
      switch token {
        
      case .atuPresent:       atuPresent = property.value.bValue
      case .callsign:         callsign = property.value
      case .chassisSerial:    chassisSerial = property.value
      case .gateway:          gateway = property.value
      case .gps:              gpsPresent = (property.value != "Not Present")
      case .ipAddress:        ipAddress = property.value
      case .location:         location = property.value
      case .macAddress:       macAddress = property.value
      case .model:            radioModel = property.value
      case .netmask:          netmask = property.value
      case .name:             nickname = property.value
      case .numberOfScus:     numberOfScus = property.value.iValue
      case .numberOfSlices:   numberOfSlices = property.value.iValue
      case .numberOfTx:       numberOfTx = property.value.iValue
      case .options:          radioOptions = property.value
      case .region:           region = property.value
      case .screensaver:      radioScreenSaver = property.value
      case .softwareVersion:  softwareVersion = property.value
      }
    }
  }
  
  /// Parse the Reply to a Version command, reply format: <key=value>#<key=value>#...<key=value>
  /// - Parameters:
  ///   - properties:          a KeyValuesArray
  func parseVersionReply(_ properties: KeyValuesArray) {
    enum Property: String {
      case fpgaMb                   = "fpga-mb"
      case psocMbPa100              = "psoc-mbpa100"
      case psocMbTrx                = "psoc-mbtrx"
      case smartSdrMB               = "smartsdr-mb"
      case picDecpu                 = "pic-decpu"
    }
    // process each key/value pair, <key=value>
    for property in properties {
      // check for unknown Keys
      guard let token = Property(rawValue: property.key) else {
        // log it and ignore the Key
        log("Radio: unknown version property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .smartSdrMB:   smartSdrMB = property.value
      case .picDecpu:     picDecpuVersion = property.value
      case .psocMbTrx:    psocMbtrxVersion = property.value
      case .psocMbPa100:  psocMbPa100Version = property.value
      case .fpgaMb:       fpgaMbVersion = property.value
      }
    }
  }
  
  /// Parse a Radio status message
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  func parse(_ properties: KeyValuesArray) {
    enum Property: String {
      case alpha
      case backlight
      case bandPersistenceEnabled   = "band_persistence_enabled"
      case binauralRxEnabled        = "binaural_rx"
      case calFreq                  = "cal_freq"
      case callsign
      case daxIqAvailable           = "daxiq_available"
      case daxIqCapacity            = "daxiq_capacity"
      case enforcePrivateIpEnabled  = "enforce_private_ip_connections"
      case freqErrorPpb             = "freq_error_ppb"
      case frontSpeakerMute         = "front_speaker_mute"
      case fullDuplexEnabled        = "full_duplex_enabled"
      case headphoneGain            = "headphone_gain"
      case headphoneMute            = "headphone_mute"
      case lineoutGain              = "lineout_gain"
      case lineoutMute              = "lineout_mute"
      case lowLatencyDigital        = "low_latency_digital_modes"
      case muteLocalAudio           = "mute_local_audio_when_remote"
      case nickname
      case panadapters
      case pllDone                  = "pll_done"
      case radioAuthenticated       = "radio_authenticated"
      case remoteOnEnabled          = "remote_on_enabled"
      case rttyMark                 = "rtty_mark_default"
      case serverConnected          = "server_connected"
      case slices
      case snapTuneEnabled          = "snap_tune_enabled"
      case tnfsEnabled              = "tnf_enabled"
    }
    enum SubProperty: String {
      case filterSharpness          = "filter_sharpness"
      case staticNetParams          = "static_net_params"
      case oscillator
    }
    // separate by category
    if let category = SubProperty(rawValue: properties[0].key) {
      // drop the first property
      let adjustedProperties = Array(properties[1...])
      
      switch category {
        
      case .filterSharpness:  parseFilterProperties( adjustedProperties )
      case .staticNetParams:  parseStaticNetProperties( adjustedProperties )
      case .oscillator:       parseOscillatorProperties( adjustedProperties )
      }
      
    } else {
      // process each key/value pair, <key=value>
      for property in properties {
        // Check for Unknown Keys
        guard let token = Property(rawValue: property.key)  else {
          // log it and ignore the Key
          log("Radio: unknown property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
          continue
        }
        // Known tokens, in alphabetical order
        switch token {
          
        case .alpha:                    alpha = property.value.bValue
        case .backlight:                backlight = property.value.iValue
        case .bandPersistenceEnabled:   bandPersistenceEnabled = property.value.bValue
        case .binauralRxEnabled:        binauralRxEnabled = property.value.bValue
        case .calFreq:                  calFreq = property.value.dValue
        case .callsign:                 callsign = property.value
        case .daxIqAvailable:           daxIqAvailable = property.value.iValue
        case .daxIqCapacity:            daxIqCapacity = property.value.iValue
        case .enforcePrivateIpEnabled:  enforcePrivateIpEnabled = property.value.bValue
        case .freqErrorPpb:             freqErrorPpb = property.value.iValue
        case .fullDuplexEnabled:        fullDuplexEnabled = property.value.bValue
        case .frontSpeakerMute:         frontSpeakerMute = property.value.bValue
        case .headphoneGain:            headphoneGain = property.value.iValue
        case .headphoneMute:            headphoneMute = property.value.bValue
        case .lineoutGain:              lineoutGain = property.value.iValue
        case .lineoutMute:              lineoutMute = property.value.bValue
        case .lowLatencyDigital:        lowLatencyDigital = property.value.bValue
        case .muteLocalAudio:           muteLocalAudio = property.value.bValue
        case .nickname:                 nickname = property.value
        case .panadapters:              availablePanadapters = property.value.iValue
        case .pllDone:                  startCalibration = property.value.bValue
        case .radioAuthenticated:       radioAuthenticated = property.value.bValue
        case .remoteOnEnabled:          remoteOnEnabled = property.value.bValue
        case .rttyMark:                 rttyMark = property.value.iValue
        case .serverConnected:          serverConnected = property.value.bValue
        case .slices:                   availableSlices = property.value.iValue
        case .snapTuneEnabled:          snapTuneEnabled = property.value.bValue
        case .tnfsEnabled:              tnfsEnabled = property.value.bValue
        }
      }
    }
    // is the Radio initialized?
//    if !_radioInitialized {
//      // YES, notify all observers
//      _radioInitialized = true
//      log("Radio: initialized, name = \(nickname)", .debug, #function, #file, #line)
//    }
  }
  
  /// Parse a Filter Properties status message
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  private func parseFilterProperties(_ properties: KeyValuesArray) {
    var cw = false
    var digital = false
    var voice = false
    
    enum Property: String {
      case cw
      case digital
      case voice
      case autoLevel                = "auto_level"
      case level
    }
    
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key.lowercased())  else {
        // log it and ignore the Key
        log("Radio: unknown filter property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .cw:       cw = true
      case .digital:  digital = true
      case .voice:    voice = true
        
      case .autoLevel:
        if cw       { filterCwAutoEnabled = property.value.bValue ; cw = false }
        if digital  { filterDigitalAutoEnabled = property.value.bValue ; digital = false }
        if voice    { filterVoiceAutoEnabled = property.value.bValue ; voice = false }
      case .level:
        if cw       { filterCwLevel = property.value.iValue }
        if digital  { filterDigitalLevel = property.value.iValue  }
        if voice    { filterVoiceLevel = property.value.iValue }
      }
    }
  }
  
  /// Parse a Static Net Properties status message
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  private func parseStaticNetProperties(_ properties: KeyValuesArray) {
    enum Property: String {
      case gateway
      case ip
      case netmask
    }
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Radio: unknown static property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .gateway:  staticGateway = property.value
      case .ip:       staticIp = property.value
      case .netmask:  staticNetmask = property.value
      }
    }
  }
  
  /// Parse an Oscillator Properties status message
  /// - Parameters:
  ///   - properties:      a KeyValuesArray
  private func parseOscillatorProperties(_ properties: KeyValuesArray) {
    enum Property: String {
      case extPresent               = "ext_present"
      case gpsdoPresent             = "gpsdo_present"
      case locked
      case setting
      case state
      case tcxoPresent              = "tcxo_present"
    }
    // process each key/value pair, <key=value>
    for property in properties {
      // Check for Unknown Keys
      guard let token = Property(rawValue: property.key)  else {
        // log it and ignore the Key
        log("Radio: unknown oscillator property, \(property.key) = \(property.value)", .warning, #function, #file, #line)
        continue
      }
      // Known tokens, in alphabetical order
      switch token {
        
      case .extPresent:   extPresent = property.value.bValue
      case .gpsdoPresent: gpsdoPresent = property.value.bValue
      case .locked:       locked = property.value.bValue
      case .setting:      setting = property.value
      case .state:        state = property.value
      case .tcxoPresent:  tcxoPresent = property.value.bValue
      }
    }
  }
  
  /*
   "radio oscillator " + _selectedOscillator.ToString()
   "radio set rtty_mark_default=" + _rttyMarkDefault
   "radio backlight " + _backlight
   "radio set binaural_rx=" + Convert.ToByte(_binauralRX)
   "radio set mute_local_audio_when_remote=" + Convert.ToByte(_isMuteLocalAudioWhenRemoteOn)
   "radio set snap_tune_enabled=" + Convert.ToByte(_snapTune)
   "radio filter_sharpness voice level=" + _filterSharpnessVoice
   "radio filter_sharpness voice auto_level=" + Convert.ToByte(_filterSharpnessVoiceAuto)
   "radio filter_sharpness cw level=" + _filterSharpnessCW
   "radio filter_sharpness cw auto_level=" + Convert.ToByte(_filterSharpnessCWAuto)
   "radio filter_sharpness digital level=" + _filterSharpnessDigital
   "radio filter_sharpness digital auto_level=" + Convert.ToByte(_filterSharpnessDigitalAuto)
   "radio reboot"
   "radio set tnf_enabled=" + _tnfEnabled
   "radio screensaver " + ScreensaverModeToString(_screensaver)
   "radio callsign " + _callsign
   "radio name " + _nickname
   "radio set remote_on_enabled=" + Convert.ToByte(_remoteOnEnabled)
   "radio set full_duplex_enabled=" + Convert.ToByte(_fullDuplexEnabled)
   "radio pll_start"
   "radio set freq_error_ppb=" + _freqErrorPPB
   "radio set cal_freq=" + StringHelper.DoubleToString(_calFreq, "f6")
   "radio gps install"
   "radio gps uninstall"
   "radio set enforce_private_ip_connections=" + Convert.ToByte(_enforcePrivateIPConnections)
   */
}

extension Radio {
  
//  public func parseAndSend(_ property: Property, _ value: String = "") {
//    var newValue = value
//
//    // alphabetical order
//    switch property {
//
//    }
//    parse([(property.rawValue, newValue)])
//    send(property, newValue)
//  }
//
//  public func send(_ property: Property, _ value: String) {
//    // Known tokens, in alphabetical order
//    switch property {
//    }
//  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  /// Send a command to Set a property
  /// - Parameters:
  ///   - token:      the parse token
  ///   - separator:  String used between token and value
  ///   - value:      the new value
//  private func transmitCmd(_ token: Property, _ separator: String, _ value: Any) {
//    apiModel.send("transmit set " + token.rawValue + separator + "\(value)")
//  }
}
