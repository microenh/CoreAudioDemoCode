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
