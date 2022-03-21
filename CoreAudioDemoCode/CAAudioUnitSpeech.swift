//
//  CAAudioUnitSpeech.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/21/22.
//

import AVFoundation

// MARK: user-data struct
struct MyAUGraphPlayer {
    var graph: AUGraph!
    var speechAU: AudioUnit!
}

// MARK: utility functions
// throwIfError() from CheckError.swift

func createMyAUGraph(player: inout MyAUGraphPlayer) throws {
    // Create a new AUGraph
    try throwIfError(NewAUGraph(&player.graph), "NewAUGraph")
    
    // Generate a description that matches our output device (speakers)
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_DefaultOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    
    // Add a node with above description to the graph
    var outputNode = AUNode()
    try throwIfError(AUGraphAddNode(player.graph,
                                    &outputcd,
                                    &outputNode),
                     "AUGraphAddNode[kAudioUnitSubType_DefaultOutput]")
    
    // Generate a description that will match a generator AU of type: speech synthesizer
    var speechcd = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                             componentSubType: kAudioUnitSubType_SpeechSynthesis,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    // Add a node with above description to the graph
    var speechNode = AUNode()
    try throwIfError(AUGraphAddNode(player.graph,
                                    &speechcd,
                                    &speechNode),
                     "AUGraphAddNode[kAudioUnitSubType_SpeechSynthesis]")
    
    // Opening the graph opens all contains audio units, but does not allocate any resources yet
    try throwIfError(AUGraphOpen(player.graph), "AUGraphOpen")
    
    // Get the reference to the AudioUnit object for the speech synthesis graph node
    try throwIfError(AUGraphNodeInfo(player.graph,
                                     speechNode,
                                     nil,
                                     &player.speechAU),
                     "AUGraphNodeInfo")
    
#if PART_II
    print ("Part II")
#else
    // Connect the output source of the speech synthesis AU to the input source of the output node
    try throwIfError(AUGraphConnectNodeInput(player.graph,
                                             speechNode,
                                             0,
                                             outputNode,
                                             0),
                     "AUGraphConnectNodeInput")
    // Now initialize the graph (causes resources to be allocated)
    try throwIfError(AUGraphInitialize(player.graph), "AUGraphInitialize")
#endif
}

func prepareSpeechAU(player: inout MyAUGraphPlayer) throws {
    var chan = SpeechChannel.allocate(capacity: 1)
    var propSize = UInt32(MemoryLayout<SpeechChannel>.size)
    print (propSize)
    try throwIfError(AudioUnitGetProperty(player.speechAU,
                                          kAudioUnitProperty_SpeechChannel,
                                          kAudioUnitScope_Global,
                                          0,
                                          &chan,
                                          &propSize),
                     "AudioUnitGetProperty[kAudioUnitProperty_SpeechChannel]")
    try throwIfError(Int32(SpeakCFString(chan, "Hello World" as CFString, nil)), "SpeakCFString")
}

func main() throws {
    var player = MyAUGraphPlayer()
    
    // Build a basic speech->speakers graph
    try createMyAUGraph(player: &player)
    defer {
        print ("uninitialize graph")
        AUGraphUninitialize(player.graph)
        print ("close graph")
        AUGraphClose(player.graph)
    }
    
    // Configure the speec synthesizer
    try prepareSpeechAU(player: &player)
    
    // Start playing
    print ("Playing")// -10863 - cannot do in current context
    try throwIfError(AUGraphStart(player.graph), "AUGraphStart")
    defer {
        print ("Done")
        AUGraphStop(player.graph)
    }
    
    usleep(10 * 1_000_000)
}
