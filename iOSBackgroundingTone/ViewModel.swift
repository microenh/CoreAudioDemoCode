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
    var audioQueue: AudioQueueRef!
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

class ViewModel {
    
    var myPlayer = MyPlayer()
    
    init() {
        // there are issues with myPlayer if stattApplication is renamed init() (to be called directly)
        startApplication()
    }
    
    func setupNotifications() {
        // Get the default notification center instance.
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance)
    }

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                  return
              }
        
        // Switch over the interruption type.
        switch type {
            
        case .began:
            // An interruption began. Update the UI as necessary.
            break
            
        case .ended:
            // An interruption ended. Resume playback, if appropriate.
            checkError(AudioQueueStart(myPlayer.audioQueue, nil), "Couldn't restart the AudioQueue")
            
        default: ()
        }
    }

    func startApplication() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .moviePlayback, policy: .default)
        } catch {
            print ("Couldn't set category on audio session")
            return // false
        }
        
        var audioQueueLocal: AudioQueueRef?
        
        checkError(AudioQueueNewOutput(&myPlayer.streamFormat,
                                       myAQOutputCallback,
                                       &myPlayer,
                                       nil,
                                       nil,
                                       0,
                                       &audioQueueLocal),
                   "Couldn't create the output queue")
        
        myPlayer.audioQueue = audioQueueLocal
        myPlayer.bufferSize = UInt32(Settings.bufferDuration *
                                     myPlayer.streamFormat.mSampleRate *
                                     Double(myPlayer.streamFormat.mBytesPerFrame))
        for _ in 0..<Settings.bufferCount {
            var buffer: AudioQueueBufferRef!
            checkError(AudioQueueAllocateBuffer(myPlayer.audioQueue, myPlayer.bufferSize, &buffer),
                       "AudioQueueAllocateBuffer failed")
            checkError(fillBuffer(buffer: buffer, myPlayer: &myPlayer), "Couldn't fill buffer (priming)")
            checkError(AudioQueueEnqueueBuffer(myPlayer.audioQueue,
                                               buffer,
                                               0,
                                               nil),
                       "Couldn't enqueue buffer (priming)")
        }
        setupNotifications()
        checkError(AudioQueueStart(myPlayer.audioQueue, nil), "Couldn't start the AudioQueue")
    }
    
    func applicationDidEnterBackground() {
        myPlayer.currentFrequency = Settings.backgroundFrequency
    }
    
    func applicationWillEnterForeground() {
        // this block necessary if application is restarting after interruption
        // it doesn't do any harm if application is just moving from background to foreground
        do {
            try AVAudioSession.sharedInstance().setActive(true)

        } catch {
            print ("Couldn't reset audio session active")
            exit(1)
        }
        checkError(AudioQueueStart(myPlayer.audioQueue, nil), "Couldn't restart the AudioQueue")
        // end of restart block
        
        myPlayer.currentFrequency = Settings.foreroundFrequency
    }
    
    
}

func fillBuffer(buffer: AudioQueueBufferRef, myPlayer: UnsafeMutablePointer<MyPlayer>) -> OSStatus {
    var j = myPlayer.pointee.startingFrameCount
    let cycleLength = Settings.sampleRate / myPlayer.pointee.currentFrequency
    // print (cycleLength)
    let frameCount = myPlayer.pointee.bufferSize / myPlayer.pointee.streamFormat.mBytesPerFrame
    let data = buffer.pointee.mAudioData.bindMemory(to: Int16.self, capacity: Int(frameCount))
    for frame in 0..<Int(frameCount) {
        data[frame] = Int16(sin(2 * Double.pi * (j / cycleLength)) * 0x7fff)
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



