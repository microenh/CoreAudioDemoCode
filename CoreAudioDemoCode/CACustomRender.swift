//
//  CACustomRender.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/21/22.
//

import Foundation
import AudioToolbox

// MARK: settings
struct Settings {
    static let sineFrequency = 880.0
    static let sampleRate = 44100.0
    static let twoPi = 2 * Double.pi
    static let phaseAdj = Settings.twoPi * Settings.sineFrequency / Settings.sampleRate
}

// MARK: user data struct
struct MySineWavePlayer {
    var outputUnit: AudioUnit!
    var staringFrameCount = Double(0)
    var phase = Double(0)
}

// MARK: callback function
func sineWaveRenderProc(inRefCon: UnsafeMutableRawPointer,
                        ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                        inTimeStamp: UnsafePointer<AudioTimeStamp>,
                        inBusNumber: UInt32,
                        inNumberFrames: UInt32,
                        ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    // print("sineWaveRenderProc needs \(inNumberFrames) frames at \(CFAbsoluteTimeGetCurrent())")
    
    let player = inRefCon.assumingMemoryBound(to: MySineWavePlayer.self)
    
    // let cycleLength = 44100.0 / Settings.sineFrequency
    var phase = player.pointee.phase
    
    // key line to decoding multiple AudioBuffers in AudioBufferList
    // I think it only works because mBuffers is the first field in AudioBuffer list

    guard let abl = UnsafeMutableAudioBufferListPointer(ioData) else { return -50 }

    // The following code only works if there are exactly two channels
    // left channel
    // let dataL = abl[0].mData!.assumingMemoryBound(to: Float32.self)
    // right channel
    // let dataR = abl[1].mData!.assumingMemoryBound(to: Float32.self)
    
    // should work for any number of channels
    let data = (0..<Int(ioData!.pointee.mNumberBuffers)).map{ i in abl[i].mData!.assumingMemoryBound(to: Float32.self) }
    
    for frame in 0..<Int(inNumberFrames) {
        let output = Float32(cos(phase))
        for d in data {
            d[frame] = output
        }
//        dataL[frame] = output
//        dataR[frame] = output
        
        phase += Settings.phaseAdj
        if (phase > Settings.twoPi) {
            phase -= Settings.twoPi
        }
    }
    player.pointee.phase = phase
    return noErr
}


// MARK: utility functions
// throwIfError in CheckError.swift
func createAndConnectOutputUnit(player: UnsafeMutablePointer<MySineWavePlayer>) throws {
    // Generates a description that matches the output device (speakers)
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_DefaultOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    let comp = AudioComponentFindNext(nil, &outputcd)
    guard let comp = comp else {
        print ("can't get output unit")
        exit (-1)
    }
    try throwIfError(AudioComponentInstanceNew(comp, &player.pointee.outputUnit),
                     "AudioComponentInstanceNew")
    
    // Register the render callback
    var input = AURenderCallbackStruct(inputProc: sineWaveRenderProc, inputProcRefCon: player)
    try throwIfError(AudioUnitSetProperty(player.pointee.outputUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Input,
                                          0,
                                          &input,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                     "AudioUnitSetProperty")
    // Initialize the unit
    try throwIfError(AudioUnitInitialize(player.pointee.outputUnit),
                     "AudioUnitInitialize")
    
}

// MARK: - main function
func main() throws {
    var player = MySineWavePlayer()
    
    // Set up unit and callback
    try createAndConnectOutputUnit(player: &player)
    defer {
        AudioComponentInstanceDispose(player.outputUnit)
        AudioUnitUninitialize(player.outputUnit)
    }
    
    // Start playing
    try throwIfError(AudioOutputUnitStart(player.outputUnit), "AudioOutputUnitStart")
    
    defer {
        AudioOutputUnitStop(player.outputUnit)
    }
    sleep(5)
}
