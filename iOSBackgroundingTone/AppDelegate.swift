//
//  AppDelegate.swift
//  iOSBackgroundingTone
//
//  Created by Mark Erbaugh on 4/3/22.
//

import SwiftUI
import CoreAudio
import AudioToolbox
import AVFAudio

struct Settings {
    static let foreroundFrequency = 880.0
    static let backgroundFrequency = 523.25
    static let bufferCount = 3
    static let bufferDuration = 0.5
    static let sampleRate = 44100.0
}

struct MyPlayer {
    var startingFrameCount = 0.0
    var currentFrequency = Settings.foreroundFrequency
    var bufferSize = UInt32(0)
    var streamFormat = AudioStreamBasicDescription(mSampleRate: Settings.sampleRate,
                                                   mFormatID: kAudioFormatLinearPCM,
                                                   mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked, // kAudioFormatFlagsCanonical,
                                                   mBytesPerPacket: 2,
                                                   mFramesPerPacket: 1,
                                                   mBytesPerFrame: 2,
                                                   mChannelsPerFrame: 1,
                                                   mBitsPerChannel: 16,
                                                   mReserved: 0)
}

class AppDelegate /* : NSObject, UIApplicationDelegate */ {
    

    // func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    init() {
        var myPlayer = MyPlayer()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback, policy: .default)
        } catch {
            print ("Couldn't set category on audio session")
            return // false
        }
        var audioQueue: AudioQueueRef!
        
        checkError(AudioQueueNewOutput(&myPlayer.streamFormat,
                                       myAQOutputCallback,
                                       &myPlayer,
                                       nil,
                                       nil,
                                       0,
                                       &audioQueue),
                   "Couldn't create the output queue")
        
        myPlayer.bufferSize = UInt32(Settings.bufferDuration *
                                     myPlayer.streamFormat.mSampleRate *
                                     Double(myPlayer.streamFormat.mBytesPerFrame))
        for _ in 0..<Settings.bufferCount {
            var buffer: AudioQueueBufferRef!
            checkError(AudioQueueAllocateBuffer(audioQueue, myPlayer.bufferSize, &buffer),
                       "AudioQueueAllocateBuffer failed")
//            guard let buffer = buffer else {
//                print ("buffer nil")
//                return false
//            }
            checkError(fillBuffer(buffer: buffer, myPlayer: &myPlayer), "Couldn't fill buffer (priming)")
            checkError(AudioQueueEnqueueBuffer(audioQueue,
                                               buffer,
                                               0,
                                               nil),
                       "Couldn't enqueue buffer (priming)")
        }
        checkError(AudioQueueStart(audioQueue, nil), "Couldn't start the AudioQueue")
        return // true
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        
    }
    
}

func fillBuffer(buffer: AudioQueueBufferRef, myPlayer: UnsafeMutablePointer<MyPlayer>) -> OSStatus {
    var j = myPlayer.pointee.startingFrameCount
    let cycleLength = Settings.sampleRate / myPlayer.pointee.currentFrequency
    // print (cycleLength)
    let frameCount = myPlayer.pointee.bufferSize / myPlayer.pointee.streamFormat.mBytesPerFrame
    let data = buffer.pointee.mAudioData.bindMemory(to: Int16.self, capacity: Int(frameCount))
    for frame in 0..<Int(frameCount) {
        data[frame] = Int16(sin(2 * Double.pi * (j / cycleLength)) * 0x8000)
        // print (data[frame])
        j += 1.0
        if (j > cycleLength) {
            j -= cycleLength
        }
    }
    myPlayer.pointee.startingFrameCount = j
    buffer.pointee.mAudioDataByteSize = myPlayer.pointee.bufferSize
    return noErr
}


func myAQOutputCallback(inUserData: UnsafeMutableRawPointer?,
                        inAQ: AudioQueueRef,
                        inCompleteAQBuffer: AudioQueueBufferRef) {
    let myPlayer = inUserData!.assumingMemoryBound(to: MyPlayer.self)
    checkError(fillBuffer(buffer: inCompleteAQBuffer, myPlayer: myPlayer), "Can't refill buffer")
    checkError(AudioQueueEnqueueBuffer(inAQ,
                                       inCompleteAQBuffer,
                                       0,
                                       nil),
               "Couldn't enqueue the buffer (refill)")
    
}



