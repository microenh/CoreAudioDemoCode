//
//  CAAUGraphPlayThrough.swift
//  CAAUGraphPlayThrough
//
//  Created by Mark Erbaugh on 3/22/22.
//

import AVFoundation

#if PART_II
struct Settings {
    static let speakString = "The program is running" as CFString
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

// MARK: utility functions
// throwIfError in CheckError.swift

func createInputUnit(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    // Ger input unit from HAL
    player.pointee.inputUnit = try AudioUnit.new(componentType: kAudioUnitType_Output,
                                                 componentSubType: kAudioUnitSubType_HALOutput)
    // enable I/O
    try player.pointee.inputUnit.setIO(inputScope: true, inputBus: true, enable: true)
    try player.pointee.inputUnit.setIO(inputScope: false, inputBus: false, enable: false)

    // get default default input device
    let defaultDevice = try AudioObjectID.find(mSelector: kAudioHardwarePropertyDefaultInputDevice)
    
    // manually override input device
    // defaultDevice = 57
    // print (defaultDevice)
    
    try player.pointee.inputUnit.setCurrentDevice(device: defaultDevice, inputBus: false)
        
    try player.pointee.streamFormat = player.pointee.inputUnit.getABSD(inputScope: false, inputBus: true)
    let deviceFormat = try player.pointee.inputUnit.getABSD(inputScope: true, inputBus: true)
    
    print ("in:  \(deviceFormat)")
    print ("out: \(player.pointee.streamFormat)")
    
    player.pointee.streamFormat.mSampleRate = deviceFormat.mSampleRate
    
    try player.pointee.inputUnit.setABSD(absd: player.pointee.streamFormat, inputScope: false, inputBus: true)
    
    let bufferSizeFrames = try player.pointee.inputUnit.getBufferFrameSize()
    let bufferSizeBytes = bufferSizeFrames * UInt32(MemoryLayout<Float32>.size)
    
    print ("format is \(player.pointee.streamFormat.mFormatFlags & kAudioFormatFlagIsNonInterleaved > 0 ? "non-" : "")interleaved")
    
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

func createMyAUGraph(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    
    // Create a new AUGraph
    try player.pointee.graph = AUGraph.new()
    let outputNode = try player.pointee.graph.addNode(componentType: kAudioUnitType_Output,
                                                      componentSubType: kAudioUnitSubType_DefaultOutput)
#if PART_II
    // Add a mixer to the graph
    let mixerNode = try player.pointee.graph.addNode(componentType: kAudioUnitType_Mixer,
                                                     componentSubType: kAudioUnitSubType_StereoMixer)
    // Add the speech synthesizer to the graph
    let speechNode = try player.pointee.graph.addNode(componentType: kAudioUnitType_Generator,
                                                      componentSubType: kAudioUnitSubType_SpeechSynthesis)
    // Opening the graph opens all contained audio units but does not allocate any resources yet
    try player.pointee.graph.open()
    
    // Get the reference to the AudioUnit objects for the various nodes
    player.pointee.outputUnit = try player.pointee.graph.getNodeAU(node: outputNode)
    player.pointee.speechUnit = try player.pointee.graph.getNodeAU(node: speechNode)
    let mixerUnit = try player.pointee.graph.getNodeAU(node: mixerNode)

    // Set ASBD's here
    // Set stream format on input scope of bus 0 because of the render callback will be plug in at this scope
    // per book
    /*
    try player.pointee.outputUnit.setABSD(absd: player.pointee.streamFormat, inputScope: true)
    try mixerUnit.setABSD(absd: player.pointee.streamFormat, inputScope: true)
    try mixerUnit.setABSD(absd: player.pointee.streamFormat, inputScope: false)
    */
    
    // alternate
    try mixerUnit.setABSD(absd: player.pointee.streamFormat, inputScope: true)
    // Set output stream format on speech unit and mixer unit to let stream format propagation happens
    try player.pointee.speechUnit.setABSD(absd: player.pointee.streamFormat, inputScope: false)
    try mixerUnit.setABSD(absd: player.pointee.streamFormat, inputScope: false)

    // Connections
    // Mixer output scope / bus 0 to outputUnit input scope / bus 0
    // Mixer input  scope / bus 0 to render callback
    //  (from ringbuffer, which in turn is from inputUnit)
    // Mixer input  scope / bus 1 to speech unit output scope / bus 0
    try player.pointee.graph.connectNodes(node1: mixerNode, bus1: 0, node2: outputNode, bus2: 0)
    try player.pointee.graph.connectNodes(node1: speechNode, bus1: 0, node2: mixerNode, bus2: 1)
    
    try mixerUnit.setRenderCallback(inputProc: graphRenderProc, inputProcRefCon: player)
    
    // CAShowFile(UnsafeMutableRawPointer(player.pointee.graph), stdout)
    
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
    try player.pointee.graph.open()
    // Get the reference to the AudioUnit object for the output graph node
    player.pointee.outputUnit = try player.pointee.graph.getNodeAU(node: outputNode)
    
    // Set the stream format on the output unit's input scope
    try player.pointee.outputUnit.setABSD(absd: player.pointee.streamFormat, inputScope: true)

    try player.pointee.outputUnit.setRenderCallback(inputProc: graphRenderProc, inputProcRefCon: player)
    
#endif
    
    // force desired output soundcard
//    var outputDeviceID: AudioDeviceID = 78  // replace with actual, dynamic value
//    AudioUnitSetProperty(player.pointee.outputUnit,
//                         kAudioOutputUnitProperty_CurrentDevice,
//                         kAudioUnitScope_Global,
//                         0,
//                         &outputDeviceID,
//                         UInt32(MemoryLayout<AudioDeviceID>.size))

    // Now initialze the graph (causes resource to be allocated)
    try player.pointee.graph.initialze()
    
    player.pointee.firstOutputSampleTime = -1
    print ("Bottom of CreateAUGraph()")
}

#if PART_II
func prepareSpeechAU(player: UnsafeMutablePointer<MyAUGraphPlayer>) throws {
    let chan = try player.pointee.speechUnit.getSpeechChannel()
    SpeakCFString(chan, Settings.speakString, nil)
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
    try player.inputUnit.start()
    try player.graph.start()
    
    defer {
        AUGraphStop(player.graph)
    }
    
    // and wait
    print ("Capturing, press <return> to stop:")
    getchar()
    // cleanup
}
