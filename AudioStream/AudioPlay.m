//
//  AudioPlay.m
//  AudioStreamingOpus
//
//  Created by Roman on 11/5/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import "AudioPlay.h"
#import "CSIOpusEncoder.h"
#import "CSIOpusDecoder.h"
#include "CSIDataQueue.h"


#define RECV_BUFFER_SIZE 1024

#pragma mark Recording callback

OSStatus inputCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AudioPlay *audioProcessor = (__bridge AudioPlay*) inRefCon;
    AudioUnit ioUnit = audioProcessor.ioUnit;
    ioData = audioProcessor.ioData;
    OSStatus status = AudioUnitRender(ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    if(status != noErr) { NSLog(@"Failed to retrieve data from mic"); return noErr; }

//    [audioProcessor encodeAudio:ioData timestamp:inTimeStamp];
    
    return noErr;
}

OSStatus playCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AudioPlay *audioProcessor = (__bridge AudioPlay*) inRefCon;

    int bytesFilled = [audioProcessor.decoder tryFillBuffer:ioData];
    if(bytesFilled <= 0)
    {
        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    }
    
    return noErr;
}

#pragma mark objective-c class

@implementation AudioPlay
@synthesize audioUnit, audioBuffer, gain;
const AudioUnitElement pInputBusNumber = 1;
const AudioUnitElement pOutputBusNumber = 0;
-(AudioPlay*)init
{
    self = [super init];
    if (self) {
        gain = 5;
        self.sampleRate = 48000;
        
        [self setupAudioSession];
        [self initializeAudio];
        [self setupEncoder];
        [self setupDecoder];
        [self retriveData];
    }
    return self;
}

-(void)retriveData
{
    [[[_rootRef child:@"StreamChanels"] child:@"audioChanel"] observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
             
        NSString *bufferStr = snapshot.value;
        
        NSData *bufferData = [[NSData alloc] initWithBase64EncodedString:bufferStr options:0];
        
        dispatch_async(self.decodeQueue, ^{[self.decoder decode:bufferData];});
    }];
}
- (void)setupAudioSession
{
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setPreferredSampleRate:48000 error:&error];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setPreferredIOBufferDuration:0.02 error:&error];
    [audioSession setActive:YES error:&error];
    
    double sampleRate = audioSession.sampleRate;
    double ioBufferDuration = audioSession.IOBufferDuration;
    int samplesPerFrame = (int)(ioBufferDuration * sampleRate) + 1;
    int bytesPerSample = sizeof(AudioSampleType);
    int bytesPerFrame = samplesPerFrame * bytesPerSample;
    
    self.sampleRate = sampleRate;
    self.frameDuration = ioBufferDuration;
    self.samplesPerFrame = samplesPerFrame;
    self.bytesPerSample = bytesPerSample;
    self.bytesPerFrame = bytesPerFrame;
}

