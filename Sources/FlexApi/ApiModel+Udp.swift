//
//  ApiModel+Udp.swift
//  
//
//  Created by Douglas Adams on 5/25/23.
//

import SharedModel
import Udp

extension ApiModel {
  private func udpStatus(_ status: UdpStatus) {
    switch status.statusType {
      
    case .didUnBind:
      log("Udp: unbound from port, \(status.receivePort)", .debug, #function, #file, #line)
    case .failedToBind:
      log("Udp: failed to bind, " + (status.error?.localizedDescription ?? "unknown error"), .warning, #function, #file, #line)
    case .readError:
      log("Udp: read error, " + (status.error?.localizedDescription ?? "unknown error"), .warning, #function, #file, #line)
    }
  }
  
  // Process the AsyncStream of UDP status changes
  private func subscribeToUdpStatus() {
    Task(priority: .high) {
      log("Api: UdpStatus subscription STARTED", .debug, #function, #file, #line)
      for await status in Udp.shared.statusStream {
        udpStatus(status)
      }
      log("Api: UdpStatus subscription STOPPED", .debug, #function, #file, #line)
    }
  }
}
