//
//  AudioUnit.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AudioToolbox

import AVFoundation

extension AudioUnit {
    init(componentType: OSType, componentSubType: OSType) throws {
        let comp = try AudioComponent.find(componentType: componentType,
                                           componentSubType: componentSubType)
        var audioUnit: AudioUnit?
        try checkOSStatus(AudioComponentInstanceNew(comp, &audioUnit))
        self = audioUnit!
    }

//    var halVolume: Float32 {
//        get {
//            var volume = Float32(0)
//            var propertySize = UInt32(MemoryLayout<Float32>.size)
//            failOSStatus(AudioUnitGetProperty(self,
//                                              kHALOutputParam_Volume,
//                                              kAudioUnitScope_Global,
//                                              AudioUnitScope(0),
//                                              &volume,
//                                              &propertySize))
//            return volume
//        }
//        set(volume) {
//            var volumeP = volume
//            failOSStatus(AudioUnitSetProperty(self,
//                                              kHALOutputParam_Volume,
//                                              kAudioUnitScope_Global,
//                                              AudioUnitScope(0),
//                                              &volumeP,
//                                              UInt32(MemoryLayout<Float32>.size)))
//        }
//    }
    
    func getHALVolume() throws -> Float32 {
        var volume = Float32(0)
        var propertySize = UInt32(MemoryLayout<Float32>.size)
        try checkOSStatus(AudioUnitGetProperty(self,
                                               kHALOutputParam_Volume,
                                               kAudioUnitScope_Global,
                                               AudioUnitScope(0),
                                               &volume,
                                               &propertySize))
        return volume
    }
    
    func setHALVolume(volume: Float32) throws {
        var volumeP = volume
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kHALOutputParam_Volume,
                                               kAudioUnitScope_Global,
                                               AudioUnitScope(0),
                                               &volumeP,
                                               UInt32(MemoryLayout<Float32>.size)))
    }
    
    func setIO(scope: AudioUnitScope, inputBus: Int, enable: Bool) throws {
        var enableFlag: UInt32 = enable ? 1 : 0
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioOutputUnitProperty_EnableIO,
                                               scope,
                                               AudioUnitScope(inputBus),
                                               &enableFlag,
                                               UInt32(MemoryLayout<UInt32>.size)))
    }
    
    func setCurrentDevice(device: AudioDeviceID,
                          scope: AudioObjectPropertyScope = kAudioUnitScope_Global,
                          inputBus: Int) throws {
        var deviceP = device
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioOutputUnitProperty_CurrentDevice,
                                               scope,
                                               AudioUnitScope(inputBus),
                                               &deviceP,
                                               UInt32(MemoryLayout<AudioDeviceID>.size)))
    }
    
    func getABSD(scope: AudioUnitScope, element: Int = 0) throws -> AudioStreamBasicDescription {
        var streamFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkOSStatus(AudioUnitGetProperty(self,
                                               kAudioUnitProperty_StreamFormat,
                                               scope,
                                               AudioUnitScope(element),
                                               &streamFormat,
                                               &propertySize))
        return streamFormat
    }
    
    func setABSD(absd: AudioStreamBasicDescription, scope: AudioUnitScope, element: Int = 0) throws {
        var absdP = absd
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioUnitProperty_StreamFormat,
                                               scope,
                                               AudioUnitScope(element),
                                               &absdP,
                                               UInt32(MemoryLayout<AudioStreamBasicDescription>.size)))
    }
    
    func getBufferFrameSize() throws -> UInt32 {
        var bufferSizeFrames = UInt32(0)
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        try checkOSStatus(AudioUnitGetProperty(self,
                                               kAudioDevicePropertyBufferFrameSize,
                                               kAudioUnitScope_Global,
                                               0,
                                               &bufferSizeFrames,
                                               &propertySize))
        return bufferSizeFrames
    }
    
    func setInputCallback(inputProc: @escaping AURenderCallback,
                          inputProcRefCon: UnsafeMutableRawPointer?) throws {
        var callbackStruct = AURenderCallbackStruct(inputProc: inputProc,
                                                    inputProcRefCon: inputProcRefCon)
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioOutputUnitProperty_SetInputCallback,
                                               kAudioUnitScope_Global,
                                               0,
                                               &callbackStruct,
                                               UInt32(MemoryLayout<AURenderCallbackStruct>.size)))
    }
    
    func setRenderCallback(inputProc: @escaping AURenderCallback,
                           inputProcRefCon: UnsafeMutableRawPointer?) throws {
        var callbackStruct = AURenderCallbackStruct(inputProc: inputProc,
                                                    inputProcRefCon: inputProcRefCon)
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Global,
                                               0,
                                               &callbackStruct,
                                               UInt32(MemoryLayout<AURenderCallbackStruct>.size)))
    }
    
    func initialize() throws {
        try checkOSStatus(AudioUnitInitialize(self))
    }
    
    func getSpeechChannel() throws -> SpeechChannel {
        var chan: SpeechChannel?
        var propsize = UInt32(MemoryLayout<SpeechChannelRecord>.size)
        try  checkOSStatus(AudioUnitGetProperty(self,
                                                kAudioUnitProperty_SpeechChannel,
                                                kAudioUnitScope_Global,
                                                0,
                                                &chan,
                                                &propsize))
        return chan!
    }
    
    func start() throws {
        try checkOSStatus(AudioOutputUnitStart(self))
    }
}
