//
//  TestCARingBuffer.swift
//  CoreAudioDemoCode
//
//  Created by Mark Erbaugh on 4/20/22.
//

import XCTest

class TestCARingBuffer: XCTestCase {

    var ringBuffer: RingBufferWrapper?

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let ringBuffer = CreateRingBuffer()
        XCTAssertNotNil(ringBuffer)
        AllocateBuffer(ringBuffer, 1, 1, 100)
        
        var startTime = SampleTime()
        var endTime = SampleTime()
        GetTimeBoundsFromBuffer(ringBuffer, &startTime, &endTime)
        XCTAssertEqual(startTime, endTime)
        
        let mDataIn = malloc(10)
        defer {
            free(mDataIn)
        }
        
        let audioBufferIn = AudioBuffer(mNumberChannels: 1, mDataByteSize: 10, mData: mDataIn)
        var ablIn = AudioBufferList(mNumberBuffers: 1, mBuffers: (audioBufferIn))
        
        let ptrIn = mDataIn!.assumingMemoryBound(to: UInt8.self)
        for i in 0..<9 {
            ptrIn[i] = UInt8(i + 1)
        }
        
        XCTAssertEqual(ptrIn[0], 1)
        XCTAssertEqual(ptrIn[1], 2)
        XCTAssertEqual(StoreBuffer(ringBuffer, &ablIn, 10, 0), 0)
        XCTAssertEqual(ptrIn[0], 1)
        XCTAssertEqual(ptrIn[1], 2)
        
        GetTimeBoundsFromBuffer(ringBuffer, &startTime, &endTime)
        XCTAssertEqual(startTime, 0)
        XCTAssertEqual(endTime, 10)
        
        let mDataOut = malloc(2)
        defer {
            free(mDataOut)
        }
        let ptrOut = mDataOut!.assumingMemoryBound(to: UInt8.self)
        for i in 0..<2 {
            ptrOut[i] = 9
        }
        XCTAssertEqual(ptrOut[0], 9)
        XCTAssertEqual(ptrOut[1], 9)

        let audioBufferOut = AudioBuffer(mNumberChannels: 1, mDataByteSize: 2, mData: mDataOut)
        var ablOut = AudioBufferList(mNumberBuffers: 1, mBuffers: (audioBufferOut))
        
        XCTAssertEqual(FetchBuffer(ringBuffer, &ablOut, 9, 0), 0)
        GetTimeBoundsFromBuffer(ringBuffer, &startTime, &endTime)
        XCTAssertEqual(startTime, 0)
        XCTAssertEqual(endTime, 10)


        
        XCTAssertEqual(ptrOut[0], 1)
        XCTAssertEqual(ptrOut[1], 2)
    }

}
