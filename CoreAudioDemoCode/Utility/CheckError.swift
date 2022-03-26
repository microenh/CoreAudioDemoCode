//
//  CheckError.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/14/22.
//

import Foundation

enum CAError: Error {
    case errorString(OSStatus, String)
}

// convert Apple 32-bit int to 4 characters if valid
// 1819304813 = lpcm
// 1718449215 = fmt?
// -50: Bad parameter
// -38: File not open

extension Int32 {
    var appleString: String {
        let chars = Swift.withUnsafeBytes(of: self){ Data($0) }.map{ Character(Unicode.Scalar($0)) }
        return chars.reduce(true){ $0 && (UInt8(32)...127).contains($1.asciiValue ?? 0)} ? String(chars.reversed()) : "\(self)"
    }
}

//func int32ToString(_ code: OSStatus) -> String {
//    let chars = Swift.withUnsafeBytes(of: code){ Data($0) }.map{ Character(Unicode.Scalar($0)) }
//    return chars.reduce(true){ $0 && (UInt8(32)...127).contains($1.asciiValue ?? 0)} ? String(chars.reversed()) : "\(code)"
//}
    
//func int32ToString(_ code: OSType) -> String {
//    let chars = Swift.withUnsafeBytes(of: code){ Data($0) }.map{ Character(Unicode.Scalar($0)) }
//    return chars.reduce(true){ $0 && (UInt8(32)...127).contains($1.asciiValue ?? 0)} ? String(chars.reversed()) : "\(code)"
//}
    
func checkError(_ error: OSStatus, _ operation: String = "") {
    guard error != noErr else { return }
    print ("Error: \(operation) \(error.appleString).")
    exit(EXIT_FAILURE)
}

func throwIfError(_ error: OSStatus, _ operation: String = "") throws {
    guard error != noErr else { return }
    throw CAError.errorString(error, operation)
}
