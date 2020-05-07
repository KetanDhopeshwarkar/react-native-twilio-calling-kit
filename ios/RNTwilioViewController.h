//
//  ViewController.h
//  TwilioWrapperPOC
//
//  Created by Tushar Korde on 13/04/20.
//  Copyright © 2020 Tushar Korde. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <TwilioVideo/TwilioVideo.h>
#import "TwilioCallingKit.h"

@interface RNTwilioViewController : UIViewController
// set accesstoken
@property (nonatomic, strong) NSString *accessToken;

// set tokenURL
@property (nonatomic, strong) NSString *tokenUrl;

// set roomName
@property (nonatomic, strong) NSString *roomName;

// set roomName
@property (nonatomic, strong) NSDictionary *props;

//
@property (nonatomic, strong) TVIDefaultAudioDevice *audioDevice;

//@property (nonatomic, strong) TwilioCallingKit *twilioKit;

@end

