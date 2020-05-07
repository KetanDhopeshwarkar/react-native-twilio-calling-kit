//
//  Utils.h
//  ObjCVideoQuickstart
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PlatformUtils : NSObject

+ (BOOL)isSimulator;

@end

@interface TokenUtils : NSObject

+ (void)retrieveAccessTokenFromURL:(NSString *)tokenURLStr
                        completion:(void (^)(NSString* token, NSError *err)) completionHandler;
+ (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(CGFloat)alpha;
+ (unsigned int)intFromHexString:(NSString *)hexStr;

@end
