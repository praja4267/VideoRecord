//
//  ViewController.m
//  videorecordddd
//
//  Created by ActiveMac04 on 7/25/16.
//  Copyright © 2016 Tech_Active. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<ViewControllerDelegate>{

    AVCaptureVideoOrientation videoOrientation;
    AVCaptureVideoOrientation referenceOrientation;
    BOOL recordingWillBeStarted;
    OutputMode currentOutputMode;
    dispatch_queue_t movieWritingQueue;
    CMBufferQueueRef previewBufferQueue;
    BOOL readyToRecordAudio;
    BOOL readyToRecordVideo;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    CALayer *viewLayer = self.videoview.layer;
    NSLog(@"viewLayer = %@", viewLayer);
    
    AVCaptureVideoPreviewLayer *captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    
    captureVideoPreviewLayer.frame = self.videoview.bounds;
    [self.videoview.layer addSublayer:captureVideoPreviewLayer];
    
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        // Handle the error appropriately.
        NSLog(@"ERROR: trying to open camera: %@", error);
    }
    [session addInput:input];
    
    [session startRunning];
    _videooutput = [[AVCaptureMovieFileOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
    //[_videooutput setOutputSettings:outputSettings];
    
    [session addOutput:_videooutput];



}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sartrecording:(id)sender {
    
    
    [self startRecording];
    
}

- (void)startRecording {
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString* dateTimePrefix = [formatter stringFromDate:[NSDate date]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    
    if (currentOutputMode == OutputModeMovieFile) {
        
        int fileNamePostfix = 0;
        NSString *filePath = nil;
        
        do
            filePath =[NSString stringWithFormat:@"/%@/%@-%i.mp4", documentsDirectory, dateTimePrefix, fileNamePostfix++];
        while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
        
        self.fileurl = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
        
        [self.videooutput startRecordingToOutputFileURL:self.fileurl recordingDelegate:self];
    }
    else if (currentOutputMode == OutputModeVideoData) {
        
        dispatch_async(movieWritingQueue, ^{
            
            UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
            // Don't update the reference orientation when the device orientation is face up/down or unknown.
            if (UIDeviceOrientationIsPortrait(orientation) || UIDeviceOrientationIsLandscape(orientation)) {
                referenceOrientation = (AVCaptureVideoOrientation)orientation;
            }
            
            int fileNamePostfix = 0;
            NSString *filePath = nil;
            
            do
                filePath =[NSString stringWithFormat:@"/%@/%@-%i.MOV", documentsDirectory, dateTimePrefix, fileNamePostfix++];
            while ([[NSFileManager defaultManager] fileExistsAtPath:filePath]);
            
            self.fileurl = [NSURL URLWithString:[@"file://" stringByAppendingString:filePath]];
            
            NSError *error;
            self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileurl
                                                         fileType:AVFileTypeQuickTimeMovie
                                                            error:&error];
            NSLog(@"AVAssetWriter error:%@", error);
            
            recordingWillBeStarted = YES;
            
            //        [self.assetWriter startWriting];
            //        [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
        });
    }
}

- (void)stopRecording {
    
    if (currentOutputMode == OutputModeMovieFile) {
        
        [self.videooutput stopRecording];
    }
    else if (currentOutputMode == OutputModeVideoData) {
        
        dispatch_async(movieWritingQueue, ^{
            
            _isRecording = NO;
            readyToRecordVideo = NO;
            readyToRecordAudio = NO;
            
            [self.assetWriter finishWritingWithCompletionHandler:^{
                
                self.assetWriterVideoInput = nil;
                self.assetWriterAudioInput = nil;
                self.assetWriter = nil;
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if ([self.delegate respondsToSelector:@selector(didFinishRecordingToOutputFileAtURL:error:)]) {
                        [self.delegate didFinishRecordingToOutputFileAtURL:self.fileurl error:nil];
                    }
                });
            }];
        });
    }
}
- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
    didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                       fromConnections:(NSArray *)connections
{
    _isRecording = YES;
}

- (void)                 captureOutput:(AVCaptureFileOutput *)captureOutput
   didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                       fromConnections:(NSArray *)connections error:(NSError *)error
{
    //    [self saveRecordedFile:outputFileURL];
    _isRecording = NO;
    
    if ([self.delegate respondsToSelector:@selector(didFinishRecordingToOutputFileAtURL:error:)]) {
        [self.delegate didFinishRecordingToOutputFileAtURL:outputFileURL error:error];
    }
}


