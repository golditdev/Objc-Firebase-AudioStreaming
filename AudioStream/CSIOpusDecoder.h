//
//  CSIOpusDecoder.h
//  AudioStreamingOpus
//
//  Created by Roman on 10/28/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CSIOpusDecoder : NSObject
+ (CSIOpusDecoder *)getDecoder;

+ (CSIOpusDecoder*)decoderWithSampleRate:(double)sampleRate channels:(int)channels frameDuration:(double)frameDuration;

- (id)initWithSampleRate:(double)sampleRate channels:(int)channels frameDuration:(double)frameDuration;

- (void)decode:(NSData *)packet;

- (int)tryFillBuffer:(AudioBufferList *)audioBufferList;

@end
