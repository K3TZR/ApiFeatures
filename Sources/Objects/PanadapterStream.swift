//
//  PanadapterStream.swift
//  
//
//  Created by Douglas Adams on 9/22/22.
//
import Foundation

import Shared

public final class PanadapterStream: Identifiable {
  // ------------------------------------------------------------------------------
  // MARK: - Initialization
  
  public init(_ id: PanadapterId) {
    self.id = id
  }

  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var delegate: StreamHandler?
  public let id: PanadapterId

  // ----------------------------------------------------------------------------
  // MARK: - Private properties
  
  private static let kNumberOfFrames = 16

  private struct PayloadHeader {      // struct to mimic payload layout
    var startingBinNumber: UInt16
    var segmentBinCount: UInt16
    var binSize: UInt16
    var frameBinCount: UInt16
    var frameNumber: UInt32
  }
  
  private var _accumulatedBins = 0
  private var _droppedPackets = 0
  private var _expectedFrameNumber = -1
  private var _frames = [PanadapterFrame](repeating: PanadapterFrame(), count: kNumberOfFrames)
  private var _index: Int = 0
  private var _isStreaming = false
  
  // ----------------------------------------------------------------------------
  // MARK: - Public methods
  
  /// Process the Panadapter Vita struct
  ///      The payload of the incoming Vita struct is converted to a PanadapterFrame and
  ///      passed to the Panadapter Stream Handler
  ///
  /// - Parameters:
  ///   - vita:        a Vita struct
  public func vitaProcessor(_ vita: Vita) {
    if _isStreaming == false {
      _isStreaming = true
      
      // log the start of the stream
      log("Panadapter \(vita.streamId.hex) stream: STARTED", .info, #function, #file, #line)
      
      Task {
        await ApiModel.shared.panadapters[id: vita.streamId]?.setIsStreaming()
      }
    }
    
    // Bins are just beyond the payload
    let byteOffsetToBins = MemoryLayout<PayloadHeader>.size
    
    vita.payloadData.withUnsafeBytes { ptr in
      // map the payload to the Payload struct
      let hdr = ptr.bindMemory(to: PayloadHeader.self)

      _frames[_index].startingBinNumber = Int(CFSwapInt16BigToHost(hdr[0].startingBinNumber))
      _frames[_index].segmentBinCount = Int(CFSwapInt16BigToHost(hdr[0].segmentBinCount))
      _frames[_index].binSize = Int(CFSwapInt16BigToHost(hdr[0].binSize))
      _frames[_index].frameBinCount = Int(CFSwapInt16BigToHost(hdr[0].frameBinCount))
      _frames[_index].frameNumber = Int(CFSwapInt32BigToHost(hdr[0].frameNumber))

      // validate the packet (could be incomplete at startup)
      if _frames[_index].frameBinCount == 0 { return }
      if _frames[_index].startingBinNumber + _frames[_index].segmentBinCount > _frames[_index].frameBinCount { return }
      
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
        log("Panadapter: missing frame(s), expected = \(_expectedFrameNumber), received = \(_frames[_index].frameNumber), acccumulatedBins = \(_accumulatedBins), frameBinCount = \(_frames[_index].frameBinCount)", .debug, #function, #file, #line)
        _expectedFrameNumber = -1
        _accumulatedBins = 0
        Task {
          await MainActor.run { StreamModel.shared.streamStatus[id: vita.classCode]?.errors += 1 }
        }
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
        // YES, pass it to the delegate
        delegate?.streamHandler(_frames[_index])
        
        // update the expected frame number & dataframe index
        _expectedFrameNumber += 1
        _accumulatedBins = 0
        _index = (_index + 1) % PanadapterStream.kNumberOfFrames
      }
    }
  }
}

/// Class containing Panadapter Stream data
///   populated by the Panadapter vitaHandler
public struct PanadapterFrame {
  private static let kMaxBins = 5120
  
  // ----------------------------------------------------------------------------
  // MARK: - Public properties
  
  public var startingBinNumber = 0     // Index of first bin
  public var segmentBinCount = 0       // Number of bins
  public var binSize = 0               // Bin size in bytes
  public var frameBinCount = 0         // number of bins in the complete frame
  public var frameNumber = 0           // Frame number
  public var bins = [UInt16](repeating: 0, count: kMaxBins)         // Array of bin values
  
  // ----------------------------------------------------------------------------
  // MARK: - Initialization
  
  /// Initialize a PanadapterFrame
  /// - Parameter frameSize:    max number of Panadapter samples
//  public init(frameSize: Int) {
//    // allocate the bins array
//    self.bins = [UInt16](repeating: 0, count: frameSize)
//  }
}
