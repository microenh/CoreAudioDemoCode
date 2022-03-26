//
//  main.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/13/22.
//

import Foundation

fileprivate func printError(_ statusCode: OSStatus, _ operation: String) {
    print("Error \(statusCode.appleString) \(operation)")
}

do {
    try main()
} catch CAError.errorString(let errorCode, let operation) {
    print ("Error: \(errorCode) on \(operation)")
} catch CAError.settingIO(let statusCode) {
    printError(statusCode, "setting IO")
} catch CAError.findDevice(let statusCode) {
    printError(statusCode, "finding device")
} catch CAError.newUnit(let statusCode) {
    printError(statusCode, "new AU")
} catch CAError.setCurrentDevice(let statusCode) {
    printError(statusCode, "setting current device")
} catch CAError.getAsbd(let statusCode) {
    printError(statusCode, "getting ABSD")
} catch CAError.setAsbd(let statusCode) {
    printError(statusCode, "setting ABSD")
} catch CAError.getBufferFrameSize(let statusCode) {
    printError(statusCode, "getting bufferFrameSize")
} catch CAError.setInputCallback(let statusCode) {
    printError(statusCode, "setting input callback")
} catch CAError.initializeAU(let statusCode) {
    printError(statusCode, "initializing AU")
} catch CAError.newGraph(let statusCode) {
    printError(statusCode, "new graph")
} catch CAError.addGraphNode(let statusCode) {
    printError(statusCode, "add graph node")
} catch CAError.openGraph(let statusCode) {
    printError(statusCode, "open graph")
} catch CAError.getUnit(let statusCode) {
    printError(statusCode, "get AU")
} catch CAError.connectNodes(let statusCode) {
    printError(statusCode, "connect nodes")
} catch CAError.setRenderCallback(let statusCode) {
    printError(statusCode, "setting render callback")
} catch CAError.initializeGraph(let statusCode) {
    printError(statusCode, "initializing graph")
} catch CAError.getSpeechChan(let statusCode) {
    printError(statusCode, "getting speech channel")
} catch CAError.auStart(let statusCode) {
    printError(statusCode, "start AU")
} catch CAError.graphStart(let statusCode) {
    printError(statusCode, "start graph")
// --
} catch is CAError {
    print ("Unhandled CAError")
} catch {
    print ("Unhandled error \(error)")
}
