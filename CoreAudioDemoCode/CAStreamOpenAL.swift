//
//  CAStreamOpenAL.swift
//  CAStreamOpenAL
//
//  Created by Mark Erbaugh on 4/2/22.
//

import OpenAL
import CoreFoundation
import CoreAudioTypes
import AudioToolbox

struct Settings {
    static let bufferCount = 2
    static let bufferDurationSeconds = 1.0
    static let orbitSpeed = 1.0
    static let streamPath = "/Users/mark/Music/daily_download_20191014_128.mp3" as CFString
    static let runTime = 30.0
}

// MARK: user-data struct
struct MyStreamPlayer {
    var dataFormat = AudioStreamBasicDescription(mSampleRate: 44100,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsSignedInteger |
                                                               kAudioFormatFlagIsPacked,
                                                 mBytesPerPacket: 2,
                                                 mFramesPerPacket: 1,
                                                 mBytesPerFrame: 2,
                                                 mChannelsPerFrame: 1,
                                                 mBitsPerChannel: 16,
                                                 mReserved: 0)
    var bufferSizeBytes = UInt32(0)
    var fileLengthFrames = Int64(0)
    var totalFramesRead = Int64(0)
    var sources = [ALuint()]
    var extAudioFile: ExtAudioFileRef!
    
    var sampleBuffer: UnsafeMutableRawPointer!
    var buffers: AudioBuffer!
}

// MARK: utility functions

func updateSourceLocation(player: UnsafeMutablePointer<MyStreamPlayer>) {
    let theta = fmod(CFAbsoluteTimeGetCurrent() * Settings.orbitSpeed, Double.pi * 2)
    alSource3f(player.pointee.sources[0], AL_POSITION,
               ALfloat(3 * cos(theta)),
               ALfloat(0.5 * sin(theta)),
               ALfloat(sin(theta)))
}

func setUpExtAudioFile(player: UnsafeMutablePointer<MyStreamPlayer>) -> OSStatus {
    let streamFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                      Settings.streamPath,
                                                      CFURLPathStyle.cfurlposixPathStyle,
                                                      false)!

    checkError(ExtAudioFileOpenURL(streamFileURL, &player.pointee.extAudioFile),
               "Couldn't open ExtAudioFile for streaming")
    
    // Tell extAudioFile about our format
    checkError(ExtAudioFileSetProperty(player.pointee.extAudioFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                       &player.pointee.dataFormat),
               "Couldn't set client format on ExtAudioFile")

    // Figure out how big file is
    var propSize = UInt32(MemoryLayout<Int64>.size)
    ExtAudioFileGetProperty(player.pointee.extAudioFile,
                            kExtAudioFileProperty_FileLengthFrames,
                            &propSize,
                            &player.pointee.fileLengthFrames)
    
    print ("fileLengthFrames = \(player.pointee.fileLengthFrames)")
    
    player.pointee.bufferSizeBytes = UInt32(Settings.bufferDurationSeconds *
                                     player.pointee.dataFormat.mSampleRate *
                                     Double(player.pointee.dataFormat.mBytesPerFrame))

    print ("bufferSizeBytes = \(player.pointee.bufferSizeBytes)")
    print ("Bottom of setUpExtAudioFile")
    
    player.pointee.sampleBuffer = malloc(MemoryLayout<UInt16>.size * Int(player.pointee.bufferSizeBytes))
    player.pointee.buffers = AudioBuffer(mNumberChannels: 1,
                                         mDataByteSize: UInt32(player.pointee.bufferSizeBytes),
                                         mData: player.pointee.sampleBuffer)
    print ("Allocated \(player.pointee.bufferSizeBytes) byte buffer for ABL")
    return noErr
}

