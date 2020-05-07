#import "TwilioCallingKit.h"

@implementation TwilioCallingKit

RCT_EXPORT_MODULE()

- (void) dealloc
{
    // If you don't remove yourself as an observer, the Notification Center
    // will continue to try and send notification objects to the deallocated
    // object.
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[@"TWILIO_ON_STATE_CHANGE"];
}

RCT_EXPORT_METHOD(connect:(nonnull NSDictionary *)props)
{
    
    // view did load
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleUpdatedData:)
                                                 name:@"DataUpdated"
                                               object:nil];

    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSString * storyboardName = @"RNTwilioViewController";
        
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:[NSBundle bundleForClass:[RNTwilioViewController class]]];
        RNTwilioViewController *videoController = [storyboard instantiateViewControllerWithIdentifier:@"RNTwilioViewController"];
        
        videoController.props = props;
//        videoController.twilioKit = self;
        
        TVIDefaultAudioDevice *audioDevice = [TVIDefaultAudioDevice audioDevice];
        TwilioVideoSDK.audioDevice = audioDevice;
        videoController.audioDevice = audioDevice;
        
        // The default modal presenting is page sheet in ios 13, not full screen
        if (@available(iOS 13, *)) {
            [videoController setModalPresentationStyle: UIModalPresentationFullScreen];
        }
        
        id<UIApplicationDelegate> app = [[UIApplication sharedApplication] delegate];
        UINavigationController *rootViewController = ((UINavigationController*) app.window.rootViewController);
        
        if (rootViewController.presentedViewController) {
            [rootViewController.presentedViewController presentViewController:videoController animated:YES completion:nil];
            return;
        }
        
        [rootViewController presentViewController:videoController animated:NO completion:nil];
    });
}

+ (void)sendEventToJS:(NSString *)event {
    [self sendEventToJS:event];
}
- (void)sendEvent:(NSString *)event {
   [self sendEventWithName:@"TWILIO_ON_STATE_CHANGE" body:@{@"status": event}];
}

-(void)handleUpdatedData:(NSNotification *)notification {
    NSLog(@"recieved");
    
    NSDictionary *userInfo = notification.userInfo;
    NSString *eventName = [userInfo objectForKey:@"event"];
    
    [self sendEventWithName:@"TWILIO_ON_STATE_CHANGE" body:@{@"status": eventName}];
}


@end
