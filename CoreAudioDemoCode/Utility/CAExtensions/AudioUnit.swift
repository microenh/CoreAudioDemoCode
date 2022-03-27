//
//  AudioUnit.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AVFoundation

extension AudioUnit {
    static func new(componentType: OSType, componentSubType: OSType) throws -> AudioUnit {
        let comp = try AudioComponent.find(componentType: componentType,
                                           componentSubType: componentSubType)
        var audioUnit: AudioUnit?
        try checkOSStatus(AudioComponentInstanceNew(comp, &audioUnit))
        return audioUnit!
    }
    
    func setIO(inputScope: Bool, inputBus: Bool, enable: Bool) throws {
        var enableFlag: UInt32 = enable ? 1 : 0
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioOutputUnitProperty_EnableIO,
                                               inputScope ? kAudioUnitScope_Input : kAudioUnitScope_Output,
                                               inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                               &enableFlag,
                                               UInt32(MemoryLayout<UInt32>.size)))
    }
    
    func setCurrentDevice(device: AudioDeviceID,
                          mScope: AudioObjectPropertyScope = kAudioUnitScope_Global,
                          inputBus: Bool) throws {
        var deviceP = device
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioOutputUnitProperty_CurrentDevice,
                                               mScope,
                                               inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                               &deviceP,
                                               UInt32(MemoryLayout<AudioDeviceID>.size)))
    }
    
    func getABSD(inputScope: Bool, inputBus: Bool) throws -> AudioStreamBasicDescription {
        var streamFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkOSStatus(AudioUnitGetProperty(self,
                                               kAudioUnitProperty_StreamFormat,
                                               inputScope ? kAudioUnitScope_Input: kAudioUnitScope_Output,
                                               inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                               &streamFormat,
                                               &propertySize))
        return streamFormat
    }
    
    func setABSD(absd: AudioStreamBasicDescription,
                 inputScope: Bool,
                 inputBus: Bool = false) throws {
        var absdP = absd
        let propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try checkOSStatus(AudioUnitSetProperty(self,
                                               kAudioUnitProperty_StreamFormat,
                                               inputScope ? kAudioUnitScope_Input : kAudioUnitScope_Output,
                                               inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                               &absdP,
                                               propertySize))
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
