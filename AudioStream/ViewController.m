//
//  ViewController.m
//  AudioStream
//
//  Created by Roman on 10/28/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import "ViewController.h"
#import "AudioProcessor.h"
#import "AudioPlay.h"

@interface ViewController ()

@end

@implementation ViewController
- (void)viewDidLoad {
    [super viewDidLoad];
 
    _recordBtn.layer.cornerRadius = 3.0f;
    _playBtn.layer.cornerRadius = 3.0f;
    [_recordBtn addTarget:self action:@selector(recordAction:) forControlEvents:UIControlEventTouchUpInside];
    [_playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    if (_encodeAudioProcessor == nil) {
        _encodeAudioProcessor = [[AudioProcessor alloc] init];
    }
    if (_decodeAudioProcessor == nil) {
        _decodeAudioProcessor = [[AudioPlay alloc] init];
    }
}

- (void)recordAction:(UIButton*)btn
{
    if (!btn.isSelected) {
        [btn setTitle:@"Recording..." forState:UIControlStateNormal];
        [_playBtn setHidden:YES];
        
        _imageView.image = [UIImage imageNamed:@"recordAudio"];
        [btn setSelected:YES];
        if (_encodeAudioProcessor == nil) {
            _encodeAudioProcessor = [[AudioProcessor alloc] init];
        }
        _encodeAudioProcessor.isRecording = YES;
        [_encodeAudioProcessor start];
    } else {
        [btn setTitle:@"Record" forState:UIControlStateNormal];
        [_playBtn setHidden:NO];
        
        _imageView.image = [UIImage imageNamed:@"stopRecord"];
        [btn setSelected:NO];
         [_encodeAudioProcessor stop];
    }
}

- (void)playAction:(UIButton*)btn
{
    if (!btn.isSelected) {
        [btn setTitle:@"Playing..." forState:UIControlStateNormal];
        [_recordBtn setHidden:YES];
        
        _imageView.image = [UIImage imageNamed:@"playAudio"];
        [btn setSelected:YES];
        if (_decodeAudioProcessor == nil) {
            _decodeAudioProcessor = [[AudioPlay alloc] init];
        }
        _decodeAudioProcessor.isRecording = NO;
        [_decodeAudioProcessor start];
    } else {
        [btn setTitle:@"play" forState:UIControlStateNormal];
        [_recordBtn setHidden:NO];
        
        _imageView.image = [UIImage imageNamed:@"stopAudio"];
        [btn setSelected:NO];
         [_decodeAudioProcessor stop];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


@end
