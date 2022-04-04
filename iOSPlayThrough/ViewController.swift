//
//  ViewController.swift
//  iOSPlayThrough
//
//  Created by Mark Erbaugh on 4/4/22.
//

import SwiftUI
import CoreAudio
import AudioToolbox
import AVFAudio

// MARK: Constants
/// Application Constants
///
/// The properties in this struct are all `static let`. They can be used
/// similar to `#define` in C/C++. This struct is never instatiated.
struct Settings {
    
}

// MARK: State
/// Application State
///
/// This struct is passed (via pointer) to various routines
/// There is only one instance.
struct EffectState {
    var rioUnit: AudioUnit!
    var asbd: AudioStreamBasicDescription!
    var sineFrequency = Float(0)
    var sinePhase = Float(0)
}

class ViewController {
    
    var effectState = EffectState()
    
    init() {
        startApplication()
    }
    
    func startApplication() {
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .moviePlayback, policy: .default)
        } catch {
            print ("Couldn't set category on audio session")
            return // false
        }

        // Is audio input available?
        if !audioSession.isInputAvailable {
            // TODO: generate alert
            print ("Input not available")
            return
        }
        
        // Get hardware sample rate
        let hardwareSampleRate = audioSession.preferredSampleRate
        print ("hardwareSampleRate = \(hardwareSampleRate)")
        
        // Get Rio unit from component manager
        // listing 10.22
        // Describe the unit
        var audioCompDesc = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                                      componentSubType: kAudioUnitSubType_RemoteIO,
                                                      componentManufacturer: kAudioUnitManufacturer_Apple,
                                                      componentFlags: 0,
                                                      componentFlagsMask: 0)
        // Get the RIO unit from the audio component manager
        let rioComponent = AudioComponentFindNext(nil, &audioCompDesc)
        checkError(AudioComponentInstanceNew(rioComponent!, &effectState.rioUnit),
                   "Couldn't get RIO unit instance")
        
        // Configure Rio unit
        var oneFlag = UInt32(1)
        let bus0 = AudioUnitElement(0)
        checkError(AudioUnitSetProperty(effectState.rioUnit,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Output,
                                        bus0,
                                        &oneFlag,
                                        UInt32(MemoryLayout<UInt32>.size)),
                   "Couldn't enable RIO output")
        // Enable RIO input
        let bus1 = AudioUnitElement(1)
        checkError(AudioUnitSetProperty(effectState.rioUnit,
                                        kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input,
                                        bus1,
                                        &oneFlag,
                                        UInt32(MemoryLayout<UInt32>.size)),
                   "Couldn't enable RIO input")
        
        // Setup an ASBD in teh iPhone canonical format
        var myASBD = AudioStreamBasicDescription(mSampleRate: hardwareSampleRate,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked, // kAudioFormatFlagsCanonical,
                                                 mBytesPerPacket: 4,
                                                 mFramesPerPacket: 1,
                                                 mBytesPerFrame: 4,
                                                 mChannelsPerFrame: 2,
                                                 mBitsPerChannel: 16,
                                                 mReserved: 0)
        
        // Set format for output (bus 0) on the RIO's input scope
        checkError(AudioUnitSetProperty(effectState.rioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input,
                                        bus0,
                                        &myASBD,
                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                   "Couldn't set the ASBD for RIO on input scope/bus 0")
        
        // Set format mic input (bus 1) on the RIO's output scope
        checkError(AudioUnitSetProperty(effectState.rioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Output,
                                        bus1,
                                        &myASBD,
                                        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)),
                   "Couldn't set the ASBD for RIO on input scope/bus 0")
        
        // Set callback method
        // listing 10.25
        effectState.asbd = myASBD
        effectState.sineFrequency = 30
        effectState.sinePhase = 0
        
        // Set the callback method
//        var callbackStruct = AURenderCallbackStruct(inputProc: inputModulatingRenderCallback,
//                                                    inputProcRefCon: &effectState)
        
        // Start Rio unit
        // listing 10.26
    }
}
