#import <TwilioVideo/TwilioVideo.h>
#import "RNTwilioViewController.h"
#import "Utils.h"
#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

@interface TwilioCallingKit : RCTEventEmitter <RCTBridgeModule>
+ (void)sendEventToJS:(NSString *)event;
@end
