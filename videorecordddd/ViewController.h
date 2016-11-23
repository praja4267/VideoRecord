//
//  ViewController.h
//  videorecordddd
//
//  Created by ActiveMac04 on 7/25/16.
//  Copyright © 2016 Tech_Active. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h> 

typedef NS_ENUM(NSUInteger, OutputMode) {
    OutputModeVideoData,
    OutputModeMovieFile,
};
@protocol ViewControllerDelegate <NSObject>
- (void)didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                                      error:(NSError *)error;
@end


@interface ViewController : UIViewController<AVCaptureFileOutputRecordingDelegate>
{

    BOOL WeAreRecording;
    
    AVCaptureSession *CaptureSession;
    AVCaptureMovieFileOutput *MovieFileOutput;
    AVCaptureDeviceInput *VideoInputDevice;


}

//@property (nonatomic, retain) AVCaptureVideoPreviewLayer *PreviewLayer;
@property(nonatomic, retain) IBOutlet UIView *videoview;
- (IBAction)sartrecording:(id)sender;
@property(nonatomic, retain) AVCaptureMovieFileOutput *videooutput;
@property (nonatomic, readonly) BOOL isRecording;
@property(nonatomic,strong) NSURL *fileurl;
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
@property (nonatomic, strong) AVCaptureConnection *audioConnection;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
@property (nonatomic, assign) id<ViewControllerDelegate> delegate;

@property (nonatomic, copy) void (^onBuffer)(CMSampleBufferRef sampleBuffer);
@end

