//
//  CAAudioUnitPlayer.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 3/20/22.
//

import AVFoundation

// MARK: Settings
struct Settings {
    static let inputFileName = "/Users/mark/Documents/CASoundFiles/output.mp3"
}

 
// MARK: Utility functions
// throwIfError from CheckError.swift
func createMyAUGraph(player: inout MyAUGraphPlayer) throws {
    // Create a new AUGraph
    try throwIfError(NewAUGraph(&player.graph), "NewAUGraph")
    
    // Generate description that matched output device (speakers)
    var outputcd = AudioComponentDescription(componentType: kAudioUnitType_Output,
                                             componentSubType: kAudioUnitSubType_DefaultOutput,
                                             componentManufacturer: kAudioUnitManufacturer_Apple,
                                             componentFlags: 0,
                                             componentFlagsMask: 0)
    // Adds a node with above description to the graph
    var outputNode = AUNode()
    try throwIfError(AUGraphAddNode(player.graph,
                                    &outputcd,
                                    &outputNode),
                     "AUGraphAddNode Player")
    // Generate description that matcheds a generator AU of type: audio file player
    var fileplayercd = AudioComponentDescription(componentType: kAudioUnitType_Generator,
                                                 componentSubType: kAudioUnitSubType_AudioFilePlayer,
                                                 componentManufacturer: kAudioUnitManufacturer_Apple,
                                                 componentFlags: 0,
                                                 componentFlagsMask: 0)
    // Adds a node with above description to the graph
    var fileNode = AUNode()
    try throwIfError(AUGraphAddNode(player.graph,
                                    &fileplayercd,
                                    &fileNode),
                     "AUGraphAddNode File")
    // Opening the graph opens all contained audio units but does not allocate any resource yet
    try throwIfError(AUGraphOpen(player.graph), "AUGraphOpen")
    // Get the reference ot the AudioUnit object for the file player graph node
    try throwIfError(AUGraphNodeInfo(player.graph,
                                     fileNode,
                                     nil,
                                     &player.fileAU),
                     "AUGraphNodeInfo")
    // Connect the output source of the file player AU to the input source of the output node
    try throwIfError(AUGraphConnectNodeInput(player.graph,
                                             fileNode,
                                             0,
                                             outputNode,
                                             0),
                     "AUGraphConnectNode")
    // Now initialize the graph (causes resources to be allocated)
    try throwIfError(AUGraphInitialize(player.graph),
                     "AUGraphInitialize")
}

func prepareFileAU(player: inout MyAUGraphPlayer) throws -> UInt32 {
    // Tell the file player unit to load the file we want to play
    try throwIfError(AudioUnitSetProperty(player.fileAU,
                                          kAudioUnitProperty_ScheduledFileIDs,
                                          kAudioUnitScope_Global,
                                          0,
                                          &player.inputFile,
                                          UInt32(MemoryLayout<AudioFileID>.size)),
                     "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileIds]")
    var nPackets = UInt64(0)
    var propSize = UInt32(MemoryLayout<UInt64>.size)
    try throwIfError(AudioFileGetProperty(player.inputFile,
                                          kAudioFilePropertyAudioDataPacketCount,
                                          &propSize,
                                          &nPackets),
                     "AudioFileGetProperty[kAudioFilePropertyAudioDataPacketCount]")
    // Tell the file player AU to play the entore file
    var rgn = ScheduledAudioFileRegion(mTimeStamp: AudioTimeStamp(),
//    var rgn = ScheduledAudioFileRegion(mTimeStamp: AudioTimeStamp(mSampleTime: 0,
//                                                                  mHostTime: 0,
//                                                                  mRateScalar: 0,
//                                                                  mWordClockTime: 0,
//                                                                  mSMPTETime: SMPTETime(),
//                                                                  mFlags: .sampleTimeValid,
//                                                                  mReserved: 0),
                                       mCompletionProc: nil,
                                       mCompletionProcUserData: nil,
                                       mAudioFile: player.inputFile,
                                       mLoopCount: 0,
                                       mStartFrame: 0,
                                       mFramesToPlay: UInt32(nPackets) * player.inputFormat.mFramesPerPacket)
    try throwIfError(AudioUnitSetProperty(player.fileAU,
                                          kAudioUnitProperty_ScheduledFileRegion,
                                          kAudioUnitScope_Global,
                                          0,
                                          &rgn,
                                          UInt32(MemoryLayout<ScheduledAudioFileRegion>.size)),
                     "AudioUnitSetProperty[kAudioUnitProperty_ScheduledFileRegion]")
    // Tell the file player AU when to start playing (-1 sample time means next render cycle)
    var startTime = AudioTimeStamp(mSampleTime: -1,
                                   mHostTime: 0,
                                   mRateScalar: 0,
                                   mWordClockTime: 0,
                                   mSMPTETime: SMPTETime(),
                                   mFlags: .sampleTimeValid,
                                   mReserved: 0)
    try throwIfError(AudioUnitSetProperty(player.fileAU,
                                          kAudioUnitProperty_ScheduleStartTimeStamp,
                                          kAudioUnitScope_Global,
                                          0,
                                          &startTime,
                                          UInt32(MemoryLayout<AudioTimeStamp>.size)),
                     "AudioUnitSetProperty_ScheduleStartTimeStamp")
    // File duration
    return UInt32(nPackets) * player.inputFormat.mFramesPerPacket / UInt32(player.inputFormat.mSampleRate)
}

// MARK: User data struct
struct MyAUGraphPlayer {
    var inputFormat = AudioStreamBasicDescription()
    var inputFile: AudioFileID!
    var graph: AUGraph!
    var fileAU: AudioUnit!
}

// MARK: - Main function
func main() throws {
    let inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                     Settings.inputFileName as CFString,
                                                     CFURLPathStyle.cfurlposixPathStyle,
                                                     false)
    var player = MyAUGraphPlayer()
    // Open the input audio file
    try throwIfError(AudioFileOpenURL(inputFileURL!,
                                      AudioFilePermissions.readPermission,
                                      0,
                                      &player.inputFile),
                 "AudioFileOpenURL")
    
    defer {
        AudioFileClose(player.inputFile)
    }
    // Get the audio data format from the file
    var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    try throwIfError(AudioFileGetProperty(player.inputFile,
                                          kAudioFilePropertyDataFormat,
                                          &propSize,
                                          &player.inputFormat),
                     "AudioFileGetProperty")
    
    // Build a basic fileplayer->speaker graph
    try createMyAUGraph(player: &player)
    defer {
        AUGraphUninitialize(player.graph)
        AUGraphClose(player.graph)
    }
    
    // Configure the file player
    let fileDuration = try prepareFileAU(player: &player)
    
    // Start playing
    print ("Playing")
    try throwIfError(AUGraphStart(player.graph), "AUGraphStart")
    defer {
        print ("Done")
        AUGraphStop(player.graph)
    }
    
    // Sleep until the file is finished
    usleep(fileDuration * 1_000_000)
}
