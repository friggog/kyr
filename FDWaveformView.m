//
//  FDWaveformView
//
//  Created by William Entriken on 10/6/13.
//  Copyright (c) 2013 William Entriken. All rights reserved.
//


// FROM http://stackoverflow.com/questions/5032775/drawing-waveform-with-avassetreader
// AND http://stackoverflow.com/questions/8298610/waveform-on-ios
// DO SEE http://stackoverflow.com/questions/1191868/uiimageview-scaling-interpolation
// see http://stackoverflow.com/questions/3514066/how-to-tint-a-transparent-png-image-in-iphone

#import "FDWaveFormView.h"
#import <UIKit/UIKit.h>
#import "substrate.h"

#define absX(x) (x<0?0-x:x)
#define minMaxX(x,mn,mx) (x<=mn?mn:(x>=mx?mx:x))
#define noiseFloor (-50.0)
#define decibel(amplitude) (20.0 * log10(absX(amplitude)/32767.0))
#define imgExt @"png"
#define imageToData(x) UIImagePNGRepresentation(x)

// Drawing a larger image than needed to have it available for scrolling
#define horizontalMinimumBleed 0.1
#define horizontalMaximumBleed 0.1
#define horizontalTargetBleed 0.1
// Drawing more pixels than shown to get antialiasing
#define horizontalMinimumOverdraw 0
#define horizontalMaximumOverdraw 2
#define horizontalTargetOverdraw 1
#define verticalMinimumOverdraw 0
#define verticalMaximumOverdraw 2
#define verticalTargetOverdraw 1

NSString* pathToCache = @"/var/mobile/Library/kyr/cache";

@interface  UIImage (burn)
-(UIImage*)imageWithBurnTint:(UIColor *)color;
@end

@interface FDWaveformView()
@property (nonatomic, strong) UIImageView *highlightedImage;
@property (nonatomic, strong) UIView *clipping;
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, assign) unsigned long int totalSamples;
@property (nonatomic, assign) unsigned long int cachedStartSamples;
@property (nonatomic, assign) unsigned long int cachedEndSamples;
@property (nonatomic, assign) unsigned long int currentlyRenderingID;
@property BOOL renderingInProgress;
@property unsigned long int uniqueID;
@end

@implementation FDWaveformView
@synthesize audioURL = _audioURL;
@synthesize image = _image;
@synthesize highlightedImage = _highlightedImage;
@synthesize clipping = _clipping;

- (void)initialize
{
    self.image = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    self.highlightedImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    self.image.contentMode = UIViewContentModeScaleToFill;
    self.highlightedImage.contentMode = UIViewContentModeScaleToFill;
    [self addSubview:self.image];
    self.clipping = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    [self.clipping addSubview:self.highlightedImage];
    self.clipping.clipsToBounds = YES;
    [self addSubview:self.clipping];
    self.clipsToBounds = YES;

    self.wavesColor = [UIColor blackColor];
    self.progressColor = [UIColor blueColor];
}

- (id)initWithCoder:(NSCoder *)aCoder
{
    if (self = [super initWithCoder:aCoder])
        [self initialize];
    return self;
}

- (id)initWithFrame:(CGRect)rect
{
    if (self = [super initWithFrame:rect])
        [self initialize];
    return self;
}

- (void)dealloc
{
    self.delegate = nil;
    self.audioURL = nil;
    self.image = nil;
    self.highlightedImage = nil;
    self.clipping = nil;
    self.asset = nil;
    self.wavesColor = nil;
    self.progressColor = nil;
}

- (void)setAudioURL:(NSURL *)audioURL withUniqueID:(unsigned long)ID
{
  //  NSLog(@"SET: %lu", ID);
    _audioURL = audioURL;
    _uniqueID = ID;
    self.asset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%lu.png",pathToCache,_uniqueID]]) {
      self.image.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%lu.png",pathToCache,_uniqueID]];
      self.highlightedImage.image = [self.image.image imageWithBurnTint:self.progressColor];
    }
    else{
      self.image.image = nil;
      self.highlightedImage.image = nil;
      self.totalSamples = (unsigned long int) self.asset.duration.value;
    }
    NSLog(@"### %li",self.totalSamples);
    _progressSamples = 0; // skip custom setter
    //_zoomStartSamples = 0; // skip custom setter
    //_zoomEndSamples = (unsigned long int) self.asset.duration.value; // skip custom setter
    [self setNeedsDisplay];
}

