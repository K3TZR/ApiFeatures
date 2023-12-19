//
//  ApiFeaturesTests.swift
//  
//
//  Created by Douglas Adams on 12/22/22.
//

import XCTest

@testable import Listener
import SharedModel

final class ApiFeaturesTests: XCTestCase {
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }
  
  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }
  
  func testGuiPickables() async {
    let listener = Listener()
    
    var packet = Packet(source: .local,
                        nickname: "Dougs 6700",
                        serial: "1234-5678-9012-3456",
                        publicIp: "192.168.1.200",
                        status: "available",
                        guiClientStations: "")
    listener.processPacket(packet)
    
    packet = Packet(source: .local,
                    nickname: "Dougs 6300",
                    serial: "5678-9012-3456-7890",
                    publicIp: "192.168.1.201",
                    status: "available",
                    guiClientHandles: "0x12345678,,",
                    guiClientPrograms: "xSDR6000,,",
                    guiClientStations: "40 Meters,,",
                    guiClientIps: "192.168.1.222,,")
    listener.processPacket(packet)
    
    packet = Packet(source: .smartlink,
                    nickname: "Petes 6700",
                    serial: "9012-3456-7890-1234",
                    publicIp: "77.24.1.200",
                    status: "available",
                    guiClientStations: "")
    listener.processPacket(packet)

    let pickableRadios = listener.pickableRadios
    
    XCTAssertEqual(pickableRadios.count, 3, "PickableRadios count", file: #function)
    
    let pickableRadio = pickableRadios.first!
    XCTAssertEqual(pickableRadio.packet.source, PacketSource.local, "PickableRadio source", file: #function)
    XCTAssertEqual(pickableRadio.packet.nickname, "Dougs 6700", "PickableRadio nickname", file: #function)
    XCTAssertEqual(pickableRadio.packet.serial, "1234-5678-9012-3456", "PickableRadio serial", file: #function)
    XCTAssertEqual(pickableRadio.packet.publicIp, "192.168.1.200", "PickableRadio publicIp", file: #function)
    XCTAssertEqual(pickableRadio.packet.status, "available", "PickableRadio status", file: #function)
    XCTAssertEqual(pickableRadio.packet.guiClientHandles, "", "PickableRadio guiClientHandles", file: #function)
    XCTAssertEqual(pickableRadio.packet.guiClientPrograms, "", "PickableRadio guiClientPrograms", file: #function)
    XCTAssertEqual(pickableRadio.packet.guiClientStations, "", "PickableRadio guiClientStations", file: #function)
    XCTAssertEqual(pickableRadio.packet.guiClientIps, "", "PickableRadio guiClientIps", file: #function)
    XCTAssertEqual(pickableRadio.station, "", "PickableRadio station", file: #function)

    let pickableStations = listener.pickableStations
    XCTAssertEqual(pickableStations.count, 1, "PickableStations count", file: #function)

    let pickableStation = pickableStations.first!
    XCTAssertEqual(pickableStation.packet.source, PacketSource.local, "PickableSataion source", file: #function)
    XCTAssertEqual(pickableStation.packet.nickname, "Dougs 6300", "PickableStation nickname", file: #function)
    XCTAssertEqual(pickableStation.packet.serial, "5678-9012-3456-7890", "PickableStation serial", file: #function)
    XCTAssertEqual(pickableStation.packet.publicIp, "192.168.1.201", "PickableStation publicIp", file: #function)
    XCTAssertEqual(pickableStation.packet.status, "available", "PickableStation status", file: #function)
    XCTAssertEqual(pickableStation.packet.guiClientHandles, "0x12345678,,", "PickableStation guiClientHandles", file: #function)
    XCTAssertEqual(pickableStation.packet.guiClientPrograms, "xSDR6000,,", "PickableStation guiClientPrograms", file: #function)
    XCTAssertEqual(pickableStation.packet.guiClientStations, "40 Meters,,", "PickableStation guiClientStations", file: #function)
    XCTAssertEqual(pickableStation.packet.guiClientIps, "192.168.1.222,,", "PickableStation guiClientIps", file: #function)
    XCTAssertEqual(pickableStation.station, "40 Meters", "PickableStation station", file: #function)
  }
  
}