func fillALBuffer(player: UnsafeMutablePointer<MyStreamPlayer>, alBuffer: ALuint) {
//    player.pointee.sampleBuffer = malloc(MemoryLayout<UInt16>.size * Int(player.pointee.bufferSizeBytes))
//    player.pointee.buffers = AudioBuffer(mNumberChannels: 1,
//                                         mDataByteSize: UInt32(player.pointee.bufferSizeBytes),
//                                         mData: player.pointee.sampleBuffer)
//
//    print ("Allocated \(player.pointee.bufferSizeBytes) byte buffer for ABL")
    
    var convertedData: AudioBufferList
    var framesReadIntoBuffer = UInt32(0)
    var framesRead: UInt32
    repeat {
        framesRead = UInt32(player.pointee.fileLengthFrames) - framesReadIntoBuffer
        player.pointee.buffers.mData = player.pointee.sampleBuffer! + (Int(framesReadIntoBuffer) * MemoryLayout<UInt16>.size)
        convertedData = AudioBufferList(mNumberBuffers: 1, mBuffers: (player.pointee.buffers))

        checkError(ExtAudioFileRead(player.pointee.extAudioFile,
                                    &framesRead,
                                    &convertedData),
                   "ExtAudioFileRead failed")
        framesReadIntoBuffer += framesRead
        player.pointee.totalFramesRead += Int64(framesRead)
//        print ("read \(framesRead) frames")
//        print ("framesReadIntoBuffer \(framesReadIntoBuffer), target = \(player.pointee.bufferSizeBytes / UInt32(MemoryLayout<UInt16>.size))")
    } while framesReadIntoBuffer < (player.pointee.bufferSizeBytes / UInt32(MemoryLayout<UInt16>.size))
 
    // Copy from sample buffer to AL buffer
    alBufferData(alBuffer,
                 AL_FORMAT_MONO16,
                 player.pointee.sampleBuffer,
                 ALsizei(player.pointee.bufferSizeBytes),
                 ALsizei(player.pointee.dataFormat.mSampleRate))
//    free(player.pointee.sampleBuffer)
}

func refillALBuffers(player: UnsafeMutablePointer<MyStreamPlayer>) {
    var processed = ALint(0)
    alGetSourcei(player.pointee.sources[0],
                 AL_BUFFERS_PROCESSED,
                 &processed)
    checkALError(operation: "Couldn't get al_buffers_processed")
    
    while processed > 0 {
        var freeBuffer = ALuint(0)
        alSourceUnqueueBuffers(player.pointee.sources[0],
                               1,
                               &freeBuffer)
        checkALError(operation: "Couldn't unqueue buffer")
        // print ("Refilling buffer \(freeBuffer)")
        fillALBuffer(player: player, alBuffer: freeBuffer)
        alSourceQueueBuffers(player.pointee.sources[0],
                             1,
                             &freeBuffer)
        checkALError(operation: "Couldn't queue refilled buffer")
        processed -= 1
    }
}

func main() {
    // Prepare the ExtAudioFile for reading
    // Set up OpenAL buffers
    var player = MyStreamPlayer()
    checkError(setUpExtAudioFile(player: &player),
               "Couldn't open ExtAudioFile")
    let alDevice = alcOpenDevice(nil)
    checkALError(operation: "Couldn't open AL device")
    let alContext = alcCreateContext(alDevice, nil)
    checkALError(operation: "Couldn't open AL context")
    alcMakeContextCurrent(alContext)
    checkALError(operation: "Couldn't make AL context current")
    
    var buffers = [ALuint](repeating: ALuint(0), count: Settings.bufferCount)
    alGenBuffers(ALsizei(Settings.bufferCount), &buffers)
    checkALError(operation: "Couldn't generate buffers")
    for i in 0..<Settings.bufferCount {
        fillALBuffer(player: &player, alBuffer: buffers[i])
    }
    
    // Set up streaming source
    alGenSources(1, &player.sources)
    checkALError(operation: "Couldn't generate sources")
    alSourcef(player.sources[0], AL_GAIN, ALfloat(AL_MAX_GAIN))
    checkALError(operation: "Couldn't set source gain")
    updateSourceLocation(player: &player)
    checkALError(operation: "Couldn't set initial source position")
    
    // Queue up the buffers on the source
    alSourceQueueBuffers(player.sources[0], ALsizei(Settings.bufferCount), &buffers)
    checkALError(operation: "Couldn't queue buffers on source")
    
    // Set up listener
    alListener3f(AL_POSITION, 0, 0, 0)
    checkALError(operation: "Couldn't set listener position")
    // Start playing
    alSourcePlayv(1, player.sources)
    checkALError(operation: "Couldn't play")
    
    // Loop and wait
    print ("Playing")
    let startTime = time(nil)
    repeat {
        updateSourceLocation(player: &player)
        checkALError(operation: "Couldn't set looping source position")
        
        // refil buffers if needed
        refillALBuffers(player: &player)
        
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode,
                           0.1,
                           false)
    } while difftime(time(nil), startTime) < Settings.runTime

    // Clean up
    alSourceStop(player.sources[0])
    alDeleteSources(1, player.sources)
    alDeleteBuffers(ALsizei(Settings.bufferCount), &buffers)
    alcDestroyContext(alContext)
    alcCloseDevice(alDevice)
    free(player.sampleBuffer)
    print ("Bottom of main")
}
