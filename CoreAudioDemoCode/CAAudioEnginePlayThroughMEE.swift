//
//  CAAudioEnginePlayThroughMEE.swift
//  CAAudioEnginePlayThroughMEE
//
//  Created by Mark Erbaugh on 3/28/22.
//

import AVFoundation

// MARK: user-data struct
struct MyAUEnginePlayer {
    var streamFormat = AudioStreamBasicDescription()
    
    var engine = AVAudioEngine()
    var inputUnit: AudioUnit!
    
#if PART_II
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
    
    print ("in:  \(deviceFormat)")
    print ("out: \(player.pointee.streamFormat)")
    
    player.pointee.streamFormat.mSampleRate = deviceFormat.mSampleRate
    
    try player.pointee.inputUnit.setABSD(absd: player.pointee.streamFormat, scope: kAudioUnitScope_Output, element: 1)
    
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

func createMyAVEngine(player: UnsafeMutablePointer<MyAUEnginePlayer>) throws {
    

    
    
    
    print ("Bottom of createMyAVEngine()")
}

func main() throws {
    var player = MyAUEnginePlayer()
    
    // create the input unit
    try createInputUnit(player: &player)
    
    // build an engine with the output unit
    try createMyAVEngine(player: &player)
}
