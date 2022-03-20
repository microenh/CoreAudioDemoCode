//
//  CAStreamFormatTester.swift
//  CAStreamFormatTester
//
//  Created by Mark Erbaugh on 3/13/22.
//

import Foundation
import AVFoundation

func main() throws {
    
    var fileTypeAndFormat = AudioFileTypeAndFormatID(mFileType: kAudioFileCAFType, // kAudioFileWAVEType, // kAudioFileAIFFType,
                                                     mFormatID: kAudioFormatLinearPCM)
    
    var audioErr = noErr
    var infoSize = UInt32(0)
    
    audioErr = AudioFileGetGlobalInfoSize(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                          UInt32(MemoryLayout<AudioFileTypeAndFormatID>.size),
                                          &fileTypeAndFormat,
                                          &infoSize)
    
    guard audioErr == noErr else {
        print ("Error \(audioErr) getting size.")
        return
    }
    
    let asbdPtr = malloc(Int(infoSize))
    
    guard let asbdPtr = asbdPtr else {
        print ("malloc failed.")
        return
    }
    
    audioErr = AudioFileGetGlobalInfo(kAudioFileGlobalInfo_AvailableStreamDescriptionsForFormat,
                                      UInt32(MemoryLayout.size(ofValue: fileTypeAndFormat)),
                                      &fileTypeAndFormat,
                                      &infoSize,
                                      asbdPtr)
    
    guard audioErr == noErr else {
        print ("Error \(audioErr) getting info.")
        return
    }
    
    var asbds = [AudioStreamBasicDescription]()
    let asbdSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    var offset = 0
    for _ in 0..<(infoSize / asbdSize) {
        let asbd = asbdPtr.advanced(by: offset).load(as: AudioStreamBasicDescription.self)
        asbds.append(asbd)
        offset += Int(asbdSize)
    }
    asbdPtr.deallocate()

    for asbd in asbds {
        print (asbd.desc)
    }
}

extension AudioStreamBasicDescription {
    var fmt: String {
        let data = Swift.withUnsafeBytes(of: self.mFormatID.bigEndian) { Data($0) }
        return String(decoding: data, as: UTF8.self)
    }
    var desc: String {
        "Format: \(self.fmt) Flags: \(self.mFormatFlags) BitsPerChannel: \(self.mBitsPerChannel)"
    }
}
