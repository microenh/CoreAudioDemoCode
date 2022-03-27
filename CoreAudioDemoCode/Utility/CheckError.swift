//
//  CheckError.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/14/22.
//

import Foundation

enum CAError: Error {
    case errorString(OSStatus, String)
    case componentNotFound
    case settingIO(OSStatus)
    case findDevice(OSStatus)
    case newUnit(OSStatus)
    case setCurrentDevice(OSStatus)
    case getAsbd(OSStatus)
    case setAsbd(OSStatus)
    case getBufferFrameSize(OSStatus)
    case setInputCallback(OSStatus)
    case initializeAU(OSStatus)
    case newGraph(OSStatus)
    case addGraphNode(OSStatus)
    case openGraph(OSStatus)
    case getUnit(OSStatus)
    case connectNodes(OSStatus)
    case setRenderCallback(OSStatus)
    case initializeGraph(OSStatus)
    case getSpeechChan(OSStatus)
    case auStart(OSStatus)
    case graphStart(OSStatus)
    
//    var description: String {
//        switch self {
//        case .errorString(_, _):
//            return ""
//        case .componentNotFound:
//            return ""
//        case .settingIO(_):
//            return "setting I/O"
//        case .findDevice(_):
//            return "finding device"
//        case .newUnit(_):
//            return "new AU"
//        case .setCurrentDevice(_):
//            return "setting current device"
//        case .getAsbd(_):
//            return  "getting ABSD"
//        case .setAsbd(_):
//            return "setting ABSD"
//        case .getBufferFrameSize(_):
//            return "getting BufferFrameSize"
//        case .setInputCallback(_):
//            return "setting input callback"
//        case .initializeAU(_):
//            return "initializing AU"
//        case .newGraph(_):
//            return "new graph"
//        case .addGraphNode(_):
//            return "add graph node"
//        case .openGraph(_):
//            return "open graph"
//        case .getUnit(_):
//            return "get AU"
//        case .connectNodes(_):
//            return "connect nodes"
//        case .setRenderCallback(_):
//            return "setting render callback"
//        case .initializeGraph(_):
//            return "initialize graph"
//        case .getSpeechChan(_):
//            return "getting speec channel"
//        case .auStart(_):
//            return "start AU"
//        case .graphStart(_):
//            return "start graph"
//        }
//    }
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

func printError(_ statusCode: OSStatus, _ operation: String) {
    print("Error \(statusCode.appleString) \(operation)")
}



func checkError(_ error: OSStatus, _ operation: String = "") {
    guard error != noErr else { return }
    print ("Error: \(operation) \(error.appleString).")
    exit(EXIT_FAILURE)
}

func throwIfError(_ error: OSStatus, _ operation: String = "") throws {
    guard error != noErr else { return }
    throw CAError.errorString(error, operation)
}
