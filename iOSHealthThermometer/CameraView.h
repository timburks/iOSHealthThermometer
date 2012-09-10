//
//  CameraView.h
//  Capture
//
//  Created by Tim Burks on 12/16/10.
//  Copyright 2010 Radtastical, Inc. All rights reserved.
//
 
#if !TARGET_IPHONE_SIMULATOR

@interface CameraView : UIView <AVCaptureVideoDataOutputSampleBufferDelegate> 
{

}

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoDataOutput *output;
@property (nonatomic, assign) BOOL started;

- (void) startUpdating;
- (void) stopUpdating;
- (void) resumeUpdating;

@end

#endif
