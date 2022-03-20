//
//  CAConverter.swift
//  CAPlayer
//
//  Created by Mark Erbaugh on 3/17/22.
//

import AVFoundation

struct Settings {
    static let inputFileName = "/Users/mark/Documents/CASoundFiles/output.mp3"
    static let outputFileName = "/Users/mark/Documents/CASoundFiles/output.aif"
    static let outputSampleRate = Float64(6000)
    static let outputChannels = UInt32(1)
    static let outputBytesPerSample = UInt32(1)
}

// MARK: user data struct
struct MyAudioConverterSettings {
    var inputFormat = AudioStreamBasicDescription()
    // var outputFormat = AudioStreamBasicDescription()
    
    // define the ouput format. AudioConverter requires that one of the data formats be LPCM
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
    
    var inputFile: AudioFileID!
    var outputFile: AudioFileID!
    
    var inputFilePacketIndex = UInt64(0)
    var inputFilePacketCount = UInt64(0)
    var inputFileMaxPacketSize = UInt32(0)
    
    var inputFilePacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?
}

// MARK: utility functions
// checkError in CheckError.swift
func convert(mySettings: inout MyAudioConverterSettings) {
    // create the audioConverter object
    var audioConverter: AudioConverterRef?
    checkError(AudioConverterNew(&mySettings.inputFormat,
                                 &mySettings.outputFormat,
                                 &audioConverter),
               "AudioCoverterNew failed")
    var packetsPerBuffer = UInt32(0)
    var outputBufferSize = UInt32(32 * 1024)
    var sizePerPacket = mySettings.inputFormat.mBytesPerPacket
    if sizePerPacket == 0 {
        var size = UInt32(MemoryLayout<UInt32>.size)
        checkError(AudioConverterGetProperty(audioConverter!,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &size,
                                             &sizePerPacket),
                   "Couldn't get kAudioConverterPropertyMaximumOutputPacketSize")
        if sizePerPacket > outputBufferSize {
            outputBufferSize = sizePerPacket
        }
        packetsPerBuffer = outputBufferSize / sizePerPacket
        mySettings.inputFilePacketDescriptions = .allocate(capacity: Int(packetsPerBuffer))
    } else {
        packetsPerBuffer = outputBufferSize / sizePerPacket
    }
    
    let outputBuffer /* : UnsafeMutableRawPointer? */ = malloc(Int(outputBufferSize))
    var outputFilePacketPosition = UInt32(0)

    while true {
        let buffer = AudioBuffer(mNumberChannels: mySettings.inputFormat.mChannelsPerFrame,
                                 mDataByteSize: outputBufferSize,
                                 mData: outputBuffer)
        var convertedData = AudioBufferList(mNumberBuffers: 1, mBuffers: (buffer))
        var ioOutputDataPackets = packetsPerBuffer
        let error = AudioConverterFillComplexBuffer(audioConverter!,
                                                    myAudioConverterCallback,
                                                    &mySettings,
                                                    &ioOutputDataPackets,
                                                    &convertedData,
                                                    mySettings.inputFilePacketDescriptions)
        if error != 0 || ioOutputDataPackets == 0 {
            break
        }
        checkError(AudioFileWritePackets(mySettings.outputFile,
                                         false,
                                         ioOutputDataPackets * mySettings.outputFormat.mBytesPerPacket,
                                         nil,
                                         Int64(outputFilePacketPosition / mySettings.outputFormat.mBytesPerPacket),
                                         &ioOutputDataPackets,
                                         convertedData.mBuffers.mData!),
                   "Couldn't write packets to file")
        outputFilePacketPosition += ioOutputDataPackets * mySettings.outputFormat.mBytesPerPacket
    }
    AudioConverterDispose(audioConverter!)
    free (outputBuffer)
}