// =============================================================================
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)    captureOutput:(AVCaptureOutput *)captureOutput
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
           fromConnection:(AVCaptureConnection *)connection
{
    if (self.onBuffer) {
        self.onBuffer(sampleBuffer);
    }
    
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    
    CFRetain(sampleBuffer);
    
    dispatch_async(movieWritingQueue, ^{
        
        if (self.assetWriter && (self.isRecording || recordingWillBeStarted)) {
            
            BOOL wasReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
            
            if (connection == self.videoConnection) {
                
                // Initialize the video input if this is not done yet
                if (!readyToRecordVideo) {
                    
                    readyToRecordVideo = [self setupAssetWriterVideoInput:formatDescription];
                }
                
                // Write video data to file
                if (readyToRecordVideo && readyToRecordAudio) {
                    [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
                }
            }
            else if (connection == self.audioConnection) {
                
                // Initialize the audio input if this is not done yet
                if (!readyToRecordAudio) {
                    readyToRecordAudio = [self setupAssetWriterAudioInput:formatDescription];
                }
                
                // Write audio data to file
                if (readyToRecordAudio && readyToRecordVideo)
                    [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
            }
            
            BOOL isReadyToRecord = (readyToRecordAudio && readyToRecordVideo);
            if (!wasReadyToRecord && isReadyToRecord) {
                
                recordingWillBeStarted = NO;
                _isRecording = YES;
            }
        }
        CFRelease(sampleBuffer);
    });
}
- (BOOL)setupAssetWriterVideoInput:(CMFormatDescriptionRef)currentFormatDescription
{
    float bitsPerPixel;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription);
    int numPixels = dimensions.width * dimensions.height;
    int bitsPerSecond;
    
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
    if ( numPixels < (640 * 480) )
        bitsPerPixel = 4.05; // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    else
        bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    
    bitsPerSecond = numPixels * bitsPerPixel;
    
    NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              AVVideoCodecH264, AVVideoCodecKey,
                                              [NSNumber numberWithInteger:dimensions.width], AVVideoWidthKey,
                                              [NSNumber numberWithInteger:dimensions.height], AVVideoHeightKey,
                                              [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                               [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
                                               nil], AVVideoCompressionPropertiesKey,
                                              nil];
    
    NSLog(@"videoCompressionSetting:%@", videoCompressionSettings);
    
    if ([self.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
        
        self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo
                                                                    outputSettings:videoCompressionSettings];
        
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        self.assetWriterVideoInput.transform = [self transformFromCurrentVideoOrientationToOrientation:referenceOrientation];
        
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]) {
            
            [self.assetWriter addInput:self.assetWriterVideoInput];
        }
        else {
            
            NSLog(@"Couldn't add asset writer video input.");
            return NO;
        }
    }
    else {
        
        NSLog(@"Couldn't apply video output settings.");
        return NO;
    }
    
    return YES;
}

- (BOOL)setupAssetWriterAudioInput:(CMFormatDescriptionRef)currentFormatDescription
{
    const AudioStreamBasicDescription *currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription);
    
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize);
    NSData *currentChannelLayoutData = nil;
    
    // AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
    if ( currentChannelLayout && aclSize > 0 ) {
        
        currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
    }
    else {
        
        currentChannelLayoutData = [NSData data];
    }
    
    NSDictionary *audioCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInteger:kAudioFormatMPEG4AAC], AVFormatIDKey,
                                              [NSNumber numberWithFloat:currentASBD->mSampleRate], AVSampleRateKey,
                                              [NSNumber numberWithInt:64000], AVEncoderBitRatePerChannelKey,
                                              [NSNumber numberWithInteger:currentASBD->mChannelsPerFrame], AVNumberOfChannelsKey,
                                              currentChannelLayoutData, AVChannelLayoutKey,
                                              nil];
    if ([self.assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]) {
        
        self.assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio
                                                                    outputSettings:audioCompressionSettings];
        
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
        
        if ([self.assetWriter canAddInput:self.assetWriterAudioInput]) {
            
            [self.assetWriter addInput:self.assetWriterAudioInput];
        }
        else {
            
            NSLog(@"Couldn't add asset writer audio input.");
            return NO;
        }
    }
    else {
        
        NSLog(@"Couldn't apply audio output settings.");
        return NO;
    }
    
    return YES;
}

- (void)writeSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(NSString *)mediaType
{
    if (self.assetWriter.status == AVAssetWriterStatusUnknown) {
        
        if ([self.assetWriter startWriting]) {
            
            CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [self.assetWriter startSessionAtSourceTime:timestamp];
        }
        else {
            
            NSLog(@"AVAssetWriter startWriting error:%@", self.assetWriter.error);
        }
    }
    
    if (self.assetWriter.status == AVAssetWriterStatusWriting) {
        
        if (mediaType == AVMediaTypeVideo) {
            
            if (self.assetWriterVideoInput.readyForMoreMediaData) {
                
                if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                    
                    NSLog(@"isRecording:%d, willBeStarted:%d", self.isRecording, recordingWillBeStarted);
                    NSLog(@"AVAssetWriterInput video appendSapleBuffer error:%@", self.assetWriter.error);
                }
            }
        }
        else if (mediaType == AVMediaTypeAudio) {
            
            if (self.assetWriterAudioInput.readyForMoreMediaData) {
                
                if (![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                    
                    NSLog(@"AVAssetWriterInput audio appendSapleBuffer error:%@", self.assetWriter.error);
                }
            }
        }
    }
}
- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
    CGAffineTransform transform = CGAffineTransformIdentity;
    
//    // Calculate offsets from an arbitrary reference orientation (portrait)
//    CGFloat orientationAngleOffset = [ViewController angleOffsetFromPortraitOrientationToOrientation:orientation];
//    CGFloat videoOrientationAngleOffset = [TTMCaptureManager angleOffsetFromPortraitOrientationToOrientation:videoOrientation];
//    
//    // Find the difference in angle between the passed in orientation and the current video orientation
//    CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
//    transform = CGAffineTransformMakeRotation(angleOffset);
//    
    return transform;
}
- (void)saveRecordedFile:(NSURL *)recordedFile {
    
    
     dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeVideoAtPathToSavedPhotosAlbum:recordedFile
                                         completionBlock:
         ^(NSURL *assetURL, NSError *error) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 
                
                 
                 NSString *title;
                 NSString *message;
                 
                 if (error != nil) {
                     
                     title = @"Failed to save video";
                     message = [error localizedDescription];
                 }
                 else {
                     title = @"Saved!";
                     message = nil;
                 }
                 
                 UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                                 message:message
                                                                delegate:nil
                                                       cancelButtonTitle:@"OK"
                                                       otherButtonTitles:nil];
                 [alert show];
             });
         }];
    });
}




@end
