//
//  CAConverterExtended.swift
//  CAConverterExtended
//
//  Created by Mark Erbaugh on 3/20/22.
//

import Foundation
import CoreAudioTypes
import AudioToolbox

struct Settings {
    static let inputFileName = "/Users/mark/Documents/CASoundFiles/output.mp3"
    static let outputFileName = "/Users/mark/Documents/CASoundFiles/output.aif"
    static let outputSampleRate = Float64(6000)
    static let outputChannels = UInt32(1)
    static let outputBytesPerSample = UInt32(1)
}

// MARK: User data struct
struct MyAudioConverterSettings {
    var outputFormat = AudioStreamBasicDescription(mSampleRate: Settings.outputSampleRate,
                                                   mFormatID: kAudioFormatLinearPCM,
                                                   mFormatFlags: kAudioFormatFlagIsBigEndian
                                                   | kAudioFormatFlagIsSignedInteger
                                                   | kAudioFormatFlagIsPacked,
                                                   mBytesPerPacket: Settings.outputBytesPerSample * Settings.outputChannels,
                                                   mFramesPerPacket: 1,
                                                   mBytesPerFrame: Settings.outputBytesPerSample * Settings.outputChannels,
                                                   mChannelsPerFrame: Settings.outputChannels,
                                                   mBitsPerChannel: Settings.outputBytesPerSample * 8,
                                                   mReserved: 0)
    var inputFile: ExtAudioFileRef!
    var outputFile: AudioFileID!
}

// MARK: Utility functions
// throwIfError in CheckError.swift
func convert(_ mySettings: inout MyAudioConverterSettings) throws {
    let outputBufferSize = UInt32(32 * 1024)
    let sizePerPacket = mySettings.outputFormat.mBytesPerPacket
    let packetsPerBuffer = outputBufferSize / sizePerPacket
    let outputBuffer = malloc(Int(outputBufferSize))
    var outputFilePacketPosition = UInt32(0)
    
    while (true) {
        let buffer = AudioBuffer(mNumberChannels: mySettings.outputFormat.mChannelsPerFrame,
                                 mDataByteSize: outputBufferSize,
                                 mData: outputBuffer)
        var convertedData = AudioBufferList(mNumberBuffers: 1, mBuffers: (buffer))
        var frameCount = packetsPerBuffer
        try throwIfError(ExtAudioFileRead(mySettings.inputFile,
                                          &frameCount,
                                          &convertedData),
                         "ExtAudioFileRead")
        if (frameCount == 0) {
            // print ("Done reading file")
            return
        }
        try throwIfError(AudioFileWritePackets(mySettings.outputFile,
                                               false,
                                               frameCount,
                                               nil,
                                               Int64(outputFilePacketPosition / mySettings.outputFormat.mBytesPerPacket),
                                               &frameCount,
                                               convertedData.mBuffers.mData!),
                         "AudioFileWritePackets")
        outputFilePacketPosition += (frameCount * mySettings.outputFormat.mBytesPerPacket)
    }
}

// MARK: - Main function
func main() throws {
    var audioConverterSettings = MyAudioConverterSettings()
    
    // Open input file
    let inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.inputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    try throwIfError(ExtAudioFileOpenURL(inputFileURL!,
                                         &audioConverterSettings.inputFile),
                     "ExtAudioFileOpenURL")
    defer {
        ExtAudioFileDispose(audioConverterSettings.inputFile)
    }
    
    let outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                      Settings.outputFileName as CFString,
                                                      CFURLPathStyle.cfurlposixPathStyle,
                                                      false)
    
    try throwIfError(AudioFileCreateWithURL(outputFileURL!,
                                            kAudioFileAIFFType,
                                            &audioConverterSettings.outputFormat,
                                            AudioFileFlags.eraseFile,
                                            &audioConverterSettings.outputFile),
                     "AudioFileCreateWithURL")
    defer {
        AudioFileClose(audioConverterSettings.outputFile)
    }
    
    try throwIfError(ExtAudioFileSetProperty(audioConverterSettings.inputFile,
                                             kExtAudioFileProperty_ClientDataFormat,
                                             UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                             &audioConverterSettings.outputFormat),
                     "ExtAudioFileSetProperty")
    print ("Converting")
    defer {
        print ("Done")
    }
    try convert(&audioConverterSettings)
}
