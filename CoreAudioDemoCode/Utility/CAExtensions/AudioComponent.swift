//
//  AudioComponent.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/26/22.
//

import AVFoundation

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
