//
//  CAToneFileGenerator.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/12/22.
//

import Foundation
import AVFoundation

fileprivate struct Settings {
    static let sampleRate = Float64(44100)
    static let duration = 5.0
    static let filenameFormat = "%0.1f-square.aif"
}

func caToneFileGenerator() {
    guard CommandLine.argc > 1 else {
        print("Usage: CoreAudioDemoCode n")
        print("(where n in tone in Hz)")
        return
    }
    
    let hz = Double(CommandLine.arguments[1])
    
    guard let hz = hz else {
        print ("\"\(CommandLine.arguments[1])\" is not a valid frequency.")
        return
        
    }
    
    print ("Generating \(hz) hz tone.")
    
    let fileName = String(format: Settings.filenameFormat, hz)
    
    let fileURL = NSURL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(fileName)
    
    guard let fileURL = fileURL else {
        print ("Failed creating file URL.")
        return
    }

    var asbd = AudioStreamBasicDescription(mSampleRate: Settings.sampleRate,
                                           mFormatID: kAudioFormatLinearPCM,
                                           mFormatFlags: kAudioFormatFlagIsBigEndian
                                                         | kAudioFormatFlagIsSignedInteger
                                                         | kAudioFormatFlagIsPacked,
                                           mBytesPerPacket: 2,
                                           mFramesPerPacket: 1,
                                           mBytesPerFrame: 2,
                                           mChannelsPerFrame: 1,
                                           mBitsPerChannel: 16,
                                           mReserved: 0)
    
    
    var audioFile: AudioFileID?
    var audioErr = noErr
    
    audioErr = AudioFileCreateWithURL(fileURL as CFURL,
                                      kAudioFileAIFFType,
                                      &asbd,
                                      AudioFileFlags.eraseFile,
                                      &audioFile)
    
    guard audioErr == noErr, let audioFile = audioFile else {
        print ("Error \(audioErr) creating file.")
        return
    }
    
    // Start writing samples
    let maxSampleCount = Int(Settings.sampleRate) * Int(Settings.duration)
    var sampleCount = Int64(0)
    var bytesToWrite = UInt32(2)
    let wavelengthInSamples = Int(Settings.sampleRate / hz)
    
    while sampleCount < maxSampleCount {
        for i in 0..<wavelengthInSamples {
            var sample = i < wavelengthInSamples / 2 ? Int16.max : Int16.min
            audioErr = AudioFileWriteBytes(audioFile, false, sampleCount * 2, &bytesToWrite, &sample)
            guard audioErr == noErr else {
                print ("Error \(audioErr) writing file.")
                return
            }
            sampleCount += 1
        }
    }
    audioErr = AudioFileClose(audioFile)
    guard audioErr == noErr else {
        print ("Error closing file.")
        return
    }
    print ("Wrote \(sampleCount) samples.")
    return
}
