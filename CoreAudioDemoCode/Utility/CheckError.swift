//
//  CheckError.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/14/22.
//

import Foundation


// convert Apple 32-bit int to 4 characters if valid
// 1819304813 = lpcm
// 1718449215 = fmt?
// -50 = -50
func int32ToString(_ error: OSStatus) -> String {
    let chars = Swift.withUnsafeBytes(of: error){ Data($0) }.map{ Character(Unicode.Scalar($0)) }
    return chars.reduce(true){ $0 && $1.isASCII } ? String(chars.reversed()) : "\(error)"
}
    
func checkError(_ error: OSStatus, _ operation: String = "") {
    guard error != noErr else { return }
    print ("Error: \(operation) (\(int32ToString(error))).")
    exit(EXIT_FAILURE)
}
