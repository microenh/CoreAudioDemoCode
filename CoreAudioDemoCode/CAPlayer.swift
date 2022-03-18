//
//  CAPlayer.swift
//  CAPlayer
//
//  Created by Mark Erbaugh on 3/15/22.
//

import AVFoundation

// MARK: Global Constants
struct Settings {
    static let fileName = "../../../Data/output.mp3"
    static let duration = Float64(1.0)
    static let numberPlaybackBuffers = 2
}

// MARK: User Data Struct
struct MyPlayer {
    var playbackFile: AudioFileID?
    var packetPosition: Int64
    var numPacketsToRead: UInt32
    var packetDescs: UnsafeMutablePointer<AudioStreamPacketDescription>?
    var bufferByteSize: UInt32  // added: needed for call to AudioFileReadPacketData
    var isDone: Bool
    var bufferDone = false  // added: report when all buffers played
}

// MARK: Utility Functions
// checkError in CheckError.swift
func calculateBytesForTime(inAudioFile: AudioFileID,
                           inDesc: AudioStreamBasicDescription,
                           inSeconds: Float64) -> (outBufferSize: UInt32, outNumPackets: UInt32) {

    var outBufferSize: UInt32
    var maxPacketSize = UInt32(0)
    var propSize = UInt32(MemoryLayout<UInt32>.size)
    
    checkError(AudioFileGetProperty(inAudioFile,
                                    kAudioFilePropertyPacketSizeUpperBound,
                                    &propSize,
                                    &maxPacketSize),
               "Couldn't get file's max packet size")
    
    let maxBufferSize = UInt32(0x10000)
    let minBufferSize = UInt32(0x4000)
    
    if inDesc.mFramesPerPacket > 0 {
        let numPacketsForTime = inDesc.mSampleRate /
                                Float64(inDesc.mFramesPerPacket) * inSeconds
        outBufferSize = UInt32(numPacketsForTime) * maxPacketSize
    } else {
        outBufferSize = max(maxBufferSize, maxPacketSize)
    }
    if outBufferSize > max(maxBufferSize, maxPacketSize) {
        outBufferSize = maxBufferSize
    } else {
        if outBufferSize < minBufferSize {
            outBufferSize = minBufferSize
        }
    }
    return (outBufferSize, outBufferSize / maxPacketSize)
}

func myCopyEncoderCookieToQueue(theFile: AudioFileID, queue: AudioQueueRef) {
    var propertySize = UInt32(0)
    let result = AudioFileGetPropertyInfo(theFile, kAudioFilePropertyMagicCookieData, &propertySize, nil)
    guard result == noErr && propertySize > 0 else { return }
    
    let magicCookie = malloc(Int(propertySize))
    guard let magicCookie = magicCookie else {
        print ("malloc magicCookie failed")
        return
    }

    checkError(AudioFileGetProperty(theFile,
                                    kAudioFilePropertyMagicCookieData,
                                    &propertySize,
                                    magicCookie),
               "Get cookie from file failed")
    checkError(AudioQueueSetProperty(queue,
                                     kAudioQueueProperty_MagicCookie,
                                     magicCookie,
                                     propertySize),
               "Set cookie on queue failed")
    free(magicCookie)
}

// MARK: Player Callback Function
func myAQOutputCallback(inUserData: UnsafeMutableRawPointer?,
                        inAQ: AudioQueueRef,
                        inCompleteAQBuffer: AudioQueueBufferRef) {
    
    let aqp = inUserData?.assumingMemoryBound(to: MyPlayer.self)
    
    guard let aqp = aqp, !aqp.pointee.isDone else { return }

    // (-50) AVAudioSessionErrorCodeBadParam
    
    // 2022-03-15 21:05:10.563094-0400 CAPlayer[20364:2121326] [aqme]        MEMixerChannel.cpp:1639  client <AudioQueueObject@0x106808200;
    // [0]; play> got error 2003332927 while sending format information  (who?) kAudioCodecUnknownPropertyError
    // original code generating same message
    
    var bufferByteSize = aqp.pointee.bufferByteSize
    
    checkError(AudioFileReadPacketData(aqp.pointee.playbackFile!,
                                      false,
                                      &bufferByteSize,
                                      aqp.pointee.packetDescs,
                                      aqp.pointee.packetPosition,
                                      &aqp.pointee.numPacketsToRead,
                                      inCompleteAQBuffer.pointee.mAudioData), "AudioFileReadPacketData failed")

    if aqp.pointee.numPacketsToRead > 0 {
        inCompleteAQBuffer.pointee.mAudioDataByteSize = aqp.pointee.bufferByteSize
        AudioQueueEnqueueBuffer(inAQ,
                                inCompleteAQBuffer,
                                aqp.pointee.numPacketsToRead,
                                aqp.pointee.packetDescs)
        aqp.pointee.packetPosition += Int64(aqp.pointee.numPacketsToRead)
    } else {
        checkError((AudioQueueStop(inAQ, false)), "AudioQueueStop failed")
        aqp.pointee.isDone = true
    }
    
}

