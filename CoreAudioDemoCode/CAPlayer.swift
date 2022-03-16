//
//  CAPlayer.swift
//  CAPlayer
//
//  Created by Mark Erbaugh on 3/15/22.
//

import AVFoundation

// MARK: Global Constants
struct Settings {
    static let fileName = "output.caf"
    static let duration = Float64(0.5)
    static let numberPlaybackBuffers = 3
}

// MARK: User Data Struct
struct MyPlayer {
    var playbackFile: AudioFileID?
    var packetPosition: Int64
    var numPacketsToRead: UInt32
    var packetDescs: UnsafeMutablePointer<AudioStreamPacketDescription>?
    var bufferByteSize: UInt32
    var isDone: Bool
}

// MARK: Utility Functions
// checkError in CheckError.swift
func calculateBytesForTime(inAudioFile: AudioFileID,
                           inDesc: AudioStreamBasicDescription,
                           inSeconds: Float64,
                           outBufferSize: inout UInt32,
                           outNumPackets: inout UInt32) {
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
        let numPacketsForTime = UInt32(inDesc.mSampleRate /
                                Float64(inDesc.mFramesPerPacket) * inSeconds)
        outBufferSize = numPacketsForTime * maxPacketSize
    } else {
        outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize
    }
    
    if (outBufferSize > maxBufferSize &&
        outBufferSize > maxPacketSize) {
        outBufferSize = maxBufferSize
    } else {
        if outBufferSize < minBufferSize {
            outBufferSize = minBufferSize
        }
    }
    outNumPackets = outBufferSize / maxPacketSize
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
    
    var numBytes = aqp.pointee.bufferByteSize
    var nPackets = aqp.pointee.numPacketsToRead
    
    // (-50) AVAudioSessionErrorCodeBadParam
    
    // 2022-03-15 21:05:10.563094-0400 CAPlayer[20364:2121326] [aqme]        MEMixerChannel.cpp:1639  client <AudioQueueObject@0x106808200;
    // [0]; play> got error 2003332927 while sending format information  (who?) kAudioCodecUnknownPropertyError
    
    let err = AudioFileReadPacketData(aqp.pointee.playbackFile!,
                                       false,
                                       &numBytes,
                                       aqp.pointee.packetDescs,
                                       aqp.pointee.packetPosition,
                                       &nPackets,
                                       inCompleteAQBuffer.pointee.mAudioData)
    
    checkError(err, "AudioFileReadPacketData failed")
    
//    checkError(AudioFileReadPackets(aqp.pointee.playbackFile!,
//                                    false,
//                                    &numBytes,
//                                    aqp.pointee.packetDescs,
//                                    aqp.pointee.packetPosition,
//                                    &nPackets,
//                                    inCompleteAQBuffer.pointee.mAudioData),
//               "AudioFileReadPackets failed")
    
    if nPackets > 0 {
        inCompleteAQBuffer.pointee.mAudioDataByteSize = numBytes
        AudioQueueEnqueueBuffer(inAQ,
                                inCompleteAQBuffer,
                                nPackets,
                                aqp.pointee.packetDescs)
        aqp.pointee.packetPosition += Int64(nPackets)
    } else {
        checkError((AudioQueueStop(inAQ, false)), "AudioQueueStop failed")
        aqp.pointee.isDone = true
    }
    
}

// MARK: - Main Function
func main () {
    // var player = MyPlayer()
    
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
    var propSize = UInt32(40)
    var isWritable = UInt32(0)

    checkError(AudioFileGetPropertyInfo(playbackFile!,
                                    kAudioFilePropertyDataFormat,
                                    &propSize,
                                    &isWritable),
               "Couldn't get data format size")
    
    
    checkError(AudioFileGetProperty(playbackFile!,
                                    kAudioFilePropertyDataFormat,
                                    &propSize,
                                    &dataFormat),
               "Couldn't get file's data format.")
    
    var bufferByteSize = UInt32(0)
    var numPacketsToRead = UInt32(0)
    
    calculateBytesForTime(inAudioFile: playbackFile!,
                          inDesc: dataFormat,
                          inSeconds: Settings.duration,
                          outBufferSize: &bufferByteSize,
                          outNumPackets: &numPacketsToRead)
    
    print (bufferByteSize)
    print (numPacketsToRead)

    var packetDescs: UnsafeMutablePointer<AudioStreamPacketDescription>? = nil
    
    let isFormatVBR = dataFormat.mBytesPerPacket == 0 || dataFormat.mFramesPerPacket == 0
    
    if isFormatVBR {
        packetDescs = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(numPacketsToRead))
    }
    
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
    
    var buffers = [AudioQueueBufferRef]()
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
        
        buffers.append(buffer)
       
        myAQOutputCallback(inUserData: &player, inAQ: queue, inCompleteAQBuffer: buffer)
        
        if player.isDone {
            break
        }
    }
    checkError(AudioQueueStart(queue, nil), "AudioQueueStart failed")
    
    print ("Playing...")
    repeat {
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode,
                           0.25,
                           false)
    } while !player.isDone
    CFRunLoopRunInMode(CFRunLoopMode.defaultMode,
                       2,
                       false)
    player.isDone = true
    checkError(AudioQueueStop(queue, false), "AudioQueueStop failed")
    AudioQueueDispose(queue, true)
    AudioFileClose(player.playbackFile!)
    return
}
