//
//  CAConverter.swift
//  CAPlayer
//
//  Created by Mark Erbaugh on 3/17/22.
//

import AVFoundation

struct Settings {
    static let inputFileName = "../../../Data/output.mp3"
    static let outputFileName = "../../../Data/output.aif"
}


// MARK: user data struct
struct MyAudioConverterSettings {
    let inputFormat: AudioStreamBasicDescription
    let outputFormat: AudioStreamBasicDescription
    
    let inputFile: AudioFileID
    let outputFile: AudioFileID
    
    var inputFilePacketIndex = UInt64(0)
    let inputFilePacketCount: UInt64
    let inputFileMaxPacketSize: UInt32
    
    let inputFilePacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
    var sourceBuffer: UnsafeMutableRawPointer? = nil
}

// MARK: utility functions
// checkError in CheckError.swift
func convert(mySettings: inout MyAudioConverterSettings, outputBufferSize: UInt32, packetsPerBuffer: UInt32, audioConverter: AudioConverterRef) {
    let outBuffer: UnsafeMutableRawPointer? = malloc(Int(outputBufferSize))
    var outputFilePacketPosition = UInt32(0)
    while true {
        let buffer = AudioBuffer(mNumberChannels: mySettings.inputFormat.mChannelsPerFrame,
                                 mDataByteSize: outputBufferSize,
                                 mData: outBuffer)
        var convertedData = AudioBufferList(mNumberBuffers: 1, mBuffers: (buffer))
        var ioOutputDataPackets = packetsPerBuffer
        let error = AudioConverterFillComplexBuffer(audioConverter,
                                                    myAudioConverterCallback,
                                                    &mySettings,
                                                    &ioOutputDataPackets,
                                                    &convertedData,
                                                    mySettings.inputFilePacketDescriptions)
    }
}

// MARK: converter callback function
func myAudioConverterCallback(inAudioConverter: AudioConverterRef,
                              ioPacketCount: UnsafeMutablePointer<UInt32>,
                              ioData: UnsafeMutablePointer<AudioBufferList>,
                              outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                              inUserData: UnsafeMutableRawPointer?) -> OSStatus {
    
    return noErr
}

// MARK: - main function
func main() {
    // Open input file
    let inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.inputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    guard let inputFileURL = inputFileURL else {
        print ("Get input file URL failed.")
        return
    }
    
    var inputFile: AudioFileID? = nil
    checkError(AudioFileOpenURL(inputFileURL,
                                AudioFilePermissions.readPermission,
                                0,
                                &inputFile),
               "AudioFileOpenURL failed")

    guard let inputFile = inputFile else {
        print ("inputFile nil")
        return
    }
    defer {
        checkError(AudioFileClose(inputFile), "couldn't close input file")
    }
    
    // Get input format
    var inputFormat = AudioStreamBasicDescription()
    var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    checkError(AudioFileGetProperty(inputFile, kAudioFilePropertyDataFormat, &propSize, &inputFormat),
               "couldn't get file's data format")

    // Get the total number of packets in the file
    var inputFilePacketCount = UInt64(0)
    propSize = UInt32(MemoryLayout<UInt64>.size)
    checkError(AudioFileGetProperty(inputFile,
                                    kAudioFilePropertyAudioDataPacketCount,
                                    &propSize,
                                    &inputFilePacketCount),
               "couldn't get files' packet count")
    
    // get the size of the largest possible packet
    propSize = UInt32(MemoryLayout<UInt32>.size)
    var inputFileMaxPacketSize = UInt32(0)
    checkError(AudioFileGetProperty(inputFile,
                                    kAudioFilePropertyMaximumPacketSize,
                                    &propSize,
                                    &inputFileMaxPacketSize),
               "couldn't get file's max packet size")
    // Set up output file
    var outputFormat = AudioStreamBasicDescription(mSampleRate: 44100.0,
                                                   mFormatID: kAudioFormatLinearPCM,
                                                   mFormatFlags: kAudioFormatFlagIsBigEndian
                                                               | kAudioFormatFlagIsSignedInteger
                                                               | kAudioFormatFlagIsPacked,
                                                   mBytesPerPacket: 4,
                                                   mFramesPerPacket: 1,
                                                   mBytesPerFrame: 4,
                                                   mChannelsPerFrame: 2,
                                                   mBitsPerChannel: 16,
                                                   mReserved: 0)
    let outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.outputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    guard let outputFileURL = outputFileURL else {
        print ("get output file URL nil")
        return
    }
    var outputFile: AudioFileID? = nil
    checkError(AudioFileCreateWithURL(outputFileURL,
                                      kAudioFileAIFFType,
                                      &outputFormat,
                                      AudioFileFlags.eraseFile,
                                      &outputFile),
               "AudioFileCreateWithURL failed")
    
    guard let outputFile = outputFile else {
        print ("outputFile nil")
        return
    }
    defer {
        checkError(AudioFileClose(outputFile), "couldn't close output file")
    }

    // create the audioConverter object
    var audioConverter: AudioConverterRef?
    checkError(AudioConverterNew(&inputFormat, &outputFormat, &audioConverter),
               "AudioCoverterNew failed")
    
    guard let audioConverter = audioConverter else {
        print ("audioConverter nil")
        return
    }
    var packetsPerBuffer = UInt32(0)
    var outputBufferSize = UInt32(32 * 1024)
    var sizePerPacket = inputFormat.mBytesPerPacket
    if sizePerPacket == 0 {
        var size = UInt32(MemoryLayout<UInt32>.size)
        checkError(AudioConverterGetProperty(audioConverter,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &size,
                                             &sizePerPacket),
                   "Couldn't get kAudioConverterPropertyMaximumOutputPacketSize")
        if sizePerPacket > outputBufferSize {
            outputBufferSize = sizePerPacket
        }
        packetsPerBuffer = outputBufferSize / sizePerPacket
    } else {
        packetsPerBuffer = outputBufferSize / sizePerPacket
    }
    let inputFilePacketDescriptions:  UnsafeMutablePointer<AudioStreamPacketDescription>? = sizePerPacket == 0
      ? .allocate(capacity: Int(packetsPerBuffer))
      : nil
    
    let mySettings = MyAudioConverterSettings(inputFormat: inputFormat,
                                              outputFormat: outputFormat,
                                              inputFile: inputFile,
                                              outputFile: outputFile,
                                              inputFilePacketCount: inputFilePacketCount,
                                              inputFileMaxPacketSize: inputFileMaxPacketSize,
                                              inputFilePacketDescriptions: inputFilePacketDescriptions)
    
    // Perform conversion
    print("Converting")
    convert(mySettings: mySettings,
            outputBufferSize: outputBufferSize,
            packetsPerBuffer: packetsPerBuffer,
            audioConverter: audioConverter)
}
