//
//  AudioProcessor.h
//  AudioStreamingOpus
//
//  Created by Roman on 10/28/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "CSIOpusEncoder.h"
#import "CSIOpusDecoder.h"
#include "CSIDataQueue.h"
@import Firebase;

// return max value for given values
#define max(a, b) (((a) > (b)) ? (a) : (b))
// return min value for given values
#define min(a, b) (((a) < (b)) ? (a) : (b))

#define kOutputBus 0
#define kInputBus 1

// our default sample rate
#define SAMPLE_RATE 48000.00

@interface AudioProcessor : NSObject
{
    // Audio unit
    AudioComponentInstance audioUnit;
    
    // Audio buffers
	AudioBuffer audioBuffer;
    
    // gain
    float gain;
}

@property (nonatomic) AudioBufferList *outputEncodedBufferList;
@property (nonatomic, retain) NSMutableArray *encodedBuffers;
@property (readonly) AudioBuffer audioBuffer;
@property (readonly) AudioComponentInstance audioUnit;
@property (assign) AudioBufferList *ioData;
@property (assign) AUNode ioNode;
@property (assign) AudioUnit ioUnit;
@property (nonatomic) float gain;
@property (strong) CSIOpusEncoder *encoder;
@property (strong) CSIOpusDecoder *decoder;
@property (nonatomic) BOOL isRecording;
@property (nonatomic, retain) FIRDatabaseReference *rootRef;
@property (assign) AUGraph audioGraph;
@property (assign) AudioComponentDescription ioUnitDesc;
@property (assign) double sampleRate;
@property (assign) int bytesPerSample;
@property (assign) int bytesPerFrame;
@property (assign) double frameDuration;
@property (assign) int samplesPerFrame;

@property (strong) dispatch_queue_t decodeQueue;
-(AudioProcessor*)init;
-(void)encodeAudio:(AudioBufferList *)data timestamp:(const AudioTimeStamp *)timestamp;
-(void)initializeAudio;
- (AudioBufferList *)getBufferListFromData:(NSData *)data;
// control object
-(void)start;
-(void)stop;

// gain
-(void)setGain:(float)gainValue;
-(float)getGain;

// error managment
-(void)hasError:(int)statusCode:(char*)file:(int)line;

@end
