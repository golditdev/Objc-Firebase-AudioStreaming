//
//  ViewController.h
//  AudioStream
//
//  Created by Roman on 10/28/16.
//  Copyright © 2016 Crane. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AudioProcessor;
@class AudioPlay;

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (retain, nonatomic) AudioProcessor *encodeAudioProcessor;
@property (retain, nonatomic) AudioPlay *decodeAudioProcessor;


@end

