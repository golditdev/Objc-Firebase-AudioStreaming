//
//  AudioProcessor.m
//  AudioStreamingOpus
//
//  Created by Roman on 10/28/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import "AudioProcessor.h"
#import "CSIOpusEncoder.h"
#import "CSIOpusDecoder.h"
#include "CSIDataQueue.h"


#define RECV_BUFFER_SIZE 1024

#pragma mark Recording callback

OSStatus recordCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AudioProcessor *audioProcessor = (__bridge AudioProcessor*) inRefCon;
    AudioUnit ioUnit = audioProcessor.ioUnit;
    ioData = audioProcessor.ioData;
    OSStatus status = AudioUnitRender(ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    if(status != noErr) { NSLog(@"Failed to retrieve data from mic"); return noErr; }

    [audioProcessor encodeAudio:ioData timestamp:inTimeStamp];
    
    return noErr;
}

OSStatus renderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{

    memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}

#pragma mark objective-c class
const AudioUnitElement kInputBusNumber = 1;
const AudioUnitElement kOutputBusNumber = 0;
@implementation AudioProcessor
@synthesize audioUnit, audioBuffer, gain;

-(AudioProcessor*)init
{
    self = [super init];
    if (self) {
        gain = 5;
        self.sampleRate = 48000;
        
        [self setupAudioSession];
        [self initializeAudio];
        [self setupEncoder];
        [self setupDecoder];
    }
    return self;
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
    status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBusNumber, &ioEnabled, sizeof(ioEnabled));
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
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBusNumber, &monoStreamFormat, sizeof(monoStreamFormat));
    if(status != noErr) { NSLog(@"Failed to set stream format on mic"); return; }
    
    AURenderCallbackStruct inputCallbackStruct;
    inputCallbackStruct.inputProc        = &recordCallback;
    inputCallbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, kInputBusNumber, &inputCallbackStruct, sizeof(inputCallbackStruct));
    if(status != noErr) { NSLog(@"Failed to set input callback on mic"); return; }
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBusNumber, &monoStreamFormat, sizeof(monoStreamFormat));
    if(status != noErr) { NSLog(@"Failed to set stream format on speaker"); return; }
    
    AURenderCallbackStruct outputCallbackStruct;
    outputCallbackStruct.inputProc        = &renderCallback;
    outputCallbackStruct.inputProcRefCon  = (__bridge void *)(self);
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Output, kOutputBusNumber, &outputCallbackStruct, sizeof(outputCallbackStruct));
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

- (void)encodeAudio:(AudioBufferList *)data timestamp:(const AudioTimeStamp *)timestamp
{
    SInt16 *editBuffer = data->mBuffers[0].mData;

    // loop over every packet
    for (int nb = 0; nb < (data->mBuffers[0].mDataByteSize / 2); nb++) {

        // we check if the gain has been modified to save resoures
        if (gain != 0) {
            // we need more accuracy in our calculation so we calculate with doubles
            double gainSample = ((double)editBuffer[nb]) / 32767.0;

            /*
            at this point we multiply with our gain factor
            we dont make a addition to prevent generation of sound where no sound is.

             no noise
             0*10=0

             noise if zero
             0+10=10
            */
            gainSample *= gain;

            /**
             our signal range cant be higher or lesser -1.0/1.0
             we prevent that the signal got outside our range
             */
            gainSample = (gainSample < -1.0) ? -1.0 : (gainSample > 1.0) ? 1.0 : gainSample;

            /*
             This thing here is a little helper to shape our incoming wave.
             The sound gets pretty warm and better and the noise is reduced a lot.
             Feel free to outcomment this line and here again.

             You can see here what happens here http://silentmatt.com/javascript-function-plotter/
             Copy this to the command line and hit enter: plot y=(1.5*x)-0.5*x*x*x
             */

            gainSample = (1.5 * gainSample) - 0.5 * gainSample * gainSample * gainSample;

            // multiply the new signal back to short
            gainSample = gainSample * 32767.0;
            
            // write calculate sample back to the buffer
            editBuffer[nb] = (SInt16)gainSample;
        }
    }

    NSArray *encodedSamples = [self.encoder encodeBufferList:data];
    for (NSData *encodedSample in encodedSamples) {
        //        NSLog(@"Encoded %d bytes", encodedSample.length);
        NSString *stringForm = [encodedSample base64EncodedStringWithOptions:0];
        
        [[[_rootRef child:@"StreamChanels"] child:@"audioChanel"] setValue:stringForm];
        
//        dispatch_async(self.decodeQueue, ^{[self.decoder decode:encodedSample];});
    }
}

- (NSString*)CurrentTimestamp {
    long long milliseconds = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);

    return [NSString stringWithFormat:@"%lld",milliseconds];
}

- (AudioBufferList *)getBufferListFromData:(NSData *)data
{
    if (data.length > 0)
    {
        NSUInteger len = [data length];
        //I guess you can use Byte*, void* or Float32*. I am not sure if that makes any difference.
        Byte * byteData = (Byte*) malloc (len);
        memcpy (byteData, [data bytes], len);
        if (byteData)
        {
            AudioBufferList * theDataBuffer =(AudioBufferList*)malloc(sizeof(AudioBufferList) * 1);
            theDataBuffer->mNumberBuffers = 1;
            theDataBuffer->mBuffers[0].mDataByteSize = len;
            theDataBuffer->mBuffers[0].mNumberChannels = 1;
            theDataBuffer->mBuffers[0].mData = byteData;
            // Read the data into an AudioBufferList
            return theDataBuffer;
        }
    }
    return nil;
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
