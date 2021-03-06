//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@protocol FDWaveformViewDelegate;

@interface FDWaveformView : UIView {
  CGFloat progress;
}
@property (nonatomic, weak) id<FDWaveformViewDelegate> delegate;
@property (nonatomic, strong) NSURL *audioURL;
@property (nonatomic, strong) UIView *detailSlider;
@property (nonatomic, assign, readonly) unsigned long int totalSamples;
@property (nonatomic, assign) unsigned long int progressSamples;
@property (nonatomic, assign) unsigned long int zoomStartSamples;
@property (nonatomic, assign) unsigned long int zoomEndSamples;
@property (nonatomic, strong) UIImageView *image;
@property (nonatomic) BOOL doesAllowScrubbing;
@property (nonatomic) BOOL doesAllowStretchAndScroll;
@property (nonatomic, copy) UIColor *wavesColor;
@property (nonatomic, copy) UIColor *progressColor;
- (void)setAudioURL:(NSURL *)audioURL withUniqueID:(unsigned long)ID;
@end

@protocol FDWaveformViewDelegate <NSObject>
@optional
- (void)waveformViewWillRender:(FDWaveformView *)waveformView;
- (void)waveformViewDidRender:(FDWaveformView *)waveformView;
@end