- (void)setProgressSamples:(unsigned long)progressSamples
{
    _progressSamples = progressSamples;
    if (self.totalSamples) {
        progress = (float)self.progressSamples / self.totalSamples;
        self.clipping.frame = CGRectMake(0,0,self.frame.size.width*progress,self.frame.size.height);
        [self setNeedsLayout];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGRect frame = CGRectMake(0,0,self.frame.size.width,self.frame.size.height);//CGRectMake(self.frame.size.width*scaledStart, 0, self.frame.size.width*scaledWidth, self.frame.size.height);
    self.image.frame = self.highlightedImage.frame = frame;
    self.clipping.frame = CGRectMake(0,0,self.frame.size.width*progress,self.frame.size.height);


  //  NSLog(@"ACTIVE:%lu RENDERING:%lu",_uniqueID, _currentlyRenderingID);
    if (!self.asset || _currentlyRenderingID == _uniqueID)// || self.renderingInProgress)
      return;

    BOOL needToRender = NO;
    if (!self.image.image)
        needToRender = YES;
    if (self.image.image.size.width < self.frame.size.width * [UIScreen mainScreen].scale * horizontalMinimumOverdraw)
        needToRender = YES;
    if (self.image.image.size.width > self.frame.size.width * [UIScreen mainScreen].scale * horizontalMaximumOverdraw)
        needToRender = YES;
    if (self.image.image.size.height < self.frame.size.height * [UIScreen mainScreen].scale * verticalMinimumOverdraw)
        needToRender = YES;
    if (self.image.image.size.height > self.frame.size.height * [UIScreen mainScreen].scale * verticalMaximumOverdraw)
        needToRender = YES;
    if (!needToRender)
        return;
    //NSLog(@"NEEDS RENDER");
    self.renderingInProgress = YES;
    if ([self.delegate respondsToSelector:@selector(waveformViewWillRender:)])
        [self.delegate waveformViewWillRender:self];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self renderPNGAudioPictogramLogForAsset:self.asset
                                    startSamples:0
                                      endSamples:self.totalSamples
                                         assetID:self.uniqueID
                                            done:^(UIImage *image, UIImage *selectedImage, unsigned long int assetID) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                    if(assetID == _uniqueID) {
                                                      self.image.image = image;
                                                      self.highlightedImage.image = selectedImage;
                                                      self.cachedStartSamples = 0; ///renderStartSamples;
                                                      self.cachedEndSamples = self.totalSamples;//renderEndSamples;
                                                      [_detailSlider layoutSubviews];
                                                    }
                                                    if ([self.delegate respondsToSelector:@selector(waveformViewDidRender:)])
                                                        [self.delegate waveformViewDidRender:self];
                                                    [self layoutSubviews]; // warning
                                                    self.renderingInProgress = NO;
                                                });
                                            }];
    });
}

- (void)plotLogGraph:(Float32 *) samples
        maximumValue:(Float32) normalizeMax
        mimimumValue:(Float32) normalizeMin
         sampleCount:(NSInteger) sampleCount
         imageHeight:(float) imageHeight
            uniqueID:(unsigned long int) uniqueID
                done:(void(^)(UIImage *image, UIImage *selectedImage, unsigned long int assetID))done
{
  //NSLog(@"$$ %lu",(long)sampleCount);

    _currentlyRenderingID = uniqueID;
  // TODO: switch to a synchronous function that paints onto a given context? (for issue #2)
    CGSize imageSize = CGSizeMake(sampleCount, imageHeight);
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAlpha(context,1.0);
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, [self.wavesColor CGColor]);

    float halfGraphHeight = (imageHeight / 2);
    float centerLeft = halfGraphHeight;
    float sampleAdjustmentFactor = imageHeight / (normalizeMax - noiseFloor) / 2;

    NSLog(@"!!! %li",(long)sampleCount);
    for (NSInteger intSample=0; intSample<sampleCount; intSample++) {
        Float32 sample = *samples++;
        float pixels = (sample - noiseFloor) * sampleAdjustmentFactor;
        CGContextMoveToPoint(context, intSample, centerLeft-pixels);
        CGContextAddLineToPoint(context, intSample, centerLeft+pixels);
        CGContextStrokePath(context);
    }

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    CGRect drawRect = CGRectMake(0, 0, image.size.width, image.size.height);
    [self.progressColor set];
    UIRectFillUsingBlendMode(drawRect, kCGBlendModeSourceAtop);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    done(image, tintedImage, uniqueID);

    NSString * path = [NSString stringWithFormat:@"%@/%lu.png",pathToCache,uniqueID];
    [UIImagePNGRepresentation(image) writeToFile:path atomically:YES];
  }

