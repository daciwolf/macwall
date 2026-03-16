#import "MacWallScreenSaverView.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@interface MacWallScreenSaverView ()

@property(nonatomic, copy) NSString *currentImagePath;
@property(nonatomic, copy) NSString *currentVideoPath;
@property(nonatomic, assign) NSUInteger reloadFrameCounter;
@property(nonatomic, assign) NSTimeInterval lastObservedPlaybackTime;
@property(nonatomic, assign) NSUInteger stalledPlaybackCheckCount;
@property(nonatomic, strong) CALayer *imageLayer;
@property(nonatomic, strong) AVQueuePlayer *player;
@property(nonatomic, strong) AVPlayerLooper *looper;
@property(nonatomic, strong) AVPlayerLayer *playerLayer;
@property(nonatomic, strong) CATextLayer *messageLayer;

@end

@implementation MacWallScreenSaverView

static const NSUInteger MacWallPlaybackHealthCheckInterval = 30;
static const NSUInteger MacWallMaximumStalledPlaybackChecks = 3;

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        [self setAnimationTimeInterval:1.0 / 30.0];
        [self setWantsLayer:YES];
        self.layer.backgroundColor = NSColor.blackColor.CGColor;

        self.imageLayer = [CALayer layer];
        self.imageLayer.contentsGravity = kCAGravityResizeAspectFill;
        self.imageLayer.hidden = YES;
        [self.layer addSublayer:self.imageLayer];

        self.messageLayer = [CATextLayer layer];
        self.messageLayer.alignmentMode = kCAAlignmentCenter;
        self.messageLayer.foregroundColor = NSColor.whiteColor.CGColor;
        self.messageLayer.wrapped = YES;
        self.messageLayer.fontSize = isPreview ? 18.0 : 28.0;
        CGFloat backingScaleFactor = NSScreen.mainScreen != nil ? NSScreen.mainScreen.backingScaleFactor : 2.0;
        self.messageLayer.contentsScale = backingScaleFactor;
        [self.layer addSublayer:self.messageLayer];

        [self updateLayerFrames];
        [self registerForWorkspaceNotifications];
        [self reloadSharedStatePreservingCurrentVideo:NO forcePlayerReset:NO];
    }
    return self;
}

- (void)dealloc
{
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)startAnimation
{
    [super startAnimation];
    self.reloadFrameCounter = 0;
    [self resetPlaybackHealthTracking];
    [self reloadSharedStatePreservingCurrentVideo:YES forcePlayerReset:YES];
    [self.player playImmediatelyAtRate:1.0];
}

- (void)stopAnimation
{
    [self.player pause];
    [super stopAnimation];
}

- (void)animateOneFrame
{
    self.reloadFrameCounter += 1;

    if (self.reloadFrameCounter % MacWallPlaybackHealthCheckInterval == 0) {
        [self validatePlaybackHealth];
    }
}

- (void)setFrameSize:(NSSize)newSize
{
    [super setFrameSize:newSize];
    [self updateLayerFrames];
}

- (void)layout
{
    [super layout];
    [self updateLayerFrames];
}

- (BOOL)hasConfigureSheet
{
    return NO;
}

- (NSWindow *)configureSheet
{
    return nil;
}

