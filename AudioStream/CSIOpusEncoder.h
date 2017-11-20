//
//  CSIOpusAdapter.h
//  AudioStreamingOpus
//
//  Created by Roman on 10/25/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CSIOpusEncoder : NSObject
+ (CSIOpusEncoder *)getEncoder;
+ (CSIOpusEncoder*)encoderWithSampleRate:(double)sampleRate channels:(int)channels frameDuration:(double)frameDuration;

- (id)initWithSampleRate:(double)sampleRate channels:(int)channels frameDuration:(double)frameDuration;

- (NSArray *)encodeSample:(AVAudioPCMBuffer *) audioPCMBuffer;

- (NSArray *)encodeBufferList:(AudioBufferList *)audioBufferList;

@end
