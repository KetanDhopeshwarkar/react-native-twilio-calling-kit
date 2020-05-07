//
//  Utils.m
//  ObjCVideoQuickstart
//
//  Copyright © 2016-2017 Twilio, Inc. All rights reserved.
//

#import "Utils.h"

@implementation PlatformUtils

+ (BOOL)isSimulator {
#if TARGET_IPHONE_SIMULATOR
    return YES;
#endif
    return NO;
}

@end

@implementation TokenUtils

+ (void)retrieveAccessTokenFromURL:(NSString *)tokenURLStr
                        completion:(void (^)(NSString* token, NSError *err)) completionHandler {
    NSURL *tokenURL = [NSURL URLWithString:tokenURLStr];
    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig];
    NSURLSessionDataTask *task = [session dataTaskWithURL:tokenURL
                                        completionHandler: ^(NSData * _Nullable data,
                                                             NSURLResponse * _Nullable response,
                                                             NSError * _Nullable error) {
                                            NSString *accessToken = nil;
                                            if (!error && data) {
                                                accessToken = [[NSString alloc] initWithData:data
                                                                                    encoding:NSUTF8StringEncoding];
                                            }
                                            completionHandler(accessToken, error);
                                        }];
    [task resume];
}

+ (UIColor *)getUIColorObjectFromHexString:(NSString *)hexStr alpha:(CGFloat)alpha
{
  // Convert hex string to an integer
  unsigned int hexint = [self intFromHexString:hexStr];

  // Create a color object, specifying alpha as well
  UIColor *color =
    [UIColor colorWithRed:((CGFloat) ((hexint & 0xFF0000) >> 16))/255
    green:((CGFloat) ((hexint & 0xFF00) >> 8))/255
    blue:((CGFloat) (hexint & 0xFF))/255
    alpha:alpha];

  return color;
}

+ (unsigned int)intFromHexString:(NSString *)hexStr
{
  unsigned int hexInt = 0;

  // Create scanner
  NSScanner *scanner = [NSScanner scannerWithString:hexStr];

  // Tell scanner to skip the # character
  [scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"#"]];

  // Scan hex value
  [scanner scanHexInt:&hexInt];

  return hexInt;
}

@end
