//
//  CARecorder.swift
//  CARecorder
//
//  Created by Mark Erbaugh on 3/14/22.
//

import AVFoundation

// MARK: Global Constants
struct Settings {
    static let fileName = "output.caf"
    static let numberRecordBuffers = 3
    static let formatID = kAudioFormatMPEG4AAC
    static let channels = UInt32(1)
    static let duration = Float(0.5)
}

// MARK: User Data Struct
struct MyRecorder {
    var recordFile: AudioFileID? = nil
    var recordPacket = Int64(0)
    var running = false
}

// MARK: Utility Functions
// checkError in CheckError.swift
func myGetDefaultInputDeviceSampleRate(outSampleRate: inout Float64) -> OSStatus {
    var error = noErr
    
    var deviceID = AudioDeviceID(0)
    var propertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
                                                     mScope: kAudioObjectPropertyScopeGlobal,
                                                     mElement: 0)
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    error = AudioObjectGetPropertyData(UInt32(kAudioObjectSystemObject),
                                       &propertyAddress,
                                       0,
                                       nil,
                                       &propertySize,
                                       &deviceID)
    
    guard error == noErr else { return error }
    
    propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate
    // propertyAddress.mScope = kAudioObjectPropertyScopeGlobal
    // propertyAddress.mElement = 0
    propertySize = UInt32(MemoryLayout<Float64>.size)
    error = AudioObjectGetPropertyData(deviceID,
                                       &propertyAddress,
                                       0,
                                       nil,
                                       &propertySize,
                                       &outSampleRate)
    return error
}

func myCopyEncoderCookieToFile(queue: AudioQueueRef, theFile: AudioFileID) {
    var propertySize = UInt32(0)
    let audioErr = AudioQueueGetPropertySize(queue,
                                             kAudioConverterCompressionMagicCookie,
                                             &propertySize)
    
    if audioErr == kAudioFormatUnsupportedPropertyError {   // (1886547824) 'prop'
        return  // format doesn't have magic cookie
    }
    
    checkError(audioErr, "AudioQueueGetPropertySize failed")
    guard propertySize > 0 else {
        print ("propertySize zero")
        return
    }
    let magicCookie = malloc(Int(propertySize))
    guard let magicCookie = magicCookie else {
        print ("malloc magicCookie failed")
        return
    }
    checkError(AudioQueueGetProperty(queue,
                                     kAudioQueueProperty_MagicCookie,
                                     magicCookie,
                                     &propertySize),
               "Couldn't get audio queue's magic cookie")
    checkError(AudioFileSetProperty(theFile,
                                    kAudioFilePropertyMagicCookieData,
                                    propertySize,
                                    magicCookie),
               "Couldn't set audio file's magic cookie")
    free(magicCookie)
}

func myComputeRecordBufferSize(format: AudioStreamBasicDescription, queue: AudioQueueRef, seconds: Float) -> UInt32 {
    var packets = UInt32(0)
    let frames = UInt32(ceil(seconds * Float(format.mSampleRate)))
    var bytes = UInt32(0)
    
    if format.mBytesPerFrame > 0 {
        bytes = frames * format.mBytesPerFrame
    } else {
        var maxPacketSize = UInt32(0)
        if format.mBytesPerPacket > 0 {
            // Constant packet size
            maxPacketSize = format.mBytesPerPacket
        } else {
            // Get the largest single packet size possible
            var propertySize = UInt32(MemoryLayout<UInt32>.size)
            checkError(AudioQueueGetProperty(queue,
                                             kAudioConverterPropertyMaximumOutputPacketSize,
                                             &maxPacketSize,
                                             &propertySize),
                       "Couldn't get queue's maximum output packet size")
        }
        if format.mFramesPerPacket > 0 {
            packets = frames / format.mFramesPerPacket
        } else {
            // Worst-case scenario: 1 frame in a packet
            packets = frames
        }
        // Sanity check
        if packets == 0 {
            packets = 1
        }
        bytes = packets * maxPacketSize
    }
    return bytes
}

