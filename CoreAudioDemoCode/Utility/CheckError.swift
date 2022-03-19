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
// -50 = -50: Bad parameter
// -38 = -38: File not open
func int32ToString(_ code: OSStatus) -> String {
    let chars = Swift.withUnsafeBytes(of: code){ Data($0) }.map{ Character(Unicode.Scalar($0)) }
    return chars.reduce(true){ $0 && (UInt8(32)...127).contains($1.asciiValue ?? 0)} ? String(chars.reversed()) : "\(code)"
}
    
func checkError(_ error: OSStatus, _ operation: String = "") {
    guard error != noErr else { return }
    print ("Error: \(operation) (\(int32ToString(error))).")
    exit(EXIT_FAILURE)
}
