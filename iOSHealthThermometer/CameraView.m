//
//  CameraView.m
//  Capture
//
//  Created by Tim Burks on 12/16/10.
//  Copyright 2010 Radtastical, Inc. All rights reserved.
//
#import "CameraView.h"
#import "UIImage+Resize.h"

#if !TARGET_IPHONE_SIMULATOR

@implementation CameraView
@synthesize imageView, session, output, started;

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.imageView = [[UIImageView alloc]
                           initWithFrame:self.bounds];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth + UIViewAutoresizingFlexibleHeight;
        [self addSubview:self.imageView];
        self.clipsToBounds = YES;  
        self.started = NO;
    }
    return self;
}

- (void)dealloc {
    [self stopUpdating];
    [output setSampleBufferDelegate:nil queue:NULL];
}

// Create and configure a capture session and start it running
- (void) startUpdating
{
    NSError *error = nil;
    
    // Create the session
    self.session = [[AVCaptureSession alloc] init];
    
    // Configure the session to produce lower resolution video frames, if your 
    // processing algorithm can cope.
    session.sessionPreset = AVCaptureSessionPresetMedium;
    
    //NSLog(@"Devices: %@", [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] description]);
    
    // Find a suitable AVCaptureDevice
    AVCaptureDevice *device = [AVCaptureDevice
                               defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    
    //device = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] lastObject];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device 
                                                                        error:&error];
    if (!input) {
        // Handling the error appropriately.
    }
    [session addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    self.output = [[AVCaptureVideoDataOutput alloc] init];
    [session addOutput:output];
    
    // Configure your output.
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [output setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
    
    // Specify the pixel format
    output.videoSettings = 
    [NSDictionary dictionaryWithObject:
     [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] 
                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // If you wish to cap the frame rate to a known value, such as 15 fps, set 
    // minFrameDuration.
    for (AVCaptureConnection *connection in output.connections) {
        connection.videoMinFrameDuration = CMTimeMake(1, 10.0);
    }
    
    // Start the session running to start the flow of data
    [session startRunning];
    
    self.started = YES;
}

- (void) resumeUpdating {         
    if (!self.started) {
        [self startUpdating];
    } else {
        [session startRunning];
    }
}

- (void) stopUpdating {
    [session stopRunning];
}

// Create a UIImage from sample buffer data
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer 
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0); 
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer); 
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8, 
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst); 
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context); 
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context); 
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    return (image);
}

// Delegate routine that is called when a sample buffer was written
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection
{ 
    // Create a UIImage from the sample buffer data
    UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
    
    // rotate it
    CGSize newSize;
    newSize.width = image.size.height;
    newSize.height = image.size.width;    
    CGAffineTransform transform = [UIImage transformForOrientation:UIImageOrientationRight 
                                                          withSize:newSize];
    image = [image resizedImage:newSize
                      transform:transform 
                 drawTransposed:YES 
           interpolationQuality:kCGInterpolationDefault];    
     
    [imageView performSelectorOnMainThread:@selector(setImage:)
                                withObject:image
                             waitUntilDone:YES];
}

@end

#endif
