//
//  CAAudioEnginePlayThroughMEE.swift
//  CAAudioEnginePlayThroughMEE
//
//  Created by Mark Erbaugh on 3/28/22.
//

import AVFoundation

#if PART_II
struct Settings {
    static let speakString = "The engine is running" as CFString
}
#endif

// MARK: user-data struct
struct MyAUEnginePlayer {
    var streamFormat = AudioStreamBasicDescription()
    
    var engine = AVAudioEngine()
    var inputUnit: AudioUnit!
    var outputUnit: AudioUnit!
    
#if PART_II
    var speechUnit: AudioUnit!
#endif
    
    var inputBuffer: UnsafeMutableAudioBufferListPointer!
    var ringBuffer: RingBufferWrapper!
    
    var inToOutSampleTimeOffset = Float64(-2)
}

// MARK: render procs
func inputRenderProc(inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    let player = inRefCon.assumingMemoryBound(to: MyAUEnginePlayer.self)
        
    if player.pointee.inToOutSampleTimeOffset < -1 {
        player.pointee.inToOutSampleTimeOffset = -1
    }
    
//    let hostTime = Double(inTimeStamp.pointee.mHostTime)
//
//    print ((hostTime - player.pointee.prevTicks) * player.pointee.audioFreq)
//    player.pointee.prevTicks = hostTime
    
    var inputProcErr = AudioUnitRender(player.pointee.inputUnit,
                                       ioActionFlags,
                                       inTimeStamp,
                                       inBusNumber,
                                       inNumberFrames,
                                       player.pointee.inputBuffer.unsafeMutablePointer)
    
    if inputProcErr == 0 {
        inputProcErr = StoreBuffer(player.pointee.ringBuffer,
                                   player.pointee.inputBuffer.unsafeMutablePointer,
                                   inNumberFrames,
                                   Int64(inTimeStamp.pointee.mSampleTime))
        
        
//        let adjStartTime = inTimeStamp.pointee.mSampleTime //  - player.pointee.inToOutSampleTimeOffset
//        let adjEndTime = adjStartTime + Double(inNumberFrames)
//        var startTime = SampleTime()
//        var endTime = SampleTime()
//        _ = GetTimeBoundsFromBuffer(player.pointee.ringBuffer, &startTime, &endTime)
//        print ("\(startTime) \(adjStartTime) \(adjEndTime) \(endTime)")
    } else {
        print (inputProcErr)
    }
    return inputProcErr
}

// MARK: utility functions
func createInputUnit(player: UnsafeMutablePointer<MyAUEnginePlayer>) throws {
    // Ger input unit from HAL
    player.pointee.inputUnit = try AudioUnit(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_HALOutput)
    // enable I/O
    try player.pointee.inputUnit.setIO(scope: kAudioUnitScope_Input, inputBus: 1, enable: true)
    try player.pointee.inputUnit.setIO(scope: kAudioUnitScope_Output, inputBus: 0, enable: false)

    // get default default input device
    let defaultDevice = try AudioObjectID.find(mSelector: kAudioHardwarePropertyDefaultInputDevice)
    
    // manually override input device
    // defaultDevice = 57
    // print (defaultDevice)
    
    try player.pointee.inputUnit.setCurrentDevice(device: defaultDevice, inputBus: 0)
        
    try player.pointee.streamFormat = player.pointee.inputUnit.getABSD(scope: kAudioUnitScope_Output, element: 1)
    let deviceFormat = try player.pointee.inputUnit.getABSD(scope: kAudioUnitScope_Input, element: 1)
    
//     print ("in:  \(deviceFormat)")
//     print ("out: \(player.pointee.streamFormat)")
    
    player.pointee.streamFormat.mSampleRate = deviceFormat.mSampleRate
    
    try player.pointee.inputUnit.setABSD(absd: player.pointee.streamFormat, scope: kAudioUnitScope_Output, element: 1)
    
    let bufferSizeFrames = try player.pointee.inputUnit.getBufferFrameSize()
    let bufferSizeBytes = bufferSizeFrames * UInt32(MemoryLayout<Float32>.size)
    
    // print ("format is \(player.pointee.streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved > 0 ? "non-" : "")interleaved")
    
    let channelCount = Int(player.pointee.streamFormat.mChannelsPerFrame)
    
    player.pointee.inputBuffer = AudioBufferList.allocate(maximumBuffers: channelCount)
    for i in 0..<channelCount {
        player.pointee.inputBuffer[i] = AudioBuffer(mNumberChannels: 1,
                                                    mDataByteSize: bufferSizeBytes,
                                                    mData: malloc(Int(bufferSizeBytes)))
    }
    // Allocate ring buffer that will hold data between the two audio devices
    player.pointee.ringBuffer = CreateRingBuffer()
    AllocateBuffer(player.pointee.ringBuffer,
                   Int32(player.pointee.streamFormat.mChannelsPerFrame),
                   player.pointee.streamFormat.mBytesPerFrame,
                   bufferSizeFrames * 3)
    
    // Set render proc to supply samples from input unit
    try player.pointee.inputUnit.setInputCallback(inputProc: inputRenderProc, inputProcRefCon: player)
    
    try player.pointee.inputUnit.initialize()
    
    player.pointee.inToOutSampleTimeOffset = -2
    
    print ("Bottom of CreateInputUnit()")
    
}