- (void)reloadSharedStatePreservingCurrentVideo:(BOOL)preserveCurrentVideo forcePlayerReset:(BOOL)forcePlayerReset
{
    NSDictionary *sharedState = [self loadSharedState];
    NSDictionary *lockScreen = [sharedState[@"lockScreen"] isKindOfClass:NSDictionary.class] ? sharedState[@"lockScreen"] : nil;
    NSString *videoPath = [self decodedFilePathFromValue:lockScreen[@"videoPath"]];
    NSString *previewImagePath = [self decodedFilePathFromValue:lockScreen[@"previewImagePath"]];
    NSString *wallpaperTitle = [lockScreen[@"wallpaperTitle"] isKindOfClass:NSString.class] ? lockScreen[@"wallpaperTitle"] : nil;
    NSString *preservedVideoPath = [self.currentVideoPath copy];

    if (videoPath.length == 0) {
        videoPath = [self decodedFilePathFromValue:sharedState[@"videoPath"]];
    }

    if (previewImagePath.length == 0) {
        previewImagePath = [self decodedFilePathFromValue:sharedState[@"previewImagePath"]];
    }

    if (wallpaperTitle.length == 0) {
        wallpaperTitle = [sharedState[@"wallpaperTitle"] isKindOfClass:NSString.class] ? sharedState[@"wallpaperTitle"] : @"MacWall";
    }

    if (videoPath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        [self configurePlayerWithVideoPath:videoPath forceReset:forcePlayerReset];
        [self clearPreviewImage];
        self.messageLayer.hidden = YES;
        self.playerLayer.hidden = NO;
        [self resetPlaybackHealthTracking];

        if (self.isAnimating) {
            [self.player playImmediatelyAtRate:1.0];
        }
        return;
    }

    if (preserveCurrentVideo &&
        preservedVideoPath.length > 0 &&
        [[NSFileManager defaultManager] fileExistsAtPath:preservedVideoPath]) {
        [self configurePlayerWithVideoPath:preservedVideoPath forceReset:forcePlayerReset || self.player == nil];
        [self clearPreviewImage];
        self.messageLayer.hidden = YES;
        self.playerLayer.hidden = NO;
        [self resetPlaybackHealthTracking];

        if (self.isAnimating) {
            [self.player playImmediatelyAtRate:1.0];
        }
        return;
    }

    [self clearPlayer];
    if (previewImagePath.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:previewImagePath]) {
        [self configurePreviewImageWithPath:previewImagePath];
        self.messageLayer.hidden = YES;
        return;
    }

    [self clearPreviewImage];
    [self clearPlayer];
    self.messageLayer.hidden = NO;
    self.messageLayer.string = [NSString stringWithFormat:@"%@\n\nImport a local video in MacWall, then select MacWallScreenSaver in System Settings > Wallpaper > Screen Saver.", wallpaperTitle];
}

- (NSString *)decodedFilePathFromValue:(id)value
{
    if (![value isKindOfClass:NSString.class]) {
        return nil;
    }

    NSString *stringValue = (NSString *)value;
    NSString *decodedValue = stringValue.stringByRemovingPercentEncoding;
    return decodedValue.length > 0 ? decodedValue : stringValue;
}

- (NSDictionary *)loadSharedState
{
    NSURL *applicationSupportURL = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                                           inDomains:NSUserDomainMask].firstObject;
    if (applicationSupportURL == nil) {
        return @{};
    }

    NSURL *sharedStateDirectoryURL = [applicationSupportURL URLByAppendingPathComponent:@"MacWall" isDirectory:YES];
    NSURL *sharedStateURL = [sharedStateDirectoryURL URLByAppendingPathComponent:@"shared-state.json" isDirectory:NO];
    NSData *data = [NSData dataWithContentsOfURL:sharedStateURL];
    if (data.length == 0) {
        return @{};
    }

    id jsonObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([jsonObject isKindOfClass:NSDictionary.class]) {
        return jsonObject;
    }

    return @{};
}

- (void)configurePlayerWithVideoPath:(NSString *)videoPath forceReset:(BOOL)forceReset
{
    if (!forceReset &&
        [self.currentVideoPath isEqualToString:videoPath] &&
        self.player != nil &&
        self.playerLayer.superlayer != nil) {
        return;
    }

    [self clearPlayer];

    NSURL *videoURL = [NSURL fileURLWithPath:videoPath];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:videoURL];
    AVQueuePlayer *player = [AVQueuePlayer queuePlayerWithItems:@[]];
    player.muted = YES;
    player.preventsDisplaySleepDuringVideoPlayback = NO;
    player.automaticallyWaitsToMinimizeStalling = NO;
    player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    self.looper = [AVPlayerLooper playerLooperWithPlayer:player templateItem:playerItem];
    self.player = player;
    self.currentVideoPath = [videoPath copy];

    AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:player];
    playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    playerLayer.hidden = NO;
    self.playerLayer = playerLayer;
    [self.layer insertSublayer:playerLayer below:self.messageLayer];
    [self updateLayerFrames];
}

- (void)clearPlayer
{
    [self.player pause];
    self.player = nil;
    self.looper = nil;
    self.currentVideoPath = nil;
    [self.playerLayer removeFromSuperlayer];
    self.playerLayer = nil;
    [self resetPlaybackHealthTracking];
}

