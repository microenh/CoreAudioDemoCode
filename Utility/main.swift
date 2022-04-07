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
} catch CAError.componentNotFound {
    print ("component not found")
} catch CAError.osStatus(let osStatus) {
    print ("CA osStatus (\(osStatus.appleString))")
// --
} catch {
    print ("Unhandled error \(error)")
}
