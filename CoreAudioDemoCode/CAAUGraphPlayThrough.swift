//
//  CAAUGraphPlayThrough.swift
//  CAAUGraphPlayThrough
//
//  Created by Mark Erbaugh on 3/22/22.
//

import AVFoundation

#if PART_II
struct Settings {
    static let speakString = "Please purchase as many copies of our Core Audio book as you possibley can" as CFString
}
#endif

// MARK: user-data struct
struct MyAUGraphPlayer {
    var streamFormat = AudioStreamBasicDescription()
    
    var graph: AUGraph!
    var inputUnit: AudioUnit!
    var outputUnit: AudioUnit!
#if PART_II
    var speechUnit: AudioUnit!
#endif
    var inputBuffer: UnsafeMutableAudioBufferListPointer! // UnsafeMutablePointer<AudioBufferList>!
    var ringBuffer: RingBufferWrapper!
    
    var firstInputSampleTime = Float64(-1)
    var firstOutputSampleTime = Float64(-1)
    var inToOutSampleTimeOffset = Float64(-1)
}

// MARK: render procs

// MARK: utility functions
// throwIfError in CheckError.swift

func inputRenderProc(inRefCon: UnsafeMutableRawPointer,
                     ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                     inTimeStamp: UnsafePointer<AudioTimeStamp>,
                     inBusNumber: UInt32,
                     inNumberFrames: UInt32,
                     ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    
    var player = inRefCon.assumingMemoryBound(to: MyAUGraphPlayer.self).pointee
    
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
    
    var player = inRefCon.assumingMemoryBound(to: MyAUGraphPlayer.self).pointee

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


func createInputUnit(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    // Generate a description that matches audio HAL
    var inputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                            componentSubType: kAudioUnitSubType_HALOutput,
                                            componentManufacturer: kAudioUnitManufacturer_Apple,
                                            componentFlags: 0,
                                            componentFlagsMask: 0)

    let comp = AudioComponentFindNext(nil, &inputcd)
    guard let comp = comp else {
        print ("Can't get output unit")
        exit (-1)
    }
    try throwIfError(AudioComponentInstanceNew(comp, &player.pointee.inputUnit),
                     "open component for inputUnit")
    
    // enable I/O
    var disableFlag = UInt32(0)
    var enableFlag = UInt32(1)
    let outputBus = AudioUnitScope(0)
    let inputBus = AudioUnitScope(1)
    try throwIfError(AudioUnitSetProperty(player.pointee.inputUnit,
                                          kAudioOutputUnitProperty_EnableIO,
                                          kAudioUnitScope_Input,
                                          inputBus,
                                          &enableFlag,
                                          UInt32(MemoryLayout<UInt32>.size)),
                     "enable input on I/O unit")
    
    try throwIfError(AudioUnitSetProperty(player.pointee.inputUnit,
                                          kAudioOutputUnitProperty_EnableIO,
                                          kAudioUnitScope_Output,
                                          outputBus,
                                          &disableFlag,
                                          UInt32(MemoryLayout<UInt32>.size)),
                     "enable output on I/O unit")

    var defaultDevice = kAudioObjectUnknown
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var defaultDeviceProperty = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                           mScope: kAudioObjectPropertyScopeGlobal,
                                                           mElement: kAudioObjectPropertyElementMain)
    try throwIfError(AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject),
                                                &defaultDeviceProperty,
                                                0,
                                                nil,
                                                &propertySize,
                                                &defaultDevice),
                     "get default input device")

    try throwIfError(AudioUnitSetProperty(player.pointee.inputUnit,
                                          kAudioOutputUnitProperty_CurrentDevice,
                                          kAudioUnitScope_Global,
                                          outputBus,
                                          &defaultDevice,
                                          UInt32(MemoryLayout<AudioDeviceID>.size)),
                     "set default device on I/O unit")
    // print ("defaultDevice \(defaultDevice)")
    
    propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    try throwIfError(AudioUnitGetProperty(player.pointee.inputUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          inputBus,
                                          &player.pointee.streamFormat,
                                          &propertySize),
                     "get ASBD from input unit")
    var deviceFormat = AudioStreamBasicDescription()
    try throwIfError(AudioUnitGetProperty(player.pointee.inputUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          inputBus,
                                          &deviceFormat,
                                          &propertySize),
                     "get ASBD from input unit")
    
    print ("Device rate \(deviceFormat.mSampleRate), graph rate \(player.pointee.streamFormat.mSampleRate)")
    
    player.pointee.streamFormat.mSampleRate = deviceFormat.mSampleRate
    
    propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    try throwIfError(AudioUnitSetProperty(player.pointee.inputUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          inputBus,
                                          &player.pointee.streamFormat,
                                          propertySize),
                     "setting ASBD on input unit")
    
    var bufferSizeFrames = UInt32(0)
    propertySize = UInt32(MemoryLayout<UInt32>.size)
    try throwIfError(AudioUnitGetProperty(player.pointee.inputUnit,
                                          kAudioDevicePropertyBufferFrameSize,
                                          kAudioUnitScope_Global,
                                          0,
                                          &bufferSizeFrames,
                                          &propertySize),
                     "get buffer frame size from input unit")
    let bufferSizeBytes = bufferSizeFrames * UInt32(MemoryLayout<Float32>.size)
    
    print ("format is \(player.pointee.streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved > 0 ? "non-" : "")interleaved")
    let channelCount = Int(player.pointee.streamFormat.mChannelsPerFrame)
    let abl = AudioBufferList.allocate(maximumBuffers: channelCount)
    for i in 0..<channelCount {
        abl[i] = AudioBuffer(mNumberChannels: 1,
                             mDataByteSize: bufferSizeBytes,
                             mData: malloc(Int(bufferSizeBytes)))
    }
    player.pointee.inputBuffer = abl
        
    // Allocate ring buffer that will hold data between the two audio devices
    player.pointee.ringBuffer = CreateRingBuffer()
    AllocateBuffer(player.pointee.ringBuffer,
                   Int32(player.pointee.streamFormat.mChannelsPerFrame),
                   player.pointee.streamFormat.mBytesPerFrame,
                   bufferSizeFrames * 3)
    
    // Set render proc to supply samples from input unit
    var callbackStruct = AURenderCallbackStruct(inputProc: inputRenderProc,
                                                inputProcRefCon: player)
    try throwIfError(AudioUnitSetProperty(player.pointee.inputUnit,
                                          kAudioOutputUnitProperty_SetInputCallback,
                                          kAudioUnitScope_Global,
                                          0,
                                          &callbackStruct,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                     "setting input callback")
    
    try throwIfError(AudioUnitInitialize(player.pointee.inputUnit),
                     "initialize input unit")
    
    player.pointee.firstInputSampleTime = -1
    player.pointee.inToOutSampleTimeOffset = -1
    
    print ("Bottom of CreateInputUnit()")
}

