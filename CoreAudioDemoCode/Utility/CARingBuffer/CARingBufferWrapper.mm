//
//  CARingBufferWrapper.m
//  CallCPPFromSwift
//
//  Created by Mark Erbaugh on 3/23/22.
//

// based on https://github.com/derekli66/Learning-Core-Audio-Swift-SampleCode

#include "CARingBufferWrapper.h"
#include "CARingBuffer.h"

RingBufferWrapper CreateRingBuffer()
{
    RingBufferWrapper wrapper = {0};
    CARingBuffer* ringBuffer = new CARingBuffer();
    wrapper.ringBufferPtr = static_cast<void *>(ringBuffer);
    return wrapper;
}

void DestroyBuffer(RingBufferWrapper wrapper)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    delete buffer;
    buffer = nullptr;
    wrapper.ringBufferPtr = nullptr;
}

void AllocateBuffer(RingBufferWrapper wrapper, int nChannels, UInt32 bytesPerFrame, UInt32 capacityFrames)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    buffer->Allocate(nChannels, bytesPerFrame, capacityFrames);
}

void DeallocateBuffer(RingBufferWrapper wrapper)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    buffer->Deallocate();
}

CARingBufferError StoreBuffer(RingBufferWrapper wrapper, const AudioBufferList *abl, UInt32 nFrames, SampleTime frameNumber)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    return buffer->Store(abl, nFrames, frameNumber);
}

CARingBufferError FetchBuffer(RingBufferWrapper wrapper, AudioBufferList *abl, UInt32 nFrames, SampleTime frameNumber)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    return buffer->Fetch(abl, nFrames, frameNumber);
}

CARingBufferError GetTimeBoundsFromBuffer(RingBufferWrapper wrapper, SampleTime *startTime, SampleTime *endTime)
{
    CARingBuffer *buffer = static_cast<CARingBuffer*>(wrapper.ringBufferPtr);
    return buffer->GetTimeBounds(*startTime, *endTime);
}
