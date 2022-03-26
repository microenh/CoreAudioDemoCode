//
//  main.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/13/22.
//

import Foundation

do {
    try main()
} catch CAError.errorString(let errorCode, let operation) {
    print ("Error: \(errorCode) on \(operation)")
} catch CAError.settingIO(let statusCode) {
    print ("Error settingIO \(statusCode.appleString)")
} catch CAError.findDevice(let statusCode) {
    print ("Error findingDevice \(statusCode.appleString)")
} catch {
    print ("Unhandled error \(error)")
}