- (void)renderPNGAudioPictogramLogForAsset:(AVURLAsset *)songAsset
                              startSamples:(unsigned long int)start
                                endSamples:(unsigned long int)end
                                   assetID:(unsigned long int)assetID
                                      done:(void(^)(UIImage *image, UIImage *selectedImage, unsigned long int assetID))done

{
//  NSLog(@"RENDER FOR %lu", assetID);
    // TODO: break out subsampling code
    CGFloat widthInPixels = 778;//self.frame.size.width * [UIScreen mainScreen].scale * horizontalTargetOverdraw;
    CGFloat heightInPixels = 106;//self.frame.size.height * [UIScreen mainScreen].scale * verticalTargetOverdraw;


    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    AVAssetTrack *songTrack = [songAsset.tracks objectAtIndex:0];
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        //     [NSNumber numberWithInt:44100.0],AVSampleRateKey, /*Not Supported*/
                                        //     [NSNumber numberWithInt: 2],AVNumberOfChannelsKey,    /*Not Supported*/
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        nil];
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    [reader addOutput:output];
    UInt32 channelCount;
    NSArray *formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if (!fmtDesc) return; //!
        channelCount = fmtDesc->mChannelsPerFrame;
    }

    UInt32 bytesPerInputSample = 2 * channelCount;
    Float32 maximum = noiseFloor;
    Float64 tally = 0;
    Float32 tallyCount = 0;
    Float32 outSamples = 0;

    NSInteger downsampleFactor = end / widthInPixels;
    NSLog(@"$$$ %li",(long)downsampleFactor);
    if(downsampleFactor < 250)
      downsampleFactor = 15000;
    //downsampleFactor = downsampleFactor<1 ? 1 : downsampleFactor;
    NSMutableData *fullSongData = [[NSMutableData alloc] initWithCapacity:1556]; // 16-bit samples
    reader.timeRange = CMTimeRangeMake(CMTimeMake(start, self.asset.duration.timescale), CMTimeMake((end-start), self.asset.duration.timescale));
    [reader startReading];

    while (reader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
            void *data = malloc(bufferLength);
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data);

            SInt16 *samples = (SInt16 *) data;
            int sampleCount = (int) bufferLength / bytesPerInputSample;
            for (int i=0; i<sampleCount; i++) {
                Float32 sample = (Float32) *samples++;
                sample = decibel(sample);
                sample = minMaxX(sample,noiseFloor,0);
                tally += sample; // Should be RMS?
                for (int j=1; j<channelCount; j++)
                    samples++;
                tallyCount++;

                if (tallyCount == downsampleFactor) {
                    sample = tally / tallyCount;
                    maximum = maximum > sample ? maximum : sample;
                    [fullSongData appendBytes:&sample length:sizeof(sample)];
                    tally = 0;
                    tallyCount = 0;
                    outSamples++;
                }
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            free(data);
        }
    }

    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
        // Something went wrong. Handle it.
    if (reader.status == AVAssetReaderStatusCompleted){
        [self plotLogGraph:(Float32 *)fullSongData.bytes
              maximumValue:maximum
              mimimumValue:noiseFloor
               sampleCount:outSamples
               imageHeight:heightInPixels
                  uniqueID:assetID
                      done:done];
    }
}
@end




@implementation UIImage (burn)
- (UIImage *)imageWithBurnTint:(UIColor *)color
{
    UIImage *img = self;

    // lets tint the icon - assumes your icons are black
    UIGraphicsBeginImageContextWithOptions(img.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGContextTranslateCTM(context, 0, img.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGRect rect = CGRectMake(0, 0, img.size.width, img.size.height);

    // draw alpha-mask
    CGContextSetBlendMode(context, kCGBlendModeNormal);
    CGContextDrawImage(context, rect, img.CGImage);

    // draw tint color, preserving alpha values of original image
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(context, rect);

    UIImage *coloredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return coloredImage;

}
@end
