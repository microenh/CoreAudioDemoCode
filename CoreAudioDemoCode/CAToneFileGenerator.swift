//
//  CAToneFileGenerator.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/12/22.
//

import Foundation
import AVFoundation

fileprivate struct Settings {
    static let sampleRate = Float64(8000)
    static let duration = 5.0
    // static let filenameFormat = "%0.1f-%d-square.caf"
    // static let filenameFormat = "%0.1f-%d-saw.caf"
    static let filenameFormat = "%0.1f-%d-sine.wav"
    static let bytesPerFrame = UInt32(2)
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
    
    let nco = NCOCosine(frequency: Double(hz), sampleRate: Double(Settings.sampleRate))
    
    print ("Generating \(hz) hz tone.")
    
    let fileName = String(format: Settings.filenameFormat, hz, Settings.bytesPerFrame * 8)
    
    let fileURL = NSURL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(fileName)
    
    guard let fileURL = fileURL else {
        print ("Failed creating file URL.")
        return
    }

    var asbd = AudioStreamBasicDescription(mSampleRate: Settings.sampleRate,
                                           mFormatID: kAudioFormatLinearPCM,
                                           mFormatFlags: /* kAudioFormatFlagIsBigEndian
                                                         | */ kAudioFormatFlagIsSignedInteger
                                                         | kAudioFormatFlagIsPacked,
                                           mBytesPerPacket: Settings.bytesPerFrame,
                                           mFramesPerPacket: 1,
                                           mBytesPerFrame: Settings.bytesPerFrame,
                                           mChannelsPerFrame: 1,
                                           mBitsPerChannel: Settings.bytesPerFrame * 8,
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
    let maxSampleCount = Int64(Settings.sampleRate) * Int64(Settings.duration)
    var sampleCount = Int64(0)
    let wavelengthInSamples = Int64(Settings.sampleRate / hz)
    var samplesToWrite = wavelengthInSamples

    var wave = (0..<wavelengthInSamples)
        // .map { square(value: $0, wavelengthInSamples: wavelengthInSamples) }
        // .map { saw(value: $0, wavelengthInSamples: wavelengthInSamples) }
        // .map { sine16(value: $0, wavelengthInSamples: wavelengthInSamples) }
        // .map { _ in nco.value8 }
        .map { _ in nco.value16.bigEndian }

    while sampleCount < maxSampleCount {
        if sampleCount + wavelengthInSamples >= maxSampleCount {
            samplesToWrite = Int64(maxSampleCount - sampleCount)
        }
        var bytesToWrite = UInt32(samplesToWrite) * UInt32(Settings.bytesPerFrame)
        audioErr = AudioFileWriteBytes(audioFile, false, sampleCount * Int64(Settings.bytesPerFrame), &bytesToWrite, &wave)
        guard audioErr == noErr else {
            print ("Error \(audioErr) writing file.")
            return
        }
        sampleCount += samplesToWrite
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

func square(value: Int, wavelengthInSamples: Int) -> Int16 {
    (value < wavelengthInSamples / 2 ? Int16.max : Int16.min).bigEndian
}

func sine16(value: Int, wavelengthInSamples: Int) -> Int16 {
    Int16(Double(Int16.max) * sin(2 * Double.pi * Double(value) / Double(wavelengthInSamples))).bigEndian
}

func sine8(value: Int, wavelengthInSamples: Int) -> Int8 {
    Int8(Double(Int8.max) * sin(2 * Double.pi * Double(value) / Double(wavelengthInSamples)))
}