// MARK: QueuePropertyListener
func queuePropertyListener(inUserData: UnsafeMutableRawPointer?,
                           inAQ: AudioQueueRef,
                           propertyID: AudioQueuePropertyID) {
    var running = UInt32(0)
    var propSize = UInt32(0)
    
    checkError(AudioQueueGetProperty(inAQ, propertyID, &running, &propSize),
               "AudioQueueGetProperty failed")
    
    if running == 0 {
        let aqp = inUserData?.assumingMemoryBound(to: MyPlayer.self)
        if let aqp = aqp {
            aqp.pointee.bufferDone = true
        }
    }
    
}

// MARK: - Main Function
func main () {
    let myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                  Settings.fileName as CFString,
                                                  CFURLPathStyle.cfurlposixPathStyle,
                                                  false)
    
    guard let myFileURL = myFileURL else {
        print ("Get file URL failed.")
        return
    }
    
    var playbackFile: AudioFileID? = nil
    
    checkError(AudioFileOpenURL(myFileURL,
                                AudioFilePermissions.readPermission,
                                0,
                                &playbackFile),
               "AudilFileOpenURL failed")
    
    var dataFormat = AudioStreamBasicDescription()
    var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
    checkError(AudioFileGetProperty(playbackFile!,
                                    kAudioFilePropertyDataFormat,
                                    &propSize,
                                    &dataFormat),
               "Couldn't get file's data format.")
    
    let result = calculateBytesForTime(inAudioFile: playbackFile!,
                                       inDesc: dataFormat,
                                       inSeconds: Settings.duration)
    
    let bufferByteSize = result.outBufferSize
    let numPacketsToRead = result.outNumPackets
    
    let packetDescs : UnsafeMutablePointer<AudioStreamPacketDescription>? = dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket == 0
        ? .allocate(capacity: Int(numPacketsToRead))
        : nil
    
    var player = MyPlayer(playbackFile: playbackFile!,
                          packetPosition: 0,
                          numPacketsToRead: numPacketsToRead,
                          packetDescs: packetDescs,
                          bufferByteSize: bufferByteSize,
                          isDone: false)

    var queue: AudioQueueRef?
    
    checkError(AudioQueueNewOutput(&dataFormat,
                                   myAQOutputCallback,
                                   &player,
                                   nil,
                                   nil,
                                   0,
                                   &queue),
               "AudioQueueNewOutput failed")
    
    guard let queue = queue else {
        return
    }
    
    myCopyEncoderCookieToQueue(theFile: playbackFile!, queue: queue)
    
    player.isDone = false
    player.packetPosition = 0
    
    for _ in 0..<Settings.numberPlaybackBuffers {
        var buffer: AudioQueueBufferRef?
        checkError(AudioQueueAllocateBuffer(queue, bufferByteSize, &buffer),
                   "AudioQueueAllocateBuffer failed")
        guard let buffer = buffer else {
            print ("buffer nil")
            return
        }
        myAQOutputCallback(inUserData: &player, inAQ: queue, inCompleteAQBuffer: buffer)
        if player.isDone {
            break
        }
    }
    checkError(AudioQueueAddPropertyListener(queue, kAudioQueueProperty_IsRunning, queuePropertyListener, &player),
               "AudioQueueAddPropertyListener failed")
    checkError(AudioQueueStart(queue, nil), "AudioQueueStart failed")
    print ("Playing...")
    repeat {
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, 0.25, false)
    } while !player.bufferDone
    
    checkError((AudioQueueDispose(queue, true)), "AudioQueueDispose failed")
    checkError(AudioFileClose(player.playbackFile!), "AudioFileClose failed")
}