// MARK: converter callback function
func myAudioConverterCallback(inAudioConverter: AudioConverterRef,
                              ioDataPacketCount: UnsafeMutablePointer<UInt32>,
                              ioData: UnsafeMutablePointer<AudioBufferList>,
                              outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                              inUserData: UnsafeMutableRawPointer?) -> OSStatus {
    
    
    let audioConverterSettings = inUserData?.assumingMemoryBound(to: MyAudioConverterSettings.self)
    guard let audioConverterSettings = audioConverterSettings else {
        print ("nil audioConverterSettings")
        return -50
    }
    
    ioData.pointee.mBuffers.mData = nil
    ioData.pointee.mBuffers.mDataByteSize = 0
    
    // If there are not enough packets to satisfy request, then read what's left
    if audioConverterSettings.pointee.inputFilePacketIndex + UInt64(ioDataPacketCount.pointee) > audioConverterSettings.pointee.inputFilePacketCount {
        ioDataPacketCount.pointee = UInt32(audioConverterSettings.pointee.inputFilePacketCount - audioConverterSettings.pointee.inputFilePacketIndex)
    }
    if ioDataPacketCount.pointee == 0 {
        return noErr
    }
    
    var outByteCount = UInt32(Int(ioDataPacketCount.pointee * audioConverterSettings.pointee.inputFileMaxPacketSize))
    let sourceBuffer = calloc(1, Int(outByteCount))
    defer {
        free(sourceBuffer)
    }
    var result = AudioFileReadPacketData(audioConverterSettings.pointee.inputFile,
                                         true,
                                         &outByteCount,
                                         audioConverterSettings.pointee.inputFilePacketDescriptions,
                                         Int64(audioConverterSettings.pointee.inputFilePacketIndex),
                                         ioDataPacketCount,
                                         sourceBuffer)
    if result == kAudioFileEndOfFileError && ioDataPacketCount.pointee > 0 {
        result = noErr
    } else {
        if result != noErr {
            return result
        }
    }
    audioConverterSettings.pointee.inputFilePacketIndex += UInt64(ioDataPacketCount.pointee)
    ioData.pointee.mBuffers.mData = sourceBuffer
    ioData.pointee.mBuffers.mDataByteSize = outByteCount
    if outDataPacketDescription != nil {
        outDataPacketDescription!.pointee = audioConverterSettings.pointee.inputFilePacketDescriptions
    }
    return result
}

// MARK: - main function
func main() throws {
    // Open input file
    var audioConverterSettings = MyAudioConverterSettings()
    let inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.inputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    guard let inputFileURL = inputFileURL else {
        print ("Get input file URL failed.")
        return
    }
    
    checkError(AudioFileOpenURL(inputFileURL,
                                AudioFilePermissions.readPermission,
                                0,
                                &audioConverterSettings.inputFile),
               "AudioFileOpenURL failed")

    defer {
        checkError(AudioFileClose(audioConverterSettings.inputFile), "couldn't close input file")
    }
    
    // Get input format
    var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    checkError(AudioFileGetProperty(audioConverterSettings.inputFile,
                                    kAudioFilePropertyDataFormat,
                                    &propSize,
                                    &audioConverterSettings.inputFormat),
               "couldn't get file's data format")

    // Get the total number of packets in the file
    propSize = UInt32(MemoryLayout<UInt64>.size)
    checkError(AudioFileGetProperty(audioConverterSettings.inputFile,
                                    kAudioFilePropertyAudioDataPacketCount,
                                    &propSize,
                                    &audioConverterSettings.inputFilePacketCount),
               "couldn't get files' packet count")
    
    // get the size of the largest possible packet
    propSize = UInt32(MemoryLayout<UInt32>.size)
    checkError(AudioFileGetProperty(audioConverterSettings.inputFile,
                                    kAudioFilePropertyMaximumPacketSize,
                                    &propSize,
                                    &audioConverterSettings.inputFileMaxPacketSize),
               "couldn't get file's max packet size")
    // Set up output file
    
    // define the ouput format. AudioConverter requires that one of the data formats be LPCM
//    audioConverterSettings.outputFormat.mSampleRate = 8000.0;
//    audioConverterSettings.outputFormat.mFormatID = kAudioFormatLinearPCM;
//    audioConverterSettings.outputFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
//    audioConverterSettings.outputFormat.mBytesPerPacket = 4;
//    audioConverterSettings.outputFormat.mFramesPerPacket = 1;
//    audioConverterSettings.outputFormat.mBytesPerFrame = 4;
//    audioConverterSettings.outputFormat.mChannelsPerFrame = 2;
//    audioConverterSettings.outputFormat.mBitsPerChannel = 16;

    
    let outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.outputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    guard let outputFileURL = outputFileURL else {
        print ("get output file URL nil")
        return
    }
    checkError(AudioFileCreateWithURL(outputFileURL,
                                      kAudioFileAIFFType,
                                      &audioConverterSettings.outputFormat,
                                      AudioFileFlags.eraseFile,
                                      &audioConverterSettings.outputFile),
               "AudioFileCreateWithURL failed")
    
    defer {
        checkError(AudioFileClose(audioConverterSettings.outputFile), "couldn't close output file")
    }
    // Perform conversion
    print("Converting")
    defer {
        print ("Done")
    }
    convert(mySettings: &audioConverterSettings)
}