func createMyAVEngine(player: UnsafeMutablePointer<MyAUEnginePlayer>) throws {
        
    let outputNode = player.pointee.engine.outputNode
    player.pointee.outputUnit = outputNode.audioUnit
    
    let outputFormat = outputNode.inputFormat(forBus: 0)
    
    let inputFormat = AVAudioFormat(commonFormat: outputFormat.commonFormat,
                                    sampleRate: player.pointee.streamFormat.mSampleRate,
                                    channels: 1,
                                    interleaved: outputFormat.isInterleaved)
    
//    print ("inputFormat: \(inputFormat!)")

//    let audioFreq = 1.0 / AudioGetHostClockFrequency()
//    var prevTicks = Float64(0)

     
    let srcNode = AVAudioSourceNode(format: inputFormat!) { isSilence, inTimeStamp, frameCount, ioData -> OSStatus in
        
//        let hostTime = Double(inTimeStamp.pointee.mHostTime)
//        print ("time: \((hostTime - prevTicks) * audioFreq), samples: \(frameCount)")
//        prevTicks = hostTime

        
        if player.pointee.inToOutSampleTimeOffset == -1 {
            var startTime = SampleTime()
            var endTime = SampleTime()
            if GetTimeBoundsFromBuffer(player.pointee.ringBuffer, &startTime, &endTime) == 0 {
                player.pointee.inToOutSampleTimeOffset = inTimeStamp.pointee.mSampleTime - Double(startTime)
//                print ("setting \(player.pointee.inToOutSampleTimeOffset)")
            }

        }
        
        
        let adjStartTime = inTimeStamp.pointee.mSampleTime - player.pointee.inToOutSampleTimeOffset
//        let adjEndTime = adjStartTime + Double(frameCount)
//        var startTime = SampleTime()
//        var endTime = SampleTime()
//        _ = GetTimeBoundsFromBuffer(player.pointee.ringBuffer, &startTime, &endTime)
//        print ("available: \(startTime)-\(endTime) - requested: \(adjStartTime) \(adjEndTime)")
        
        
        // copy samples out of ring buffer
        let outputProcErr = FetchBuffer(player.pointee.ringBuffer,
                                        ioData,
                                        frameCount,
                                        Int64(adjStartTime))
        // isSilence.pointee = ObjCBool(outputProcErr != 0)
                
        if outputProcErr > 0 {
            print (outputProcErr)
        }
        return noErr
    }
    
//    for i in 0..<srcNode.numberOfInputs {
//        print ("input[\(i)] format: \(srcNode.inputFormat(forBus: i))")
//        print ("name: \(srcNode.name(forInputBus: 0) ?? "<none>")")
//    }
//
//    for i in 0..<srcNode.numberOfOutputs {
//        print ("input[\(i)] format: \(srcNode.outputFormat(forBus: i))")
//        print ("name: \(srcNode.name(forOutputBus: i) ?? "<none>")")
//    }

    player.pointee.engine.attach(srcNode)
    
    // get the engine's mixer node
    let mixerNode = player.pointee.engine.mainMixerNode
#if PART_II
        
    // add the speech synthesizer to the graph
    let cd = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                       componentSubType: kAudioUnitSubType_SpeechSynthesis)
    let speechNode = AVAudioUnitGenerator(audioComponentDescription: cd)
    player.pointee.engine.attach(speechNode)
    player.pointee.speechUnit = speechNode.audioUnit
    
    player.pointee.engine.connect(speechNode, to: mixerNode, fromBus: 0, toBus: 1, format: nil)
#endif
//    player.pointee.engine.connect(srcNode, to: outputNode, format: nil)
    player.pointee.engine.connect(srcNode, to: mixerNode, fromBus: 0, toBus: 0, format: inputFormat)
    player.pointee.engine.connect(mixerNode, to: outputNode, fromBus: 0, toBus: 0, format: nil)
    print ("Bottom of createMyAVEngine()")
}

#if PART_II
func prepareSpeechAU(player: UnsafeMutablePointer<MyAUEnginePlayer>) throws {
    let chan = try player.pointee.speechUnit.getSpeechChannel()
    SpeakCFString(chan, Settings.speakString, nil)
    print ("Bottom of prepareSpeechAU()")
}
#endif

func main() throws {
    var player = MyAUEnginePlayer()
    
    // create the input unit
    try createInputUnit(player: &player)
    defer {
        for i in 0..<player.inputBuffer.count {
            free(player.inputBuffer[i].mData)
        }
        // TODO: how to free the audio buffer list?
        // free(&player.inputBuffer!)
        AudioComponentInstanceDispose(player.inputUnit)
        DeallocateBuffer(player.ringBuffer)
    }
    
    // build an engine with the output unit
    try createMyAVEngine(player: &player)
#if PART_II
    // Configure the speech synthesizer
    try prepareSpeechAU(player: &player)
#endif
    

    player.engine.prepare()
    try player.engine.start()
    defer {
        player.engine.stop()
        player.engine.reset()
    }
    try player.inputUnit.start()
    
    // and wait
    print ("Capturing, press <return> to stop:")
    getchar()
}
