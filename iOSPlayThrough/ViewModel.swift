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
    var sineFrequency = 0.0
    var sinePhase = 0.0
}

class ViewModel {
    
    var effectState = EffectState()
    
    init() {
        startApplication()
    }
    
    func startApplication() {
        // Set up audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, policy: .default)
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
        let hardwareSampleRate = audioSession.preferredSampleRate == 0 ? 44100.0: audioSession.preferredSampleRate
        print ("hardwareSampleRate = \(hardwareSampleRate)")
        
        // Get Rio unit from component manager
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
        
        // Setup an ASBD in the iPhone canonical format
        var myASBD = AudioStreamBasicDescription(mSampleRate: hardwareSampleRate,
                                                 mFormatID: kAudioFormatLinearPCM,
                                                 mFormatFlags: kAudioFormatFlagIsSignedInteger
                                                             | kAudioFormatFlagsNativeEndian
                                                             | kAudioFormatFlagIsPacked, // | kAudioFormatFlagsCanonical,
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
        effectState.asbd = myASBD
        effectState.sineFrequency = 30
        effectState.sinePhase = 0
        
//        // Set the callback method
//        var callbackStruct = AURenderCallbackStruct(inputProc: inputModulatingRenderCallback,
//                                                    inputProcRefCon: &effectState)
//
//        checkError(AudioUnitSetProperty(effectState.rioUnit,
//                                        kAudioUnitProperty_SetRenderCallback,
//                                        kAudioUnitScope_Global,
//                                        bus0,
//                                        &callbackStruct,
//                                        UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
//                   "Couldn't set RIO's render callback on bus 0")

        let rioUnit = effectState.rioUnit
        withUnsafeMutablePointer(to: &effectState) { effectState in
            var callbackStruct = AURenderCallbackStruct(inputProc: inputModulatingRenderCallback,
                                                        inputProcRefCon: effectState)
            
            checkError(AudioUnitSetProperty(rioUnit!,
                                            kAudioUnitProperty_SetRenderCallback,
                                            kAudioUnitScope_Global,
                                            bus0,
                                            &callbackStruct,
                                            UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                       "Couldn't set RIO's render callback on bus 0")
        }
        
        // Start Rio unit
        checkError(AudioUnitInitialize(effectState.rioUnit),
                   "Couldn't initialize the RIO unit")
        checkError(AudioOutputUnitStart(effectState.rioUnit),
                   "Couldn't start the RIO unit")
        print ("RIO started")
    }

}
    
func inputModulatingRenderCallback(inRefCon: UnsafeMutableRawPointer,
                                   ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                                   inTimeStamp: UnsafePointer<AudioTimeStamp>,
                                   inBusNumber: UInt32,
                                   inNumberFrames: UInt32,
                                   ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    guard let abl = UnsafeMutableAudioBufferListPointer(ioData) else { return -50 }

    let effectState = inRefCon.assumingMemoryBound(to: EffectState.self)
    let bus1 = AudioUnitElement(1)
    checkError(AudioUnitRender(effectState.pointee.rioUnit,
                               ioActionFlags,
                               inTimeStamp,
                               bus1,
                               inNumberFrames,
                               ioData!),
               "Couldn't render from RemoteIO unit")
    
    // Walk the samples
    let bytesPerChannel = Int(effectState.pointee.asbd.mBytesPerFrame /
                              effectState.pointee.asbd.mChannelsPerFrame)
    abl.forEach { buf in
        for currentFrame in 0..<inNumberFrames {
            let frameOffset = Int(currentFrame * effectState.pointee.asbd.mBytesPerFrame)
            var channelOffset = Int(0)
            for _ in 0..<buf.mNumberChannels {
                let samplePtr = buf.mData!.advanced(by: frameOffset + channelOffset).assumingMemoryBound(to: Int16.self)
                samplePtr.pointee = Int16(Double(samplePtr.pointee) * sin(effectState.pointee.sinePhase * Double.pi * 2))
                channelOffset += bytesPerChannel
                effectState.pointee.sinePhase += (effectState.pointee.sineFrequency /
                                                  effectState.pointee.asbd.mSampleRate)
                if effectState.pointee.sinePhase > 1.0 {
                    effectState.pointee.sinePhase -= 1.0
                }
            }
        }
    }
        
    return noErr
}