-(void)initializeAudio
{
    OSStatus status = noErr;
    
    AUGraph audioGraph;
    status = NewAUGraph(&audioGraph);
    if(status != noErr) { NSLog(@"Failed to create audio graph"); return; }
    self.audioGraph = audioGraph;
    
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideAudioRoute,
                             sizeof (audioRouteOverride),
                             &audioRouteOverride
                             );
    
    AudioComponentDescription ioUnitDesc;
    ioUnitDesc.componentType = kAudioUnitType_Output;
    ioUnitDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO;
    ioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioUnitDesc.componentFlags = 0;
    ioUnitDesc.componentFlagsMask = 0;
    self.ioUnitDesc = ioUnitDesc;
    
    AUNode ioNode;
    status = AUGraphAddNode(audioGraph, &ioUnitDesc, &ioNode);
    if(status != noErr) { NSLog(@"Failed to add mic to audio graph"); return; }
    status = AUGraphOpen(audioGraph);
    if(status != noErr) { NSLog(@"Failed to open audio graph"); return; }
    self.ioNode = ioNode;
    
    AudioUnit ioUnit;
    status = AUGraphNodeInfo(audioGraph, ioNode, &ioUnitDesc, &ioUnit);
    if(status != noErr) { NSLog(@"Failed to get mic handle from audio graph"); return; }
    self.ioUnit = ioUnit;
    
    UInt32 ioEnabled = 1;
    status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, pInputBusNumber, &ioEnabled, sizeof(ioEnabled));
    if(status != noErr) { NSLog(@"Failed to set IO enabled on mic"); return; }
    
    size_t bytesPerSample = self.bytesPerSample;
    
    AudioStreamBasicDescription monoStreamFormat = {0};
    monoStreamFormat.mFormatID          = kAudioFormatLinearPCM;
    monoStreamFormat.mFormatFlags       = kAudioFormatFlagsCanonical;
    monoStreamFormat.mBytesPerPacket    = bytesPerSample;
    monoStreamFormat.mFramesPerPacket   = 1;
    monoStreamFormat.mBytesPerFrame     = bytesPerSample;
    monoStreamFormat.mChannelsPerFrame  = 1;
    monoStreamFormat.mBitsPerChannel    = 8 * bytesPerSample;
    monoStreamFormat.mSampleRate        = self.sampleRate;
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, pInputBusNumber, &monoStreamFormat, sizeof(monoStreamFormat));
    if(status != noErr) { NSLog(@"Failed to set stream format on mic"); return; }
    
    AURenderCallbackStruct inputCallbackStruct;
    inputCallbackStruct.inputProc        = &inputCallback;
    inputCallbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, pInputBusNumber, &inputCallbackStruct, sizeof(inputCallbackStruct));
    if(status != noErr) { NSLog(@"Failed to set input callback on mic"); return; }
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, pOutputBusNumber, &monoStreamFormat, sizeof(monoStreamFormat));
    if(status != noErr) { NSLog(@"Failed to set stream format on speaker"); return; }
    
    AURenderCallbackStruct outputCallbackStruct;
    outputCallbackStruct.inputProc        = &playCallback;
    outputCallbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Output, pOutputBusNumber, &outputCallbackStruct, sizeof(outputCallbackStruct));
    if(status != noErr) { NSLog(@"Failed to set render callback on speaker"); return; }
    
    AudioBufferList *ioData = (AudioBufferList *)malloc(offsetof(AudioBufferList, mBuffers) + sizeof(AudioBuffer *));
    ioData->mNumberBuffers = 1;
    ioData->mBuffers[0].mNumberChannels = 1;
    ioData->mBuffers[0].mDataByteSize = self.bytesPerFrame;
    ioData->mBuffers[0].mData = malloc(self.bytesPerFrame);
    self.ioData = ioData;
    
    status = AUGraphInitialize(audioGraph);
    if(status != noErr) { NSLog(@"Failed to initialize audio graph"); return; }
    NSLog(@"Started");
    
    _rootRef = [[FIRDatabase database] reference];
}

#pragma mark controll stream

-(void)start;
{
    // start the audio unit. You should hear something, hopefully :)
    OSStatus status;
    status = AUGraphStart(self.audioGraph);
    [self hasError:status:__FILE__:__LINE__];
}
-(void)stop;
{
    // stop the audio unit
    OSStatus status = AUGraphStop(self.audioGraph);
    [self hasError:status:__FILE__:__LINE__];
}


-(void)setGain:(float)gainValue 
{
    gain = gainValue;
}

-(float)getGain
{
    return gain;
}
- (void)setupEncoder
{
    
    self.encoder = [CSIOpusEncoder encoderWithSampleRate:self.sampleRate channels:1 frameDuration:0.01];
}

- (void)setupDecoder
{
    self.decoder = [CSIOpusDecoder decoderWithSampleRate:self.sampleRate channels:1 frameDuration:0.01];
    self.decodeQueue = dispatch_queue_create("Decode Queue", nil);
}
#pragma mark Error handling

-(void)hasError:(int)statusCode:(char*)file:(int)line 
{
	if (statusCode) {
		printf("Error Code responded %d in file %s on line %d\n", statusCode, file, line);
        exit(-1);
	}
}


@end
