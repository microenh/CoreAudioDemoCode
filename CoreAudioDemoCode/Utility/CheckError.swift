//
//  CheckError.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/14/22.
//

import Foundation

// 1819304813 = "lpcm"
// 1718449215 = "fmt?"
// -50 = (-50)

func checkError(_ error: OSStatus, _ operation: String = "") {
    func errorToString(_ error: OSStatus) -> String {
        let chars = Swift.withUnsafeBytes(of: error.bigEndian) { Data($0) }.map{ Character(Unicode.Scalar($0)) }
        return chars.map ({ $0.isASCII }).reduce(true) {$0 && $1} ? "\"\(String(chars))\"" : "(\(error))"
    }
    
    guard error != noErr else { return }
    print ("Error: \(errorToString(error)) \(operation)")
    exit(EXIT_FAILURE)
}
