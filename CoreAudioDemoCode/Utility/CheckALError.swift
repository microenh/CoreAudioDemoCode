//
//  CheckALError.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 4/2/22.
//

import OpenAL

func checkALError(operation: String) {
    let alErr = alGetError()
    guard alErr != AL_NO_ERROR else {
        return
    }
    var errName = "UNKNOWN"
    switch alErr {
    case AL_INVALID_NAME:
        errName = "AL_INVALID_NAME"
    case AL_INVALID_VALUE:
        errName = "AL_INVALID_VALUE"
    case AL_INVALID_ENUM:
        errName = "AL_INVALID_ENUM"
    case AL_INVALID_OPERATION:
        errName = "AL_INVALID_OPERATION"
    case AL_OUT_OF_MEMORY:
        errName = "AL_OUT_OF_MEMORY"
    default:
        break
    }
    print ("OpenAL Error: \(operation) (\(errName))")
    exit(1)
}
