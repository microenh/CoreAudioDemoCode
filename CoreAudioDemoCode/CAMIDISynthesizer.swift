//
//  CAMIDISynthesizer.swift
//  CAMIDISynthesizer
//
//  Created by Mark Erbaugh on 4/5/22.
//

import CoreMIDI
import CoreAudio
import AudioToolbox

// MARK: State Struct
struct MyMIDIPLayer {
    var graph: AUGraph!
    var instrumentUnit: AudioUnit!
}

// MARK: utility functions
func setupAUGraph(player: UnsafeMutablePointer<MyMIDIPLayer>) throws {
    try throwIfError(NewAUGraph(&player.pointee.graph),
               "Couldn't open AU graph")
    // Generate desription that will match our output device (speakers)
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_DefaultOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    var outputNode = AUNode()
    try throwIfError(AUGraphAddNode(player.pointee.graph,
                              &outputcd,
                              &outputNode),
               "AUGraphAddnode[kAudioUnitSubType_DefaultOutput] failed")
    
    var instrumentcd = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                 componentSubType: kAudioUnitSubType_DLSSynth,
                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                 componentFlags: 0,
                                                 componentFlagsMask: 0)
    var instrumentNode = AUNode()
    try throwIfError(AUGraphAddNode(player.pointee.graph,
                              &instrumentcd,
                              &instrumentNode),
               "AUGraphAddNode[kAudioUnitSubType_DLSSynth] file")
    
    // Opening the graph opens all contained audio units but does not allocate any resources yet
    try throwIfError(AUGraphOpen(player.pointee.graph), "AUGraphOpen failed")
    
    // Get the reference to the AudioUnit object for the instrument graph node
    try throwIfError(AUGraphNodeInfo(player.pointee.graph,
                               instrumentNode,
                               nil,
                               &player.pointee.instrumentUnit),
               "AUGraphNodeInfo failed")
    
    // Connect the output source of the speech synthesis AU to the input source of the output node
    try throwIfError(AUGraphConnectNodeInput(player.pointee.graph,
                                       instrumentNode,
                                       0,
                                       outputNode,
                                       0),
               "AUGraphConnectNodeInput failed")
    
    // Now initialize the graph (causes resources to be allocated)
    try throwIfError(AUGraphInitialize(player.pointee.graph), "AUGraphInitialize failed")
}

func setupMIDI(player: UnsafeMutablePointer<MyMIDIPLayer>) throws {
    var client = MIDIClientRef()
    try throwIfError(MIDIClientCreate("Core MIDI to System Sounds Demo" as CFString,
                                myMIDINotifyProc,
                                player,
                                &client),
               "Couldn't create MIDI client")
    
    var inPort = MIDIPortRef()
    try throwIfError(MIDIInputPortCreate(client,
                                   "Input Port" as CFString,
                                   myMIDIReadProc,
                                   player,
                                   &inPort),
               "Couldn't create MIDI input port")
    
    let sourceCount = MIDIGetNumberOfSources()
    print ("\(sourceCount) sources")
    for i in 0..<sourceCount {
        let src = MIDIGetSource(i)
        var endpointName: Unmanaged<CFString>?
        try throwIfError(MIDIObjectGetStringProperty(src,
                                               kMIDIPropertyName,
                                               &endpointName),
                   "Couldn't get endpoint name")
        let endpointNameString = endpointName!.takeRetainedValue() as String
        print ("  source \(i): \(endpointNameString)")
        
        try throwIfError(MIDIPortConnectSource(inPort,
                                         src,
                                         nil),
                   "Couldn't connect MIDI port")
    }
    
}

// MARK: notify proc
func myMIDINotifyProc(message: UnsafePointer<MIDINotification>,
                      refCon: UnsafeMutableRawPointer?) {
    print("MIDI Notify, messageID=\(message.pointee.messageID)")
}

// MARK: read proc
func myMIDIReadProc(pktlist: UnsafePointer<MIDIPacketList>,
                    refCon: UnsafeMutableRawPointer?,
                    connRefCon: UnsafeMutableRawPointer?) {
    let player = refCon?.assumingMemoryBound(to: MyMIDIPLayer.self)
    
    
    pktlist.unsafeSequence().forEach{ packet in
        let midiStatus = packet.pointee.data.0
        let midiCommand = midiStatus >> 4
        
        if midiCommand == 0x08 || midiCommand == 0x09 {
            let note = packet.pointee.data.1 & 0x7f
            let velocity = packet.pointee.data.2 & 0x7f
            
            // print ("note: \(note)")
            
            checkError(MusicDeviceMIDIEvent(player!.pointee.instrumentUnit,
                                            UInt32(midiStatus),
                                            UInt32(note),
                                            UInt32(velocity),
                                            0),
                       "Couldn't send MIDI event")
        }
    }
    
}

// MARK: - main func
func main() throws {
    var player = MyMIDIPLayer()
    
    try setupAUGraph(player: &player)
    try setupMIDI(player: &player)
    
    try throwIfError(AUGraphStart(player.graph), "Couldn't start graph")
    CFRunLoopRun()
    // Run until aborted wtih Control-C
    return
}