// MARK: Record Callback Function
func myAQInputCallback(inUserData: UnsafeMutableRawPointer?,
                       inQueue: AudioQueueRef,
                       inBuffer: AudioQueueBufferRef,
                       inStartTime: UnsafePointer<AudioTimeStamp>,
                       inNumPackets: UInt32,
                       inPacketDesc: UnsafePointer<AudioStreamPacketDescription>?) {
    
    var inNumPackets = inNumPackets
    let recorder = inUserData?.assumingMemoryBound(to: MyRecorder.self)
    guard let recorder = recorder else { return }
    
    if inNumPackets > 0 {
        // Write packets to a file
        checkError(AudioFileWritePackets(recorder.pointee.recordFile!,
                                         false,
                                         inBuffer.pointee.mAudioDataByteSize,
                                         inPacketDesc,
                                         recorder.pointee.recordPacket,
                                         &inNumPackets,
                                         inBuffer.pointee.mAudioData),
                   "AudioFileWritePackets failed")
        recorder.pointee.recordPacket += Int64(inNumPackets)
    }
    if recorder.pointee.running {
        checkError(AudioQueueEnqueueBuffer(inQueue,
                                           inBuffer,
                                           0,
                                           nil),
                   "AudioQueueEnqueueBuffer failed")
    }
}

// MARK: - Main Function
func main() {
    var recorder = MyRecorder()
    var recordFormat = AudioStreamBasicDescription(mSampleRate: 0,
                                                   mFormatID: Settings.formatID,
                                                   mFormatFlags: 0,
                                                   mBytesPerPacket: 0,
                                                   mFramesPerPacket: 0,
                                                   mBytesPerFrame: 0,
                                                   mChannelsPerFrame: Settings.channels,
                                                   mBitsPerChannel: 0,
                                                   mReserved: 0)
    checkError(myGetDefaultInputDeviceSampleRate(outSampleRate: &recordFormat.mSampleRate),
               "myGetDefaultInputDeviceSampleRate failed")
    var propSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    checkError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                     0,
                                     nil,
                                     &propSize,
                                     &recordFormat),
               "AudioFormatGetProperty failed")
    
    var queue: AudioQueueRef?
    checkError(AudioQueueNewInput(&recordFormat,
                                  myAQInputCallback,
                                  &recorder,
                                  nil,
                                  nil,
                                  0,
                                  &queue),
               "AudioQueueNewInput failed")
        
    guard let queue = queue else {
        print ("queue failed")
        return
    }
    
    var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    
    checkError(AudioQueueGetProperty(queue,
                                     kAudioConverterCurrentOutputStreamDescription,
                                     &recordFormat,
                                     &size),
               "Couldn't get queue's format")
    
    
    let myFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                  Settings.fileName as CFString,
                                                  CFURLPathStyle.cfurlposixPathStyle,
                                                  false)
    
    checkError(AudioFileCreateWithURL(myFileURL!,
                                      kAudioFileCAFType,
                                      &recordFormat,
                                      AudioFileFlags.eraseFile,
                                      &recorder.recordFile),
               "AudioFileCreateWithURL failed")
    
    // CFRelease(myFileURL)
    
    let bufferByteSize = myComputeRecordBufferSize(format: recordFormat, queue: queue, seconds: Settings.duration)
    
    for _ in 0..<Settings.numberRecordBuffers {
        var buffer: AudioQueueBufferRef?
        checkError(AudioQueueAllocateBuffer(queue,
                                            bufferByteSize,
                                            &buffer),
                   "AudioQueueAllocateBuffer failed")
        guard let buffer = buffer else {
            print ("allocate buffer failure")
            return
        }
        checkError(AudioQueueEnqueueBuffer(queue, buffer, 0, nil),
                   "AudioQueueEnqueueBuffer failed")
    }
    recorder.running = true
    checkError(AudioQueueStart(queue, nil), "AudioQueueStart failed")
    print ("Recording, press <return> to stop")
    getchar()
    print ("* recording done *")
    recorder.running = false
    checkError(AudioQueueStop(queue, true), "AudioQueueStop failed")
    myCopyEncoderCookieToFile(queue: queue, theFile: recorder.recordFile!)
    AudioQueueDispose(queue, true)
    AudioFileClose(recorder.recordFile!)
    return
}
