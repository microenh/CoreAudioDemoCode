//
//  CAMetadata.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/12/22.
//

import Foundation
import AVFoundation

func main() {
    guard CommandLine.argc > 1 else {
        print("Usage: \(CommandLine.arguments[0]) /full/path/to/audiofile")
        return
    }
    
    var theError = noErr
    
    let audioFileName = (CommandLine.arguments[1] as NSString).expandingTildeInPath
    let audioURL = NSURL(fileURLWithPath: audioFileName)
    
    var audioFile: AudioFileID?
    theError = AudioFileOpenURL(audioURL, .readPermission, 0, &audioFile)
    
    guard theError == noErr, let audioFile = audioFile else { return }
    
    var dictionarySize = UInt32(0)
    var isWriteable = UInt32(0)
    
    theError = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, &isWriteable)
    
    guard theError == noErr else { return }
    
    let dictionaryPtr = malloc(Int(dictionarySize))
    
    guard let dictionaryPtr = dictionaryPtr else { return }
    
    theError = AudioFileGetProperty(audioFile, kAudioFilePropertyInfoDictionary, &dictionarySize, dictionaryPtr)
    
    guard theError == noErr else { return }
    
    let dictionary = dictionaryPtr.load(as: CFDictionary.self)
    dictionaryPtr.deallocate()
    
    print (dictionary)
}

