//
//  CAUtility.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/25/22.
//

import AVFoundation

struct AudioDevice {
    let audioDeviceID: AudioDeviceID

    var output: Bool? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: 0)
        
        var propsize = UInt32(MemoryLayout<CFString?>.size);
        guard AudioObjectGetPropertyDataSize(self.audioDeviceID,
                                             &address,
                                             0,
                                             nil,
                                             &propsize) == 0 else {
            return nil
            
        }
        let bufferList = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(propsize))
        defer {
            free(bufferList)
        }
        guard AudioObjectGetPropertyData(self.audioDeviceID,
                                         &address,
                                         0,
                                         nil,
                                         &propsize,
                                         bufferList) == 0 else {
            return nil
        }
        return UnsafeMutableAudioBufferListPointer(bufferList).reduce(0) {$0 + $1.mNumberChannels} > 0
    }
    
    var uid: String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        
        var name: CFString? = nil
        var propsize = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(self.audioDeviceID,
                                         &address,
                                         0,
                                         nil,
                                         &propsize,
                                         &name) == 0 else {
            return nil
        }
        return name as String?
    }

    var name: String? {
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceNameCFString,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        
        var name: CFString? = nil
        var propsize = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(self.audioDeviceID,
                                         &address,
                                         0,
                                         nil,
                                         &propsize,
                                         &name) == 0 else {
            return nil
        }
        return name as String?
    }
}


struct AudioDeviceFinder {
    static func findDevices() {
        var propsize = UInt32(0)

        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)

        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject),
                                                    &address,
                                                    UInt32(MemoryLayout<AudioObjectPropertyAddress>.size),
                                                    nil,
                                                    &propsize)

        if (result != 0) {
            print("Error \(result) from AudioObjectGetPropertyDataSize")
            return
        }

        var devids = (0..<(propsize / UInt32(MemoryLayout<AudioDeviceID>.size))).map { _ in AudioDeviceID() }
        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                            &address,
                                            0,
                                            nil,
                                            &propsize,
                                            &devids);
        if (result != 0) {
            print("Error \(result) from AudioObjectGetPropertyData")
            return
        }

        for dev in devids {
            let audioDevice = AudioDevice(audioDeviceID: dev)
            if let name = audioDevice.name,
               let uid = audioDevice.uid,
               let output = audioDevice.output
            {
                print("Found device \(dev): \(name), uid = \(uid) \(output ? "output" : "")")
            }
        }
    }
}

extension AudioComponentDescription {
    init(componentType: OSType, componentSubType: OSType) {
        self.init(componentType: componentType,
             componentSubType: componentSubType,
             componentManufacturer: kAudioUnitManufacturer_Apple,
             componentFlags: 0,
             componentFlagsMask: 0)
    }
}

extension AudioComponent {
    static func find(componentType: OSType, componentSubType: OSType) throws -> AudioComponent {
        let cd = AudioComponentDescription(componentType: componentType,
                                           componentSubType: componentSubType,
                                           componentManufacturer: kAudioUnitManufacturer_Apple,
                                           componentFlags: 0,
                                           componentFlagsMask: 0)
        return try find(cd: cd)
    }
    static func find(cd: AudioComponentDescription) throws -> AudioComponent {
        var cdp = cd
        guard let comp = AudioComponentFindNext(nil, &cdp) else {
            throw CAError.componentNotFound
        }
        return comp
    }
}

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

extension AudioObjectID {
    static func find(mSelector: AudioObjectPropertySelector,
              mScope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
              mElement: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) throws -> AudioObjectID {
        var device = kAudioObjectUnknown
        var deviceProperty = AudioObjectPropertyAddress(mSelector: mSelector,
                                                        mScope: mScope,
                                                        mElement: mElement)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let osStatus = AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject),
                                                  &deviceProperty,
                                                  0,
                                                  nil,
                                                  &propertySize,
                                                  &device)
        guard osStatus == noErr else {
            throw CAError.findDevice(osStatus)
        }
        return device
    }
}

extension AUGraph {
    static func new() throws -> AUGraph {
        var graph: AUGraph?
        let osStatus = NewAUGraph(&graph)
        guard osStatus == noErr else {
            throw CAError.newGraph(osStatus)
        }
        return graph!
    }
    
    func addNode(componentType: OSType, componentSubType: OSType) throws -> AUNode{
        var cd = AudioComponentDescription(componentType: componentType,
                                           componentSubType: componentSubType)
        var node = AUNode()
        let osStatus = AUGraphAddNode(self,
                                      &cd,
                                      &node)
        guard osStatus == noErr else {
            throw CAError.addGraphNode(osStatus)
        }
        return node
    }
    
    func open() throws {
        let osStatus = AUGraphOpen(self)
        guard osStatus == noErr else {
            throw CAError.openGraph(osStatus)
        }
    }
    
    func getNodeAU(node: AUNode) throws -> AudioUnit {
        var unit: AudioUnit?
        let osStatus = AUGraphNodeInfo(self,
                                       node,
                                       nil,
                                       &unit)
        guard osStatus == noErr else {
            throw CAError.getUnit(osStatus)
        }
        return unit!
    }
    
    func connectNodes(node1: AUNode, bus1: UInt32, node2: AUNode, bus2: UInt32) throws {
        let osStatus = AUGraphConnectNodeInput(self, node1, bus1, node2, bus2)
        guard osStatus == noErr else {
            throw CAError.connectNodes(osStatus)
        }
    }
    
    func initialze() throws {
        let osStatus = AUGraphInitialize(self)
        guard osStatus == noErr else {
            throw CAError.initializeGraph(osStatus)
        }
    }
    
    func start() throws {
        let osStatus = AUGraphStart(self)
        guard osStatus == noErr else {
            throw CAError.graphStart(osStatus)
        }
    }
}
