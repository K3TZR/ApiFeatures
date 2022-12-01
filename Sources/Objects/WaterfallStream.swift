//
//  WaterfallStream.swift
//  
//
//  Created by Douglas Adams on 9/22/22.
//

import Foundation

import Shared

public class WaterfallStream: Identifiable {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: WaterfallId) {
    self.id = id
  }
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var delegate: StreamHandler?
  public let id: WaterfallId
//  public var packetErrors = 0
//  public var packetsProcessed = 0

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private static let kNumberOfFrames = 10

  private struct PayloadHeader {    // struct to mimic payload layout
    var firstBinFreq: UInt64        // 8 bytes
    var binBandwidth: UInt64        // 8 bytes
    var lineDuration : UInt32       // 4 bytes
    var segmentBinCount: UInt16     // 2 bytes
    var height: UInt16              // 2 bytes
    var frameNumber: UInt32         // 4 bytes
    var autoBlackLevel: UInt32      // 4 bytes
    var frameBinCount: UInt16       // 2 bytes
    var startingBinNumber: UInt16   // 2 bytes
  }
  
  private var _accumulatedBins = 0
  private var _expectedFrameNumber = -1
  private var _frames = [WaterfallFrame](repeating: WaterfallFrame(), count:kNumberOfFrames )
  private var _index: Int = 0
  private var _isStreaming = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Process the Waterfall Vita struct
  ///      The payload of the incoming Vita struct is converted to a WaterfallFrame and
  ///      passed to the Waterfall Stream Handler
  /// - Parameters:
  ///   - vita:       a Vita struct
  public func vitaProcessor(_ vita: Vita) {
    if _isStreaming == false {
      _isStreaming = true
      
      // log the start of the stream
      log("Waterfall \(vita.streamId.hex) stream: STARTED", .info, #function, #file, #line)
      Task {
        await ApiModel.shared.waterfalls[id: vita.streamId]?.setIsStreaming()
      }
    }
    
    // Bins are just beyond the payload
    let byteOffsetToBins = MemoryLayout<PayloadHeader>.size
    
    vita.payloadData.withUnsafeBytes { ptr in
      // map the payload to the Payload struct
      let hdr = ptr.bindMemory(to: PayloadHeader.self)
      
      _frames[_index].startingBinNumber = Int(CFSwapInt16BigToHost(hdr[0].startingBinNumber))
      _frames[_index].segmentBinCount = Int(CFSwapInt16BigToHost(hdr[0].segmentBinCount))
      _frames[_index].frameBinCount = Int(CFSwapInt16BigToHost(hdr[0].frameBinCount))
      _frames[_index].frameNumber = Int(CFSwapInt32BigToHost(hdr[0].frameNumber))
      
      // validate the packet (could be incomplete at startup)
      if _frames[_index].frameBinCount == 0 { return }
      if _frames[_index].startingBinNumber + _frames[_index].segmentBinCount > _frames[_index].frameBinCount { return }
      
      // populate frame values
      _frames[_index].firstBinFreq = CGFloat(CFSwapInt64BigToHost(hdr[0].firstBinFreq)) / 1.048576E6
      _frames[_index].binBandwidth = CGFloat(CFSwapInt64BigToHost(hdr[0].binBandwidth)) / 1.048576E6
      _frames[_index].lineDuration = Int( CFSwapInt32BigToHost(hdr[0].lineDuration) )
      _frames[_index].height = Int( CFSwapInt16BigToHost(hdr[0].height) )
      _frames[_index].autoBlackLevel = CFSwapInt32BigToHost(hdr[0].autoBlackLevel)
      
      // are we waiting for the start of a frame?
      if _expectedFrameNumber == -1 {
        // YES, is it the start of a frame?
        if _frames[_index].startingBinNumber == 0 {
          // YES, START OF A FRAME
          _expectedFrameNumber = _frames[_index].frameNumber
        } else {
          // NO, NOT THE START OF A FRAME
          return
        }
      }
      // is it the expected frame?
      if _expectedFrameNumber != _frames[_index].frameNumber {
        // NOT THE EXPECTED FRAME, wait for the next start of frame
        log("Waterfall: missing frame(s), expected = \(_expectedFrameNumber), received = \(_frames[_index].frameNumber), accumulatedBins = \(_accumulatedBins), frameBinCount = \(_frames[_index].frameBinCount)", .debug, #function, #file, #line)
        _expectedFrameNumber = -1
        _accumulatedBins = 0
//        packetErrors += 1
        return
      }
      vita.payloadData.withUnsafeBytes { ptr in
        // Swap the byte ordering of the data & place it in the bins
        for i in 0..<_frames[_index].segmentBinCount {
          _frames[_index].bins[i+_frames[_index].startingBinNumber] = CFSwapInt16BigToHost( ptr.load(fromByteOffset: byteOffsetToBins + (2 * i), as: UInt16.self) )
        }
      }
      _accumulatedBins += _frames[_index].segmentBinCount
      
      // is it a complete Frame?
      if _accumulatedBins == _frames[_index].frameBinCount {
        //        _frames[_index].frameBinCount = _accumulatedBins
        // YES, pass it to the delegate
        delegate?.streamHandler(_frames[_index])
        
        // update the expected frame number & dataframe index
        _expectedFrameNumber += 1
        _accumulatedBins = 0
        _index = (_index + 1) % WaterfallStream.kNumberOfFrames
      }
    }
  }
}

/// Class containing Waterfall Stream data
///   populated by the Waterfall vitaHandler
public struct WaterfallFrame {
  private static let kMaxBins = 4096

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var firstBinFreq: CGFloat = 0.0  // Frequency of first Bin (Hz)
  public var binBandwidth: CGFloat = 0.0  // Bandwidth of a single bin (Hz)
  public var lineDuration  = 0            // Duration of this line (ms)
  public var segmentBinCount = 0          // Number of bins
  public var height = 0                   // Height of frame (pixels)
  public var frameNumber = 0              // Time code
  public var autoBlackLevel: UInt32 = 0   // Auto black level
  public var frameBinCount = 0            //
  public var startingBinNumber = 0        //
  public var bins = [UInt16](repeating: 0, count: kMaxBins)            // Array of bin values
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a WaterfallFrame
  /// - Parameter frameSize:    max number of Waterfall samples
//  public init(frameSize: Int) {
//    // allocate the bins array
//    self.bins = [UInt16](repeating: 0, count: frameSize)
//  }
}