- (void)configurePreviewImageWithPath:(NSString *)imagePath
{
    if ([self.currentImagePath isEqualToString:imagePath] && self.imageLayer.contents != nil) {
        self.imageLayer.hidden = NO;
        return;
    }

    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    if (cgImage == nil) {
        [self clearPreviewImage];
        return;
    }

    self.currentImagePath = [imagePath copy];
    self.imageLayer.contents = (__bridge id)cgImage;
    self.imageLayer.hidden = NO;
}

- (void)clearPreviewImage
{
    self.currentImagePath = nil;
    self.imageLayer.contents = nil;
    self.imageLayer.hidden = YES;
}

- (void)updateLayerFrames
{
    self.imageLayer.frame = self.bounds;
    self.playerLayer.frame = self.bounds;
    self.messageLayer.frame = NSInsetRect(self.bounds, 48.0, 48.0);
}

- (void)registerForWorkspaceNotifications
{
    NSNotificationCenter *workspaceNotificationCenter = [NSWorkspace sharedWorkspace].notificationCenter;
    [workspaceNotificationCenter addObserver:self
                                    selector:@selector(handleWorkspaceWakeNotification:)
                                        name:NSWorkspaceDidWakeNotification
                                      object:nil];
    [workspaceNotificationCenter addObserver:self
                                    selector:@selector(handleWorkspaceWakeNotification:)
                                        name:NSWorkspaceScreensDidWakeNotification
                                      object:nil];
    [workspaceNotificationCenter addObserver:self
                                    selector:@selector(handleWorkspaceWakeNotification:)
                                        name:NSWorkspaceSessionDidBecomeActiveNotification
                                      object:nil];
}

- (void)handleWorkspaceWakeNotification:(NSNotification *)notification
{
    (void)notification;
    [self reloadSharedStatePreservingCurrentVideo:YES forcePlayerReset:YES];
}

- (void)validatePlaybackHealth
{
    if (self.currentVideoPath.length == 0) {
        [self reloadSharedStatePreservingCurrentVideo:NO forcePlayerReset:NO];
        return;
    }

    if (self.player == nil || self.playerLayer.superlayer == nil || self.player.currentItem == nil) {
        [self reloadSharedStatePreservingCurrentVideo:YES forcePlayerReset:YES];
        return;
    }

    AVPlayerItem *currentItem = self.player.currentItem;
    if (currentItem.status == AVPlayerItemStatusFailed || currentItem.error != nil) {
        [self reloadSharedStatePreservingCurrentVideo:YES forcePlayerReset:YES];
        return;
    }

    if (currentItem.status != AVPlayerItemStatusReadyToPlay) {
        if (self.isAnimating) {
            [self.player playImmediatelyAtRate:1.0];
        }
        return;
    }

    BOOL playbackLooksHealthy = self.player.rate > 0.0f;
    if (@available(macOS 10.12, *)) {
        playbackLooksHealthy = playbackLooksHealthy && self.player.timeControlStatus == AVPlayerTimeControlStatusPlaying;
    }

    NSTimeInterval playbackTime = [self currentPlaybackTime];
    if (isfinite(playbackTime) && isfinite(self.lastObservedPlaybackTime)) {
        playbackLooksHealthy = playbackLooksHealthy && fabs(playbackTime - self.lastObservedPlaybackTime) > 0.05;
    }

    if (playbackLooksHealthy) {
        self.lastObservedPlaybackTime = playbackTime;
        self.stalledPlaybackCheckCount = 0;
        return;
    }

    if (self.isAnimating) {
        [self.player playImmediatelyAtRate:1.0];
    }

    self.stalledPlaybackCheckCount += 1;
    if (self.stalledPlaybackCheckCount >= MacWallMaximumStalledPlaybackChecks) {
        [self reloadSharedStatePreservingCurrentVideo:YES forcePlayerReset:YES];
    }
}

- (NSTimeInterval)currentPlaybackTime
{
    if (self.player == nil) {
        return NAN;
    }

    CMTime time = self.player.currentTime;
    if (CMTIME_IS_INVALID(time) || CMTIME_IS_INDEFINITE(time)) {
        return NAN;
    }

    Float64 seconds = CMTimeGetSeconds(time);
    return isfinite(seconds) ? seconds : NAN;
}

- (void)resetPlaybackHealthTracking
{
    self.lastObservedPlaybackTime = [self currentPlaybackTime];
    self.stalledPlaybackCheckCount = 0;
}

@end
