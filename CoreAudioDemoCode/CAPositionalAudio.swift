//
//  CAPositionalAudio.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 4/2/22.
//

import OpenAL
import CoreAudioTypes
import AudioToolbox

struct Settings {
    static let runTime = 20.0
    static let orbitSpeed = 2.0
    static let loopPath = "/Library/Audio/Apple Loops/Apple/11 Blues Garage/Backroad Blues Lead Guitar 03.caf" as CFString
}


// MARK: user-data struct
struct MyLoopPlayer {
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
    var sampleBuffer: UnsafeMutableRawPointer?
    var bufferSizeBytes = Int32(0)
    var sources = [ALuint()]
}

// MARK: utility functions

func checkALError(operation: String) {
    let alErr = alGetError()
    guard alErr != AL_NO_ERROR else {
        return
    }
    var errName = "UNKNOWN"
    switch alErr {
    case AL_INVALID_NAME:
        errName = "AL_INVALID_NAME"
    case AL_INVALID_VALUE:
        errName = "AL_INVALID_VALUE"
    case AL_INVALID_ENUM:
        errName = "AL_INVALID_ENUM"
    case AL_INVALID_OPERATION:
        errName = "AL_INVALID_OPERATION"
    case AL_OUT_OF_MEMORY:
        errName = "AL_OUT_OF_MEMORY"
    default:
        break
    }
    print ("OpenAL Error: \(operation) (\(errName))")
    exit(1)
}

func updateSourceLocation(player: UnsafeMutablePointer<MyLoopPlayer>) {
    let theta = fmod(CFAbsoluteTimeGetCurrent() * Settings.orbitSpeed, Double.pi * 2)
    let x = ALfloat(3 * cos(theta))
    let y = ALfloat(0.5 * sin(theta))
    let z = ALfloat(sin(theta))
    alSource3f(player.pointee.sources[0], AL_POSITION, x, y, z)
}

func loadLoopIntoBuffer(player: UnsafeMutablePointer<MyLoopPlayer>) -> OSStatus {
    let loopFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                    Settings.loopPath,
                                                    CFURLPathStyle.cfurlposixPathStyle,
                                                    false)!
    var extAudioFile: ExtAudioFileRef!
    checkError(ExtAudioFileOpenURL(loopFileURL, &extAudioFile),
               "Couldn't open ExtAudioFile for reading")

    checkError(ExtAudioFileSetProperty(extAudioFile,
                                       kExtAudioFileProperty_ClientDataFormat,
                                       UInt32(MemoryLayout<AudioStreamBasicDescription>.size),
                                       &player.pointee.dataFormat),
               "Couldn't set client format on ExtAudioFile")
    
    var fileLengthFrames = Int64(0)
    var propSize = UInt32(MemoryLayout<Int64>.size)
    ExtAudioFileGetProperty(extAudioFile,
                            kExtAudioFileProperty_FileLengthFrames,
                            &propSize,
                            &fileLengthFrames)
    player.pointee.bufferSizeBytes = Int32(fileLengthFrames) * Int32(player.pointee.dataFormat.mBytesPerFrame)
    
    player.pointee.sampleBuffer = malloc(MemoryLayout<UInt16>.size * Int(player.pointee.bufferSizeBytes))
    let buffers = AudioBuffer(mNumberChannels: 1,
                              mDataByteSize: UInt32(player.pointee.bufferSizeBytes),
                              mData: player.pointee.sampleBuffer)

    var convertedData = AudioBufferList(mNumberBuffers: 1, mBuffers: (buffers))

    // loop reading into the ABL until buffer is full
    var totalFramesRead = UInt32(0)
    // repeat {
        var framesRead = UInt32(fileLengthFrames) - totalFramesRead
        // while doing successive reads
        // buffers[0].mData = player.pointee.sampleBuffer! + (Int(totalFramesRead) * MemoryLayout<UInt16>.size)
        checkError(ExtAudioFileRead(extAudioFile,
                                    &framesRead,
                                    &convertedData),
                   "ExtAudioFileRead failed")
        totalFramesRead += framesRead
        print ("read \(framesRead) frames")
    // } while totalFramesRead < fileLengthFrames
    return noErr
}


// MARK: - main function
func main() {
    var player = MyLoopPlayer()
    
    // Convert to an OpenAL-friendly format and read into memory
    checkError(loadLoopIntoBuffer(player: &player),
               "Couldn't load loop into buffer")
    let alDevice = alcOpenDevice(nil)
    checkALError(operation: "Couldn't open AL device")
    let alContext = alcCreateContext(alDevice, nil)
    checkALError(operation: "Couldn't open AL context")
    alcMakeContextCurrent(alContext)
    
    // Set up OpenAL buffer
    var buffers = [ALuint()]
    alGenBuffers(1, &buffers)
    checkALError(operation: "Couldn't generate buffers")
    
    alBufferData(buffers[0],
                 AL_FORMAT_MONO16,
                 player.sampleBuffer,
                 player.bufferSizeBytes,
                 ALsizei(player.dataFormat.mSampleRate))
    free(player.sampleBuffer)
        
    // Set up OpenAL source
    alGenSources(1, &player.sources)
    checkALError(operation: "Couldn't generate sources")
    alSourcei(player.sources[0],
              AL_LOOPING,
              AL_TRUE)
    checkALError(operation: "Couldn't set source looping property")
    alSourcef(player.sources[0],
              AL_GAIN,
              ALfloat(AL_MAX_GAIN))
    checkALError(operation: "Couldn't set source gain")
    updateSourceLocation(player: &player)
    checkALError(operation: "Couldn't set initial source position")
    
    // Connect buffer to source
    alSourcei(player.sources[0],
              AL_BUFFER,
              ALint(buffers[0]))
    checkALError(operation: "Couldn't connect buffer to source")
    
    // Set up listener
    alListener3f(AL_POSITION, 0, 0, 0)
    checkALError(operation: "Couldn't set listener position")
    
    // Start playing
    alSourcePlay(player.sources[0])
    checkALError(operation: "Couldn't play")
    
    // Loop and wait
    print ("Playing")
    let startTime = time(nil)
    repeat {
        updateSourceLocation(player: &player)
        checkALError(operation: "Couldn't set looping source position")
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode,
                           0.1,
                           false)
    } while difftime(time(nil), startTime) < Settings.runTime
    
    // Cleanup
    alSourceStop(player.sources[0])
    alDeleteSources(1, player.sources)
    alDeleteBuffers(1, buffers)
    alcDestroyContext(alContext)
    alcCloseDevice(alDevice)
    print ("Bottom of main")
}
