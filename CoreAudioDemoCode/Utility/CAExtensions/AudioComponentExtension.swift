//
//  AudioComponentExtension.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AVFoundation

extension AudioComponentDescription {
    init(componentType: OSType, componentSubType: OSType) {
        self.init(componentType: componentType,
             componentSubType: componentSubType,
             componentManufacturer: kAudioUnitManufacturer_Apple,
             componentFlags: 0,
             componentFlagsMask: 0)
    }
}
