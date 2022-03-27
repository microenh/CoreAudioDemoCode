//
//  AudioObjectID.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AVFoundation

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


