//
//  AppDelegate.m
//  iOSHealthThermometer
//
//  Created by Tim Burks on 7/2/12.
//  Copyright (c) 2012 Radtastical Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "ThermometerViewController.h"

@interface AppDelegate ()
@property (nonatomic, strong) ThermometerViewController *thermometerViewController;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"Launching");
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [self.window makeKeyAndVisible];
    
    self.window.rootViewController = self.thermometerViewController = [[ThermometerViewController alloc] init];
    return YES;
}

- (void) applicationWillResignActive:(UIApplication *)application
{
    [self.thermometerViewController disconnect];
}

- (void) applicationDidBecomeActive:(UIApplication *)application
{
    [self.thermometerViewController startScan];
}

// http://stackoverflow.com/questions/4656214/iphone-backgrounding-to-poll-for-events
UIBackgroundTaskIdentifier bgTask;
- (void)applicationDidEnterBackground:(UIApplication *)application
{
    UIApplication *app = [UIApplication sharedApplication];
    
    dispatch_block_t expirationHandler;
    expirationHandler = [^{
        [app endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
        NSLog(@"app requesting to continue in background (2)");
        bgTask = [app beginBackgroundTaskWithExpirationHandler:expirationHandler];
    } copy];
    
    NSLog(@"app requesting to continue in background (1)");
    bgTask = [app beginBackgroundTaskWithExpirationHandler:expirationHandler];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // inform others to stop tasks, if you like
        [[NSNotificationCenter defaultCenter] postNotificationName:@"ApplicationEntersBackground" object:self];
        
        // do your background work here
    });
}

@end
