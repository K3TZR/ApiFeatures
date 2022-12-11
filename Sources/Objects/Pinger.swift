//
//  Pinger.swift
//  Api6000Components/Api6000
//
//  Created by Douglas Adams on 12/14/16.
//  Copyright © 2018 Douglas Adams & Mario Illgen. All rights reserved.
//

import Foundation
//import Combine
import ComposableArchitecture

import Shared

public enum PingStatus {
  case started
  case stopped(String?)
}

///  Pinger Actor implementation
///
///      generates "ping" messages every pingInterval second(s)
///      sends a PingStatus when stopped with an optional reason code
///
public final class Pinger { 
  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private var _lastPingRxTime: Date!
  private let _pingQ = DispatchQueue(label: "Radio.pingQ")
  private var _pingTimer: DispatchSourceTimer!
  private weak var _radio: Radio?
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(pingInterval: Int = 1, pingTimeout: Double = 10) {
    _lastPingRxTime = Date(timeIntervalSinceNow: 0)
    //    Task(priority: .background) {
    //      await startPinging(interval: pingInterval, timeout: pingTimeout)
    //    }
    startPinging(interval: pingInterval, timeout: pingTimeout)
  }
  
  @Dependency(\.apiModel) var apiModel
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  public func stopPinging(reason: String? = nil) {
    _pingTimer?.cancel()
//    pingPublisher.send(.stopped(reason))
  }
  
  public func pingReply(_ command: String, seqNum: UInt, responseValue: String, reply: String) {
    _lastPingRxTime = Date()
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Private methods
  
  private func startPinging(interval: Int, timeout: Double) {
    // create the timer's dispatch source
    _pingTimer = DispatchSource.makeTimerSource(queue: _pingQ)
    
    // Setup the timer
    _pingTimer.schedule(deadline: DispatchTime.now(), repeating: .seconds(interval))
    
    // set the event handler
    _pingTimer.setEventHandler(handler: { [self] in
      // has it been too long since the last response?
      let interval = Date().timeIntervalSince(_lastPingRxTime)
      if interval > timeout {
        // YES, stop the Pinger
        stopPinging(reason: "timeout")
        
      } else {
        Task(priority: .low) {
          await MainActor.run { apiModel.send("ping", replyTo: self.pingReply) }
        }
      }
    }
    )
    
    // start the timer
    _pingTimer.resume()
  }
}
