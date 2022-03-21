//
//  CAAudioUnitSpeech.swift
//  CAMetadata
//
//  Created by Mark Erbaugh on 3/21/22.
//

import AVFoundation


struct Settings {
    static let roomType = AUReverbRoomType.reverbRoomType_SmallRoom
    static let text = "Four score and seven years ago our forefathers brought forth on this continent a new nation" as CFString
}

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
    // Generate a description that mateches the reverb effect
    var reverbcd = AudioComponentDescription(componentType: kAudioUnitType_Effect,
                                             componentSubType: kAudioUnitSubType_MatrixReverb,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    // Add a node with the above description to the graph
    var reverbNode = AUNode()
    try throwIfError(AUGraphAddNode(player.graph,
                                    &reverbcd,
                                    &reverbNode),
                     "AUGraphAddNode[kAudioUnitSubType_MatrixReverb]")
    
    // Connect the output source of the speech synthesiser AU to the input source of the reverb node
    try throwIfError(AUGraphConnectNodeInput(player.graph,
                                             speechNode,
                                             0,
                                             reverbNode,
                                             0),
                     "AUGraphConnectNode (speech to reverb)")
    // Connect the output source of the reverb AU to the input source of the output node
    try throwIfError(AUGraphConnectNodeInput(player.graph,
                                             reverbNode,
                                             0,
                                             outputNode,
                                             0),
                     "AUGraphConnectNode (reverb to output)")
    
    // Get the reference ot the AudioUnit object for the reverb graph node
    var reverbUnit: AudioUnit?
    try throwIfError(AUGraphNodeInfo(player.graph,
                                 reverbNode,
                                 nil,
                                 &reverbUnit),
                 "AUGraphNodeInfo")
    // Now Initialize the grapho (this causes the resources to be allocated)
    try throwIfError(AUGraphInitialize(player.graph), "AUGraphInitialize")

    // Set the reverb preset for room size
    var roomType = Settings.roomType
    try throwIfError(AudioUnitSetProperty(reverbUnit!,
                                          kAudioUnitProperty_ReverbRoomType,
                                          kAudioUnitScope_Global,
                                          0,
                                          &roomType,
                                          UInt32(MemoryLayout<UInt32>.size)),
                     "AudioUnitSetProperty[kAudioUnitProperty_ReverbRoomType]")
    
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
    try throwIfError(AudioUnitGetProperty(player.speechAU,
                                          kAudioUnitProperty_SpeechChannel,
                                          kAudioUnitScope_Global,
                                          0,
                                          &chan,
                                          &propSize),
                     "AudioUnitGetProperty[kAudioUnitProperty_SpeechChannel]")
    try throwIfError(Int32(SpeakCFString(chan, Settings.text, nil)), "SpeakCFString")
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
    print ("Playing")
    try throwIfError(AUGraphStart(player.graph), "AUGraphStart")
    defer {
        print ("Done")
        AUGraphStop(player.graph)
    }
    
    usleep(10 * 1_000_000)
}
