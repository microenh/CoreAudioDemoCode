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
    
    var firstInputSampleTime = Float64(-1)
    var firstOutputSampleTime = Float64(-1)
    var inToOutSampleTimeOffset = Float64(-1)
}

// MARK: render procs
func inputRenderProc(inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    var player = inRefCon.assumingMemoryBound(to: MyAUEnginePlayer.self).pointee
    
    // Have we ever logged input timing? (for offset calculation)
    if player.firstInputSampleTime < 0 {
        player.firstInputSampleTime = inTimeStamp.pointee.mSampleTime
        if player.firstOutputSampleTime > 0 && player.inToOutSampleTimeOffset < 0 {
            player.inToOutSampleTimeOffset = player.firstInputSampleTime - player.firstOutputSampleTime
        }
    }
    
    var inputProcErr = AudioUnitRender(player.inputUnit,
                                       ioActionFlags,
                                       inTimeStamp,
                                       inBusNumber,
                                       inNumberFrames,
                                       player.inputBuffer.unsafeMutablePointer)
    
    if inputProcErr == 0 {
        inputProcErr = StoreBuffer(player.ringBuffer,
                                   player.inputBuffer.unsafeMutablePointer,
                                   inNumberFrames,
                                   Int64(inTimeStamp.pointee.mSampleTime))
    }
    return inputProcErr
}


func graphRenderProc(inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    var player = inRefCon.assumingMemoryBound(to: MyAUEnginePlayer.self).pointee

    // Have we ever logged input timing? (for offset calculation)
    if player.firstOutputSampleTime < 0 {
        player.firstOutputSampleTime = inTimeStamp.pointee.mSampleTime
        if player.firstInputSampleTime > 0 && player.inToOutSampleTimeOffset < 0 {
            player.inToOutSampleTimeOffset = player.firstInputSampleTime - player.firstOutputSampleTime
        }
    }
    
    // copy samples out of ring buffer
    let outputProcErr = FetchBuffer(player.ringBuffer,
                                    ioData,
                                    inNumberFrames,
                                    Int64(inTimeStamp.pointee.mSampleTime + player.inToOutSampleTimeOffset))
    return outputProcErr
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
    
    // print ("in:  \(deviceFormat)")
    // print ("out: \(player.pointee.streamFormat)")
    
    player.pointee.streamFormat.mSampleRate = deviceFormat.mSampleRate
    
    try player.pointee.inputUnit.setABSD(absd: player.pointee.streamFormat, scope: kAudioUnitScope_Output, element: 1)
    
    let bufferSizeFrames = try player.pointee.inputUnit.getBufferFrameSize()
    let bufferSizeBytes = bufferSizeFrames * UInt32(MemoryLayout<Float32>.size)
    
    // print ("format is \(player.pointee.streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved > 0 ? "non-" : "")interleaved")
    
    let channelCount = Int(player.pointee.streamFormat.mChannelsPerFrame)
    
    // TODO: Should the .allocate and malloc be freed?
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
    
    player.pointee.firstInputSampleTime = -1
    player.pointee.inToOutSampleTimeOffset = -1
    
    print ("Bottom of CreateInputUnit()")
    
}

func createMyAVEngine(player: UnsafeMutablePointer<MyAUEnginePlayer>) throws {
        
    let outputNode = player.pointee.engine.outputNode
    player.pointee.outputUnit = outputNode.audioUnit
    
    let outputFormat = outputNode.inputFormat(forBus: 0)
    
    let inputFormat = AVAudioFormat(commonFormat: outputFormat.commonFormat,
                                    sampleRate: outputFormat.sampleRate,
                                    channels: 2,
                                    interleaved: outputFormat.isInterleaved)
    
    let srcNode = AVAudioSourceNode { isSilence, inTimeStamp, frameCount, ioData -> OSStatus in
        if player.pointee.firstOutputSampleTime < 0 {
            player.pointee.firstOutputSampleTime = inTimeStamp.pointee.mSampleTime
            if player.pointee.firstInputSampleTime > 0 && player.pointee.inToOutSampleTimeOffset < 0 {
                player.pointee.inToOutSampleTimeOffset = player.pointee.firstInputSampleTime - player.pointee.firstOutputSampleTime
            }
        }
        
        // copy samples out of ring buffer
        let outputProcErr = FetchBuffer(player.pointee.ringBuffer,
                                        ioData,
                                        frameCount,
                                        Int64(inTimeStamp.pointee.mSampleTime + player.pointee.inToOutSampleTimeOffset))
        // isSilence.pointee = ObjCBool(outputProcErr != 0)
        if outputProcErr > 0 {
            print (outputProcErr)
        }
        return noErr
    }
    
    
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
    
    player.pointee.engine.connect(speechNode, to: mixerNode, format: inputFormat)

#endif
    player.pointee.engine.connect(srcNode, to: mixerNode, format: inputFormat)
    player.pointee.engine.connect(mixerNode, to: outputNode, format: inputFormat)
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
    
    // build an engine with the output unit
    try createMyAVEngine(player: &player)
#if PART_II
    // Configure the speech synthesizer
    try prepareSpeechAU(player: &player)
#endif
    
    // try player.inputUnit.start()
    player.engine.prepare()
    try player.engine.start()
    defer {
        player.engine.stop()
        player.engine.reset()
    }
    
    // and wait
    print ("Capturing, press <return> to stop:")
    getchar()
}
