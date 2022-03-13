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
    static let filenameFormat = "%0.1f-square.wav"
    // static let filenameFormat = "%0.1f-saw.aif"
    // static let filenameFormat = "%0.1f-sine.aif"
}

func main() {
    guard CommandLine.argc > 1 else {
        print("Usage: \(CommandLine.arguments[0]) n")
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
    let wavelengthInSamples = Int(Settings.sampleRate / hz)
    var bytesToWrite = UInt32(wavelengthInSamples * 2)

    var wave = (0..<wavelengthInSamples)
        .map{ square(value: $0, wavelengthInSamples: wavelengthInSamples) }
        // .map { saw(value: $0, wavelengthInSamples: wavelengthInSamples) }
        // .map { sine(value: $0, wavelengthInSamples: wavelengthInSamples) }
 
    while sampleCount < maxSampleCount {
        audioErr = AudioFileWriteBytes(audioFile, false, sampleCount * 2, &bytesToWrite, &wave)
        guard audioErr == noErr else {
            print ("Error \(audioErr) writing file.")
            return
        }
        sampleCount += Int64(wavelengthInSamples)
    }
    audioErr = AudioFileClose(audioFile)
    guard audioErr == noErr else {
        print ("Error closing file.")
        return
    }
    print ("Wrote \(sampleCount) samples.")
    return
}

func saw(value: Int, wavelengthInSamples: Int) -> Int16 {
    Int16((Double(value) * 2 * Double(Int16.max) / Double(wavelengthInSamples)) - Double(Int16.max)).bigEndian
}

func sine(value: Int, wavelengthInSamples: Int) -> Int16 {
    Int16(Double(Int16.max) * sin(2 * Double.pi * Double(value) / Double(wavelengthInSamples))).bigEndian
}

func square(value: Int, wavelengthInSamples: Int) -> Int16 {
    (value < wavelengthInSamples / 2 ? Int16.max : Int16.min).bigEndian
}

