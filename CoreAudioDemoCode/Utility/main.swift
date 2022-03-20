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
} catch {
    print ("Unhandled error \(error)")
}
