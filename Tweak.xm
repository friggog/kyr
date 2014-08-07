#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "FDWaveformView.h"

NSURL * url;
FDWaveformView * waveFormView;

#define imgExt @"png"
#define imageToData(x) UIImagePNGRepresentation(x)

@interface MusicNowPlayingViewController : UIViewController
-(void) displayWaveFormImage;
@end

@interface AVAsset (chew)
-(id)_absoluteURL;
@end

@interface MPAVItem : NSObject
@property (nonatomic,readonly) MPMediaItem * mediaItem;
@property (nonatomic,readonly) AVAsset * asset;
@property (nonatomic,readonly) unsigned long long persistentID;
@end

@interface MPDetailSlider : UISlider
@property (assign,nonatomic) double duration;
@end

@interface MusicTheme : NSObject
-(id)tintColor;
@end

%hook MusicNowPlayingViewController

-(id)_createContentViewForItem:(id)arg1 contentViewController:(id*)arg2 {
	MPAVItem * mitem = (MPAVItem*)arg1;
	AVAsset * asset = mitem.asset;
	if([asset._absoluteURL isFileURL]) {
		[waveFormView setAudioURL:asset._absoluteURL withUniqueID:mitem.persistentID];
		waveFormView.hidden = NO;
	}
	else {
		waveFormView.hidden = YES;
	}
	return %orig;
}

%end

@interface MusicNowPlayingPlaybackControlsView : UIView
@end

%hook MusicNowPlayingPlaybackControlsView

-(void)layoutSubviews {
	%orig;

	UIView* slider = MSHookIvar<UIView*>(self,"_progressControl");

	if(!waveFormView) {
		waveFormView = [[FDWaveformView alloc] initWithFrame:CGRectMake(53,389,216,24)];
		waveFormView.progressColor = [%c(MusicTheme) tintColor];
		waveFormView.detailSlider = slider;
	}

	if(![waveFormView isDescendantOfView:self])
		[self insertSubview:waveFormView belowSubview:slider];
}

%end

%hook MPDetailSlider

-(void)layoutSubviews {
	%orig;

	if(waveFormView.image.image){
		MSHookIvar<UIView*>(self,"_thumbView").hidden = YES;
		MSHookIvar<UIView*>(self,"_minTrackView").hidden = YES;
		MSHookIvar<UIView*>(self,"_maxTrackView").hidden = YES;
	}
	else{
		MSHookIvar<UIView*>(self,"_thumbView").hidden = NO;
		MSHookIvar<UIView*>(self,"_minTrackView").hidden = NO;
		MSHookIvar<UIView*>(self,"_maxTrackView").hidden = NO;
	}

	CGFloat thumbPos = MSHookIvar<UIView*>(self,"_thumbView").center.x - 50;
	CGFloat width = 216;

	waveFormView.progressSamples = waveFormView.totalSamples * (thumbPos/width);
}

%end