func createMyAUGraph(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    
    // Create a new AUGraph
    try throwIfError(NewAUGraph(&player.pointee.graph),
                     "New AUGraph")
    
    // Generate a description that matched default output
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_DefaultOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    let comp = AudioComponentFindNext(nil, &outputcd)
    guard let _ = comp else {
        print ("can't get output unit")
        exit (-1)
    }
    // Adds a node with above description to graph
    var outputNode = AUNode()
    
    try throwIfError(AUGraphAddNode(player.pointee.graph,
                                    &outputcd,
                                    &outputNode),
                     "AUGraphAddNode[kAudioUnitSubType_DefaultOutput]")
    
#if PART_II
    // Add a mixer to the graph
    var mixercd = AudioComponentDescription(componentType: kAudioUnitType_Mixer,
                                            componentSubType: kAudioUnitSubType_StereoMixer,
                                            componentManufacturer: kAudioUnitManufacturer_Apple,
                                            componentFlags: 0,
                                            componentFlagsMask: 0)
    var mixerNode: AUNode = 0
    try throwIfError(AUGraphAddNode(player.pointee.graph,
                                    &mixercd,
                                    &mixerNode),
                     "AUGraphAddNode[kAudioUniteSubType_StereoMixer]")
    
    // Add the speech synthesizer to the graph
    var speechcd = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                             componentSubType: kAudioUnitSubType_SpeechSynthesis,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    var speechNode: AUNode = 0
    try throwIfError(AUGraphAddNode(player.pointee.graph,
                                    &speechcd,
                                    &speechNode),
                     "AUGraphAddNode[kAudioUniteSubType_SpeechSynthesis]")
    // Opening the graph opens all contained audio units but does not allocate any resources yet
    try throwIfError(AUGraphOpen(player.pointee.graph), "AUGraphOpen")
    
    // Get the reference to the AudioUnit objects for the various nodes
    try throwIfError(AUGraphNodeInfo(player.pointee.graph,
                                     outputNode,
                                     nil,
                                     &player.pointee.outputUnit),
                     "AUGraphNodeInfo")
    try throwIfError(AUGraphNodeInfo(player.pointee.graph,
                                     speechNode,
                                     nil,
                                     &player.pointee.speechUnit),
                     "AUGraphNodeInfo")
    var mixerUnit: AudioUnit!
    try throwIfError(AUGraphNodeInfo(player.pointee.graph,
                                     mixerNode,
                                     nil,
                                     &mixerUnit),
                     "AUGraphNodeInfo")
    // Set ASBD's here
    var propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    // Set stream format on input scope of bus 0 because of the render callback will be plug in at this scope
    try throwIfError(AudioUnitSetProperty(mixerUnit, //player.pointee.outputUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          0,
                                          &player.pointee.streamFormat,
                                          propertySize),
                     "set stream format on output unit")
    // Set output stream format on speech unit and mixer unit to let stream format propagation happens
    try throwIfError(AudioUnitSetProperty(player.pointee.speechUnit,  // mixerUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output, // kAudioUnitScope_Input,
                                          0,
                                          &player.pointee.streamFormat,
                                          propertySize),
                     "set stream format on speect unit bus 0")
    try throwIfError(AudioUnitSetProperty(mixerUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Output,
                                          0,
                                          &player.pointee.streamFormat,
                                          propertySize),
                     "set stream format on mixer unit bus 0")
    
    // Connections
    // Mixer output scope / bus 0 to outputUnit input scope / bus 0
    // Mixer input  scope / bus 0 to render callback
    //  (from ringbuffer, which in turn is from inputUnit)
    // Mixer input  scope / bus 1 to speech unit outpu scope / bus 0
    
    try throwIfError(AUGraphConnectNodeInput(player.pointee.graph,
                                             mixerNode,
                                             0,
                                             outputNode,
                                             0),
                     "connecting mixer output(0) to outputNode(0)")
    try throwIfError(AUGraphConnectNodeInput(player.pointee.graph,
                                             speechNode,
                                             0,
                                             mixerNode,
                                             1),
                     "connecting speech synth output(0) to mixer input (1)")

    var callbackStruct = AURenderCallbackStruct(inputProc: graphRenderProc, inputProcRefCon: player)
    
    try throwIfError(AudioUnitSetProperty(mixerUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Global,
                                          0,
                                          &callbackStruct,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                     "Setting render callback on mixer unit")
    CAShowFile(UnsafeMutableRawPointer(player.pointee.graph), stdout)
    
/*
 AudioUnitGraph 0x1596B0AD:
   Member Nodes:
     node 1: 'auou' 'def ' 'appl', instance 0x9596b0ae O  // OUTPUT
     node 2: 'aumx' 'smxr' 'appl', instance 0x9596b0b0 O  // MIXER  (calls graphRenderProc - gets data from RingBuffer)
     node 3: 'augn' 'ttsp' 'appl', instance 0x9596b0b1 O  // SPEECH SYNTHESIS
   Connections:
     node   2 bus   0 => node   1 bus   0  [ 2 ch,  44100 Hz, Float32, deinterleaved]
     node   3 bus   0 => node   2 bus   1  [ 2 ch,  44100 Hz, Float32, deinterleaved]
   CurrentState:
     mLastUpdateError=0, eventsToProcess=F, isInitialized=F, isRunning=F
 */
#else
    // Opening the graph opens all contained audio units but does not allocate any resources yet
    try throwIfError(AUGraphOpen(player.pointee.graph), "AUGraphOpen")
                     
    // Get the reference to the AudioUnit object for the output graph node
    try throwIfError(AUGraphNodeInfo(player.pointee.graph,
                                     outputNode,
                                     nil,
                                     &player.pointee.outputUnit),
                     "AUGraphNodeInfo")
    
    // Set the stream format on the outpu unit's input scope
    let propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    try throwIfError(AudioUnitSetProperty(player.pointee.outputUnit,
                                          kAudioUnitProperty_StreamFormat,
                                          kAudioUnitScope_Input,
                                          0,
                                          &player.pointee.streamFormat,
                                          propertySize),
                     "Set stream format on output unit")
    
    var callbackStruct = AURenderCallbackStruct(inputProc: graphRenderProc, inputProcRefCon: player)
    
    try throwIfError(AudioUnitSetProperty(player.pointee.outputUnit,
                                          kAudioUnitProperty_SetRenderCallback,
                                          kAudioUnitScope_Global,
                                          0,
                                          &callbackStruct,
                                          UInt32(MemoryLayout<AURenderCallbackStruct>.size)),
                     "Setting render callback on output unit")
    
#endif
    // Now initialze the graph (causes resource to be allocated)
    try throwIfError(AUGraphInitialize(player.pointee.graph), "AUGraphInitialize")
    
    player.pointee.firstOutputSampleTime = -1
    print ("Bottom of CreateAUGraph()")
}

#if PART_II
func prepareSpeechAU(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    var chan: SpeechChannel?
    var propsize = UInt32(MemoryLayout<SpeechChannelRecord>.size)
    
    try throwIfError(AudioUnitGetProperty(player.pointee.speechUnit,
                                          kAudioUnitProperty_SpeechChannel,
                                          kAudioUnitScope_Global,
                                          0,
                                          &chan,
                                          &propsize),
                     "AudioFileGetProperty[kAudioUnitProperty_SpeechChannel]")
    
    SpeakCFString(chan!,
                  Settings.speakString,
                  nil)
    print ("Bottom of prepareSpeechAU()")
}
#endif

// MARK: - main function
func main() throws {
    
    var player = MyAUGraphPlayer()
    // Create the input unit
    try createInputUnit(player: &player)
    
    // Build a graph with output unit
    try createMyAUGraph(player: &player)
    defer {
        AUGraphUninitialize(player.graph)
        AUGraphClose(player.graph)
    }
    
#if PART_II
    // Configure the speech synthesizer
    try prepareSpeechAU(player: &player)
#endif
        
    // Start playing
    try throwIfError(AudioOutputUnitStart(player.inputUnit), "AudioOutputUnitStart")
    try throwIfError(AUGraphStart(player.graph), "AUGraphStart")
    defer {
        AUGraphStop(player.graph)
    }
    // and wait
    print ("Capturing, press <return> to stop:")
    getchar()
    // cleanup
}
