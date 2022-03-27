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
        let osStatus = AudioComponentInstanceNew(comp, &audioUnit)
        guard osStatus == noErr else {
            throw CAError.newUnit(osStatus)
        }
        return audioUnit!
    }
    
    func setIO(inputScope: Bool, inputBus: Bool, enable: Bool) throws {
        var enableFlag: UInt32 = enable ? 1 : 0
        let osStatus = AudioUnitSetProperty(self,
                                            kAudioOutputUnitProperty_EnableIO,
                                            inputScope ? kAudioUnitScope_Input : kAudioUnitScope_Output,
                                            inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                            &enableFlag,
                                            UInt32(MemoryLayout<UInt32>.size))
        guard osStatus == noErr else {
            throw CAError.settingIO(osStatus)
        }
    }
    
    func setCurrentDevice(device: AudioDeviceID,
                          mScope: AudioObjectPropertyScope = kAudioUnitScope_Global,
                          inputBus: Bool) throws {
        var deviceP = device
        let osStatus = AudioUnitSetProperty(self,
                                            kAudioOutputUnitProperty_CurrentDevice,
                                            mScope,
                                            inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                            &deviceP,
                                            UInt32(MemoryLayout<AudioDeviceID>.size))
        guard osStatus == noErr else {
            throw CAError.setCurrentDevice(osStatus)
        }
    }
    
    func getABSD(inputScope: Bool, inputBus: Bool) throws -> AudioStreamBasicDescription {
        var streamFormat = AudioStreamBasicDescription()
        var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let osStatus = AudioUnitGetProperty(self,
                                            kAudioUnitProperty_StreamFormat,
                                            inputScope ? kAudioUnitScope_Input: kAudioUnitScope_Output,
                                            inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                            &streamFormat,
                                            &propertySize)
        guard osStatus == noErr else {
            throw CAError.getAsbd(osStatus)
        }
        return streamFormat
    }
    
    func setABSD(absd: AudioStreamBasicDescription,
                 inputScope: Bool,
                 inputBus: Bool = false) throws {
        var absdP = absd
        let propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let osStatus = AudioUnitSetProperty(self,
                                            kAudioUnitProperty_StreamFormat,
                                            inputScope ? kAudioUnitScope_Input : kAudioUnitScope_Output,
                                            inputBus ? AudioUnitScope(1) : AudioUnitScope(0),
                                            &absdP,
                                            propertySize)
        guard osStatus == noErr else {
            throw CAError.setAsbd(osStatus)
        }
    }
    
    func getBufferFrameSize() throws -> UInt32 {
        var bufferSizeFrames = UInt32(0)
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        let osStatus = AudioUnitGetProperty(self,
                                            kAudioDevicePropertyBufferFrameSize,
                                            kAudioUnitScope_Global,
                                            0,
                                            &bufferSizeFrames,
                                            &propertySize)
        guard osStatus == noErr else {
            throw CAError.getBufferFrameSize(osStatus)
        }
        return bufferSizeFrames
    }
    
    func setInputCallback(inputProc: @escaping AURenderCallback,
                          inputProcRefCon: UnsafeMutableRawPointer?) throws {
        var callbackStruct = AURenderCallbackStruct(inputProc: inputProc,
                                                    inputProcRefCon: inputProcRefCon)
        let osStatus = AudioUnitSetProperty(self,
                                            kAudioOutputUnitProperty_SetInputCallback,
                                            kAudioUnitScope_Global,
                                            0,
                                            &callbackStruct,
                                            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard osStatus == noErr else {
            throw CAError.setInputCallback(osStatus)
        }
    }
    
    func setRenderCallback(inputProc: @escaping AURenderCallback,
                          inputProcRefCon: UnsafeMutableRawPointer?) throws {
        var callbackStruct = AURenderCallbackStruct(inputProc: inputProc,
                                                    inputProcRefCon: inputProcRefCon)
        let osStatus = AudioUnitSetProperty(self,
                                            kAudioUnitProperty_SetRenderCallback,
                                            kAudioUnitScope_Global,
                                            0,
                                            &callbackStruct,
                                            UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        guard osStatus == noErr else {
            throw CAError.setRenderCallback(osStatus)
        }
    }
    
    func initialize() throws {
        let osStatus = AudioUnitInitialize(self)
        guard osStatus == noErr else {
            throw CAError.initializeAU(osStatus)
        }
    }
    
    func getSpeechChannel() throws -> SpeechChannel {
        var chan: SpeechChannel?
        var propsize = UInt32(MemoryLayout<SpeechChannelRecord>.size)
        let osStatus =  AudioUnitGetProperty(self,
                                             kAudioUnitProperty_SpeechChannel,
                                             kAudioUnitScope_Global,
                                             0,
                                             &chan,
                                             &propsize)
        guard osStatus == noErr else {
            throw CAError.getSpeechChan(osStatus)
        }
        return chan!
    }
    
    func start() throws {
        let osStatus = AudioOutputUnitStart(self)
        guard osStatus == noErr else {
            throw CAError.auStart(osStatus)
        }
    }
}
