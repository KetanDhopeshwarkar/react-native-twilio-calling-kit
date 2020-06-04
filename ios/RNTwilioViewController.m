//
//  ViewController.m
//  TwilioWrapperPOC
//
//  Created by Tushar Korde on 13/04/20.
//  Copyright © 2020 Tushar Korde. All rights reserved.
//

#import "RNTwilioViewController.h"
#import "Utils.h"
#import "TwilioCallingKit.h"

#import <CallKit/CallKit.h>
#import <PushKit/PushKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UserNotifications/UserNotifications.h>

API_AVAILABLE(ios(10.0))
@interface RNTwilioViewController () <UITextFieldDelegate, TVIRemoteParticipantDelegate, TVIRoomDelegate, TVIVideoViewDelegate, TVICameraSourceDelegate, CXProviderDelegate, UNUserNotificationCenterDelegate, PKPushRegistryDelegate>

// Configure access token manually for testing in `ViewDidLoad`, if desired! Create one manually in the console.
//@property (nonatomic, strong) NSString *accessToken;
//@property (nonatomic, strong) NSString *tokenUrl;

#pragma mark Video SDK components

@property (nonatomic, strong) TVICameraSource *camera;
@property (nonatomic, strong) TVILocalVideoTrack *localVideoTrack;
@property (nonatomic, strong) TVILocalAudioTrack *localAudioTrack;
@property (nonatomic, strong) TVIRemoteParticipant *remoteParticipant;
@property (nonatomic, weak) TVIVideoView *remoteView;
@property (nonatomic, strong) TVIRoom *room;

@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) CXCallController *callKitCallController;
@property (nonatomic, strong) PKPushRegistry *pushRegistry;
//@property (nonatomic, strong) TVIDefaultAudioDevice *audioDevice;

@property (nonatomic, copy) void (^callKitCompletionHandler)(BOOL);
@property BOOL userInitiatedDisconnect;
@property BOOL isConnected;
@property BOOL isVoiceCall;
@property BOOL isSpeakerOn;

@property NSString* meetingRoomName;
@property NSTimer* timer;
@property NSTimer *stopWatchTimer;
@property NSTimer *hideUITimer;
@property NSDate *startDateTime;

#pragma mark UI Element Outlets and handles

// `TVIVideoView` created from a storyboard
@property (weak, nonatomic) IBOutlet TVIVideoView *previewView;

@property (nonatomic, weak) IBOutlet UIButton *disconnectButton;
@property (nonatomic, weak) IBOutlet UIButton *micButton;
@property (weak, nonatomic) IBOutlet UIButton *flipButton;
//@property (weak, nonatomic) IBOutlet UIButton *flashButton;
@property (weak, nonatomic) IBOutlet UIButton *videoButton;
@property (weak, nonatomic) IBOutlet UIButton *backButton;
@property (weak, nonatomic) IBOutlet UILabel *callDurationTimerLabel;
@property (weak, nonatomic) IBOutlet UILabel *shopNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *shopCategoryLabel;
@property (weak, nonatomic) IBOutlet UIView *topBackgroundView;
@property (weak, nonatomic) IBOutlet UIView *bottomBackgroundView;
@property (weak, nonatomic) IBOutlet UIImageView *shopPosterImage;
@property (weak, nonatomic) IBOutlet UIButton *speakerButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *backButtonTopConstraint;//16
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *stackViewBottomConstraint;//20
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topBackgroundViewTopConstraint;
@property (weak, nonatomic) IBOutlet UIStackView *bottomControllsStackView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewTrailingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewTopPaddingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewLeadingConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewLBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *previewViewWidthConstraint;

@end

API_AVAILABLE(ios(10.0))
@implementation RNTwilioViewController


- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    
    if (self) {
        CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:@"CallKit Quickstart"];
        [configuration setMaximumCallGroups:1];
        [configuration setMaximumCallsPerCallGroup:1];
        [configuration setSupportsVideo:YES];
        [configuration setSupportedHandleTypes:[[NSSet alloc] initWithObjects:[NSNumber numberWithInt:1], nil]];
        [configuration setIconTemplateImageData:[NSData dataWithContentsOfFile:@"iconMask80"]];
        [configuration setRingtoneSound:@"Ringtone.caf"];
        
        self.callKitProvider = [[CXProvider alloc]initWithConfiguration:configuration];
        [self.callKitProvider setDelegate:self queue:nil];
        self.callKitCallController = [[CXCallController alloc] init];
        self.pushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.pushRegistry.delegate = self;
        self.pushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
    }
    
    return self;
}
- (void)dealloc {
    // We are done with camera
    if (self.camera) {
        [self.camera stopCapture];
        self.camera = nil;
    }
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    if (self.stopWatchTimer) {
        [self.stopWatchTimer invalidate];
        self.stopWatchTimer = nil;
    }
    
    if (self.hideUITimer) {
        [self.hideUITimer invalidate];
        self.hideUITimer = nil;
    }
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self logMessage:[NSString stringWithFormat:@"TwilioVideo v%@", [TwilioVideoSDK sdkVersion]]];
    
    NSLog(@"\n\nProps from JS code");
    NSLog(@"%@", self.props);
    
    self.isConnected = NO;
    self.isSpeakerOn = YES;
    
    [self initialize];

    // Configure access token for testing. Create one manually in the console
    // at https://www.twilio.com/console/video/runtime/testing-tools
//    self.accessToken = @"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzg5NjkwNTg2NGVjMTU3MTE4NjdiZTUzODAxMWM4MDY4LTE1ODg3NzI5MjkiLCJpc3MiOiJTSzg5NjkwNTg2NGVjMTU3MTE4NjdiZTUzODAxMWM4MDY4Iiwic3ViIjoiQUM1MTI3OGMwOTc2NmRhMGI5NzJhZWUzM2MwOWRhN2RjMyIsImV4cCI6MTU4ODc3NjUyOSwiZ3JhbnRzIjp7ImlkZW50aXR5IjoiVHVzaGFyIiwidmlkZW8iOnsicm9vbSI6IlRlc3QxMjMifX19.H_nYLnj1_eBM2Oa7dXEU-p3UqqQvICxAMGm3QQzpNug";
//    self.accessToken = @"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiIsImN0eSI6InR3aWxpby1mcGE7dj0xIn0.eyJqdGkiOiJTSzg5NjkwNTg2NGVjMTU3MTE4NjdiZTUzODAxMWM4MDY4LTE1ODg3NzI4ODkiLCJpc3MiOiJTSzg5NjkwNTg2NGVjMTU3MTE4NjdiZTUzODAxMWM4MDY4Iiwic3ViIjoiQUM1MTI3OGMwOTc2NmRhMGI5NzJhZWUzM2MwOWRhN2RjMyIsImV4cCI6MTU4ODc3NjQ4OSwiZ3JhbnRzIjp7ImlkZW50aXR5IjoiQW1vbCIsInZpZGVvIjp7InJvb20iOiJUZXN0MTIzIn19fQ.3M4XWmm8Xhj_nXQqOsQNiZuzTHKXEu_pSZWTyOLxlMI";
    
    
       if(!self.isVoiceCall){
           // Preview our local camera track in the local video preview view.
           [self startPreview];
       }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleUIControllVisibility)];
    [self.view addGestureRecognizer:tap];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:YES];
    __weak typeof(self)weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf doConnect];
    });
}

- (void)viewDidLayoutSubviews{
    [super viewDidLayoutSubviews];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];

    gradient.frame = self.topBackgroundView.bounds;
    gradient.colors = @[(id)[TokenUtils getUIColorObjectFromHexString:@"#FF7851" alpha:1].CGColor, (id)[TokenUtils getUIColorObjectFromHexString:@"#C70139" alpha:1].CGColor];
    
    gradient.startPoint = CGPointMake(0.0, 0.5);
    gradient.endPoint =  CGPointMake(1.0, 0.5);
    [self.topBackgroundView.layer insertSublayer:gradient atIndex:0];
    [self.view layoutIfNeeded];
}

#pragma mark - Public

- (IBAction)connectButtonPressed:(id)sender {
    if (![self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"] && ![self.accessToken isEqualToString:@""]) {
        [self doConnect];
    } else {
        [self dissmiss];
    }
}

- (IBAction)disconnectButtonPressed:(id)sender {
    if (self.isConnected) {
        [self.room disconnect];
    } else {
        [self dissmiss];
    }
}

- (IBAction)micButtonPressed:(id)sender {
    [self muteUnmuteAudio];
}
- (IBAction)flipCameraButtonPressed:(id)sender {
    [self flipCamera];
}
- (IBAction)flashSwitchButtonPressed:(id)sender {
    [self toggleFlash];
}
- (IBAction)startStopVideo:(UIButton *)sender {
    [self muteUnmuteVideo];
}
- (IBAction)schedulecallButtonPressed:(id)sender {
    
}
- (IBAction)backButtonPressed:(UIButton *)sender {
    [self dissmiss];
}
- (IBAction)speakerButtonPressed:(UIButton *)sender {
    [self toggleSpeakerOnOff:self.isSpeakerOn];
}
-(void)dissmiss {
    if (self.isConnected) {
        [self.room disconnect];
    } else {
        [self dismissViewControllerAnimated:YES completion:^{
            self.room = nil;
            self.audioDevice = nil;
            self.localAudioTrack = nil;
            self.localVideoTrack = nil;
            self.camera = nil;
            self.remoteParticipant = nil;
            [self.remoteView removeFromSuperview];
            self.remoteView = nil;
            self.callKitCompletionHandler = nil;
        }];
    }
    
}

-(void)initialize {
    
    self.flipButton.layer.cornerRadius = 25;
    self.videoButton.layer.cornerRadius = 25;
    self.micButton.layer.cornerRadius = 25;
    self.speakerButton.layer.cornerRadius = 25;
    self.disconnectButton.layer.cornerRadius = 35;
    self.callDurationTimerLabel.layer.cornerRadius = 14.5;
    self.shopPosterImage.layer.cornerRadius = self.shopPosterImage.frame.size.height/2;
    
    if ( !([[self.props objectForKey:@"header"] isKindOfClass:[NSNull class]] || [self.props objectForKey:@"header"] == nil || [[self.props objectForKey:@"header"] isEqualToString:@""]) )
    {
        [self.shopNameLabel setText:[self.props objectForKey:@"header"]];
    }
    
    if ( !([[self.props objectForKey:@"sub_header"] isKindOfClass:[NSNull class]] || [self.props objectForKey:@"sub_header"] == nil || [[self.props objectForKey:@"sub_header"] isEqualToString:@""]) )
    {
        [self.shopCategoryLabel setText:[self.props objectForKey:@"sub_header"]];
    }
    
    if ( !([[self.props objectForKey:@"token"] isKindOfClass:[NSNull class]] || [self.props objectForKey:@"token"] == nil || [[self.props objectForKey:@"token"] isEqualToString:@""]) )
    {
        self.accessToken = [self.props objectForKey:@"token"];
    }
    
    [self.props valueForKey:@"is_voice_call"];
    
    if ( !([[self.props objectForKey:@"is_voice_call"] isKindOfClass:[NSNull class]] || [self.props objectForKey:@"is_voice_call"] == nil || [[self.props objectForKey:@"is_voice_call"] integerValue] == 0))
    {
        
        self.isVoiceCall = YES;
    } else {
        self.isVoiceCall = NO;
    }
    
    if ( !([[self.props objectForKey:@"room_name"] isKindOfClass:[NSNull class]] || [self.props objectForKey:@"room_name"] == nil || [[self.props objectForKey:@"room_name"] isEqualToString:@""]) )
    {
        self.meetingRoomName = [self.props objectForKey:@"room_name"];
    }
    
    if (self.isVoiceCall) {
        self.topBackgroundView.hidden = NO;
        self.bottomBackgroundView.hidden = NO;
        self.flipButton.hidden = YES;
        self.speakerButton.hidden = NO;
        //TODO:
        self.shopPosterImage.hidden = YES;
        
        [self.videoButton setImage:[UIImage imageNamed:@"videocam-off"] forState:UIControlStateNormal];
        self.previewView.hidden = YES;
        
    } else {
        self.topBackgroundView.hidden = YES;
        self.bottomBackgroundView.hidden = YES;
        self.flipButton.hidden = NO;
        self.speakerButton.hidden = YES;
        self.shopPosterImage.hidden = YES;
        [self.videoButton setImage:[UIImage imageNamed:@"videocam-on"] forState:UIControlStateNormal];
         self.previewView.hidden = NO;
    }
}

- (void)onParticipantConnect {
    self.isConnected = YES;
    
    self.callDurationTimerLabel.hidden = NO;
    self.startDateTime = [NSDate date];
    self.stopWatchTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/10.0 target:self selector:@selector(stopWatchReading) userInfo:nil repeats:YES];
    [self setupAutohideTimer];
    
    if (!self.isVoiceCall) {
        [self transformPreviewView];
    }
    
    NSDictionary *userInfo =
    [NSDictionary dictionaryWithObject:@"CONNECTED" forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
                           @"DataUpdated" object:nil userInfo:userInfo];
}

- (void)transformPreviewView {
    self.previewView.layer.cornerRadius = 5;
    [UIView animateWithDuration:0.6
        animations:^{
            self.previewViewTopPaddingConstraint.constant = 130;
            self.previewViewTrailingConstraint.constant = 20;
//            self.previewViewLeadingConstraint.priority = 998;
//            self.previewViewLBottomConstraint.priority = 998;
        
            self.previewViewLeadingConstraint.active = false;
            self.previewViewLBottomConstraint.active = false;
            [self.view layoutIfNeeded]; // Called on parent view
        }];
    
}

- (void)setupAutohideTimer {
    if (self.hideUITimer) {
        [self.hideUITimer invalidate];
        self.hideUITimer = nil;
    }
    self.hideUITimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(autoHideUIControllAfterConnect) userInfo:nil repeats:NO];
    
}

-(void)stopWatchReading
{
  NSDate *currentDate = [NSDate date];
  NSTimeInterval timeInterval = [currentDate timeIntervalSinceDate:self.startDateTime];
  NSDate *timerDate = [NSDate dateWithTimeIntervalSince1970:timeInterval];

  // create the date formatter
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
  [dateFormatter setDateFormat:@"HH:mm:ss"];

  [dateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0.0]];
  NSString *timeStr = [dateFormatter stringFromDate:timerDate];

  //set the text to your label
  [self.callDurationTimerLabel setText:timeStr];
}

- (void)toggleUIControllVisibility {
    if (!self.isConnected) {
        self.previewViewTopPaddingConstraint.constant = 86;
        return;
    }
    BOOL visibility = self.backButton.isHidden;
    
    [UIView animateWithDuration:0.2
    animations:^{
        self.backButton.hidden = !visibility;
        self.shopNameLabel.hidden = !visibility;
        self.shopCategoryLabel.hidden = !visibility;
        self.disconnectButton.hidden = !visibility;
        
        self.bottomControllsStackView.hidden = !visibility;
//        self.flipButton.hidden = !visibility;
//        self.videoButton.hidden = !visibility;
//        self.micButton.hidden = !visibility;
        
        if (self.isVoiceCall) {
            //self.speakerButton.hidden = !visibility;
            self.topBackgroundView.hidden = !visibility;
            self.bottomBackgroundView.hidden = !visibility;
        }
        
//        self.backButtonTopConstraint.constant = visibility ? 16 : -200;
//        self.topBackgroundViewTopConstraint.constant = visibility ? 0 : -200;
//        self.stackViewBottomConstraint.constant = visibility ? 20 : -200;
//        self.previewViewTopPaddingConstraint.constant = visibility ? 86 : 50;
        [self.view layoutIfNeeded]; // Called on parent view
    }];
    
    [self setupAutohideTimer];
}

- (void)autoHideUIControllAfterConnect {
    if (!self.isConnected) {
//        self.previewViewTopPaddingConstraint.constant = 86;
        return;
    }
    BOOL visibility = NO;
    
    [UIView animateWithDuration:0.2
    animations:^{
        self.backButton.hidden = !visibility;
        self.shopNameLabel.hidden = !visibility;
        self.shopCategoryLabel.hidden = !visibility;
        self.disconnectButton.hidden = !visibility;
        
        self.bottomControllsStackView.hidden = !visibility;
//        self.flipButton.hidden = !visibility;
//        self.videoButton.hidden = !visibility;
//        self.micButton.hidden = !visibility;
        
        if (self.isVoiceCall) {
            //self.speakerButton.hidden = !visibility;
            self.topBackgroundView.hidden = !visibility;
            self.bottomBackgroundView.hidden = !visibility;
        } else {
            
        }
        
//        self.backButtonTopConstraint.constant = visibility ? 16 : -200;
//        self.topBackgroundViewTopConstraint.constant = visibility ? 0 : -200;
//        self.stackViewBottomConstraint.constant = visibility ? 20 : -200;
//        self.previewViewTopPaddingConstraint.constant = visibility ? 86 : 50;
        [self.view layoutIfNeeded]; // Called on parent view
    }];
}


-(void)muteUnmuteVideo {
    
    if (self.localVideoTrack) {
        BOOL isEnabled = self.localVideoTrack.isEnabled;
        self.localVideoTrack.enabled = !isEnabled;
        self.previewView.hidden = isEnabled;
        self.flipButton.enabled = !isEnabled;
        
        UIImage *btnImage = isEnabled ? [UIImage imageNamed:@"videocam-off"] : [UIImage imageNamed:@"videocam-on"];
        [self.videoButton setImage:btnImage forState:UIControlStateNormal];
        
        [self switchToVideoCall];
    }
}

-(void)switchToVideoCall {
    
    if (self.localVideoTrack) {
        
        self.speakerButton.hidden = YES;
        self.flipButton.hidden = NO;
        self.isVoiceCall = NO;
        self.shopPosterImage.hidden = YES;
        self.topBackgroundView.hidden = YES;
        self.bottomBackgroundView.hidden = YES;
        
        self.isSpeakerOn = YES;
        [self toggleSpeakerOnOff:YES];
    }
}


-(void)muteUnmuteAudio {
    
    // We will toggle the mic to mute/unmute and change the title according to the user action.
    
    if (self.localAudioTrack) {
        BOOL isEnabled = self.localAudioTrack.isEnabled;
        self.localAudioTrack.enabled = !isEnabled;
        
        UIImage *btnImage = isEnabled ? [UIImage imageNamed:@"mic-off"] : [UIImage imageNamed:@"mic-on"];
        [self.micButton setImage:btnImage forState:UIControlStateNormal];
    }
}


- (void)flipCamera {
    AVCaptureDevice *newDevice = nil;

    if (self.camera.device.position == AVCaptureDevicePositionFront) {
        newDevice = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionBack];
    } else {
        newDevice = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionFront];
    }

    if (newDevice != nil) {
        [self.camera selectCaptureDevice:newDevice completion:^(AVCaptureDevice *device, TVIVideoFormat *format, NSError *error) {
            if (error != nil) {
                [self logMessage:[NSString stringWithFormat:@"Error selecting capture device.\ncode = %lu error = %@", error.code, error.localizedDescription]];
            } else {
                self.previewView.mirror = (device.position == AVCaptureDevicePositionFront);
            }
        }];
    }
}

- (void)toggleFlash {
    if (self.camera && self.camera.device.flashAvailable) {
        if(self.camera.torchMode == AVCaptureTorchModeOn) {
            self.camera.torchMode = AVCaptureTorchModeOff;
        } else if(self.camera.torchMode == AVCaptureTorchModeOff) {
            self.camera.torchMode = AVCaptureTorchModeAuto;
        } else {
             self.camera.torchMode = AVCaptureTorchModeOn;
        }
    }
}

- (void)toggleSpeakerOnOff:(BOOL)isOn {
    
    if (self.localAudioTrack) {
        self.audioDevice.block =  ^ {
            // We will execute `kTVIDefaultAVAudioSessionConfigurationBlock` first.
            kTVIDefaultAVAudioSessionConfigurationBlock();

            // Overwrite the audio route
            AVAudioSession *session = [AVAudioSession sharedInstance];
            NSError *error = nil;
            
            if (isOn) {
                
                if (![session setMode:AVAudioSessionModeVoiceChat error:&error]) {
                    NSLog(@"AVAudiosession setMode %@",error);
                } else {
                    self.isSpeakerOn = !self.isSpeakerOn;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.speakerButton setImage:[UIImage imageNamed:@"speaker-off"] forState:UIControlStateNormal];
                    });
                }
            } else {
                if (![session setMode:AVAudioSessionModeVideoChat error:&error]) {
                    NSLog(@"AVAudiosession setMode %@",error);
                } else {
                    self.isSpeakerOn = !self.isSpeakerOn;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.speakerButton setImage:[UIImage imageNamed:@"speaker-on"] forState:UIControlStateNormal];
                    });
                }
            }

            if (![session overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error]) {
                NSLog(@"AVAudiosession overrideOutputAudioPort %@",error);
            }
        };
        self.audioDevice.block();
    }
}

#pragma mark - Private

- (void)startPreview {
    // TVICameraSource is not supported with the Simulator.
    if ([PlatformUtils isSimulator]) {
        self.previewView.hidden = YES;
        return;
    }
  
    AVCaptureDevice *frontCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionFront];
    AVCaptureDevice *backCamera = [TVICameraSource captureDeviceForPosition:AVCaptureDevicePositionBack];

    if (frontCamera != nil || backCamera != nil) {
        self.camera = [[TVICameraSource alloc] initWithDelegate:self];
        self.localVideoTrack = [TVILocalVideoTrack trackWithSource:self.camera
                                                           enabled:self.isVoiceCall ? NO : YES
                                                              name:@"Camera"];
        // Add renderer to video track for local preview
        [self.localVideoTrack addRenderer:self.previewView];
        [self logMessage:@"Video track created"];

        if (frontCamera != nil && backCamera != nil) {
            self.flipButton.enabled = YES;
        } else {
            self.flipButton.enabled = NO;
        }

        [self.camera startCaptureWithDevice:frontCamera != nil ? frontCamera : backCamera
                                 completion:^(AVCaptureDevice *device, TVIVideoFormat *format, NSError *error) {
                                     if (error != nil) {
                                         [self logMessage:[NSString stringWithFormat:@"Start capture failed with error.\ncode = %lu error = %@", error.code, error.localizedDescription]];
                                     } else {
                                         self.previewView.mirror = (device.position == AVCaptureDevicePositionFront);
                                     }
                                 }];
    } else {
        self.previewView.hidden = YES;
        [self logMessage:@"No front or back capture device found!"];
    }
}


- (void)prepareLocalMedia {
    
    // We will share local audio and video when we connect to room.
    
    //self.audioDevice = [TVIDefaultAudioDevice audioDevice];
    TwilioVideoSDK.audioDevice = self.audioDevice;

    //Set speaker on off //by defult it would be on
    [self toggleSpeakerOnOff:YES];
    
    // Create an audio track.
    if (!self.localAudioTrack) {
        self.localAudioTrack = [TVILocalAudioTrack trackWithOptions:nil
                                                            enabled:YES
                                                               name:@"Microphone"];

        if (!self.localAudioTrack) {
            [self logMessage:@"Failed to add audio track"];
        }
    }

    // Create a video track which captures from the camera.
    if (!self.localVideoTrack) {
        [self startPreview];
    }
}

- (void)doConnect {
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        [self logMessage:@"Please provide a valid token to connect to a room"];
        return;
    }
    
    // Prepare local media which we will share with Room Participants.
    [self prepareLocalMedia];
    
    TVIConnectOptions *connectOptions = [TVIConnectOptions optionsWithToken:self.accessToken
                                                                      block:^(TVIConnectOptionsBuilder * _Nonnull builder) {

        // Use the local media that we prepared earlier.
        builder.audioTracks = self.localAudioTrack ? @[ self.localAudioTrack ] : @[ ];
        builder.videoTracks = self.localVideoTrack ? @[ self.localVideoTrack ] : @[ ];

        // The name of the Room where the Client will attempt to connect to. Please note that if you pass an empty
        // Room `name`, the Client will create one for you. You can get the name or sid from any connected Room.
        builder.roomName = self.meetingRoomName;
    }];
    
    // Connect to the Room using the options we provided.
    self.room = [TwilioVideoSDK connectWithOptions:connectOptions delegate:self];
    
    [self logMessage:[NSString stringWithFormat:@"Attempting to connect to room %@", self.meetingRoomName]];
}

-(void)holdCall:(BOOL)onHold {
    
    [_localAudioTrack setEnabled:!onHold];
    [_localVideoTrack setEnabled:!onHold];
}

-(void)performRoomConnect:(NSUUID *)uuid withRoomName:(NSString *)roomName with:(void (^)(BOOL))completionHandler {
    
    if ([self.accessToken isEqualToString:@"TWILIO_ACCESS_TOKEN"]) {
        
        [self logMessage:[NSString stringWithFormat:@"Fetching an access token"]];
        
        [TokenUtils retrieveAccessTokenFromURL:self.tokenUrl completion:^(NSString *token, NSError *err) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!err) {
                    self.accessToken = token;
                } else {
                    [self logMessage:[NSString stringWithFormat:@"Error retrieving the access token"]];
//                    [self showRoomUI:NO];
                }
            });
        }];
    }
    
    // Prepare local media which we will share with Room Participants.
    [self prepareLocalMedia];
    
    TVIConnectOptions *connectOptions = [TVIConnectOptions optionsWithToken:self.accessToken
                                                                      block:^(TVIConnectOptionsBuilder * _Nonnull builder) {
        
        // Use the local media that we prepared earlier.
        builder.audioTracks = self.localAudioTrack ? @[ self.localAudioTrack ] : @[ ];
        builder.videoTracks = self.localVideoTrack ? @[ self.localVideoTrack ] : @[ ];
        
        builder.roomName = self.meetingRoomName;
        builder.uuid = uuid;
    }];
    
    // Connect to the Room using the options we provided.
    self.room = [TwilioVideoSDK connectWithOptions:connectOptions delegate:self];
    
    [self logMessage:[NSString stringWithFormat:@"Attempting to connect to room %@", self.meetingRoomName]];
    
//    [self showRoomUI:YES];
    self.callKitCompletionHandler = completionHandler;
}

- (void)setupRemoteView {
    // Creating `TVIVideoView` programmatically
    TVIVideoView *remoteView = [[TVIVideoView alloc] init];
    
    // `TVIVideoView` supports UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFill and UIViewContentModeScaleAspectFit
    // UIViewContentModeScaleAspectFit is the default mode when you create `TVIVideoView` programmatically.
    remoteView.contentMode = UIViewContentModeScaleAspectFill;
    [self.view insertSubview:remoteView atIndex:0];
    self.remoteView = remoteView;
    
    NSLayoutConstraint *centerX = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterX
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterX
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerX];
    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                               attribute:NSLayoutAttributeCenterY
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.view
                                                               attribute:NSLayoutAttributeCenterY
                                                              multiplier:1
                                                                constant:0];
    [self.view addConstraint:centerY];
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:self.view
                                                             attribute:NSLayoutAttributeWidth
                                                            multiplier:1
                                                              constant:0];
    [self.view addConstraint:width];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.remoteView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:self.view
                                                              attribute:NSLayoutAttributeHeight
                                                             multiplier:1
                                                               constant:0];
    [self.view addConstraint:height];
}

- (void)cleanupRemoteParticipant {
    if (self.remoteParticipant) {
        if ([self.remoteParticipant.videoTracks count] > 0) {
            TVIRemoteVideoTrack *videoTrack = self.remoteParticipant.remoteVideoTracks[0].remoteTrack;
            [videoTrack removeRenderer:self.remoteView];
            [self.remoteView removeFromSuperview];
        }
        self.remoteParticipant = nil;
    }
}

- (void)logMessage:(NSString *)msg {
    NSLog(@"%@", msg);
}

#pragma mark - TVIRoomDelegate

- (void)didConnectToRoom:(TVIRoom *)room {
    // At the moment, this example only supports rendering one Participant at a time.
    
    [self logMessage:[NSString stringWithFormat:@"Connected to room %@ as %@", room.name, room.localParticipant.identity]];
    
    if (room.remoteParticipants.count > 0) {
        self.remoteParticipant = room.remoteParticipants[0];
        self.remoteParticipant.delegate = self;
    }
    [self onParticipantConnect];
}

- (void)room:(TVIRoom *)room didDisconnectWithError:(nullable NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Disconncted from room %@, error = %@", room.name, error]];
    
    [self cleanupRemoteParticipant];
    
    self.isConnected = NO;
    [self dissmiss];
    
    //Send event to JS
//    [TwilioCallingKit sendEventToJS:@"DISCONNECTED"];
    NSDictionary *userInfo =
    [NSDictionary dictionaryWithObject:@"DISCONNECTED" forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
                           @"DataUpdated" object:nil userInfo:userInfo];
    
    //[self showRoomUI:NO];
}

- (void)room:(TVIRoom *)room didFailToConnectWithError:(nonnull NSError *)error{
    [self logMessage:[NSString stringWithFormat:@"Failed to connect to room, error = %@", error]];
    
    //Send event to JS
//    [TwilioCallingKit sendEventToJS:@"FAIL_TO_CONNECT"];
    NSDictionary *userInfo =
    [NSDictionary dictionaryWithObject:@"FAIL_TO_CONNECT" forKey:@"event"];
    [[NSNotificationCenter defaultCenter] postNotificationName:
                           @"DataUpdated" object:nil userInfo:userInfo];
    
    self.isConnected = NO;
    [self dissmiss];
}

- (void)room:(TVIRoom *)room isReconnectingWithError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:@"Reconnecting due to %@", error.localizedDescription];
    [self logMessage:message];
}

- (void)didReconnectToRoom:(TVIRoom *)room {
    [self logMessage:@"Reconnected to room"];
}

- (void)room:(TVIRoom *)room participantDidConnect:(TVIRemoteParticipant *)participant {
    if (!self.remoteParticipant) {
        self.remoteParticipant = participant;
        self.remoteParticipant.delegate = self;
    }
    
    //[self onParticipantConnect];
    [self logMessage:[NSString stringWithFormat:@"Participant %@ connected with %lu audio and %lu video tracks",
                      participant.identity,
                      (unsigned long)[participant.audioTracks count],
                      (unsigned long)[participant.videoTracks count]]];
}

- (void)room:(TVIRoom *)room participantDidDisconnect:(TVIRemoteParticipant *)participant {
    if (self.remoteParticipant == participant) {
        [self cleanupRemoteParticipant];
    }
    self.isConnected = NO;
    [self dissmiss];
    [self logMessage:[NSString stringWithFormat:@"Room %@ participant %@ disconnected", room.name, participant.identity]];
}

#pragma mark - TVIRemoteParticipantDelegate

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didPublishVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has offered to share the video Track.
    //[self switchToVideoCall];
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ video track .",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
   didUnpublishVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the video Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didPublishAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has offered to share the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ published %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
   didUnpublishAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    
    // Remote Participant has stopped sharing the audio Track.
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ unpublished %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didSubscribeToVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                     publication:(TVIRemoteVideoTrackPublication *)publication
                  forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's video frames now.
    //[self switchToVideoCall];
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [self setupRemoteView];
        [videoTrack addRenderer:self.remoteView];
    }
}

- (void)didUnsubscribeFromVideoTrack:(TVIRemoteVideoTrack *)videoTrack
                         publication:(TVIRemoteVideoTrackPublication *)publication
                      forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's video Track. We will no longer receive the
    // remote Participant's video.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ video track for Participant %@",
                      publication.trackName, participant.identity]];
    
    if (self.remoteParticipant == participant) {
        [videoTrack removeRenderer:self.remoteView];
        [self.remoteView removeFromSuperview];
    }
}

- (void)didSubscribeToAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                     publication:(TVIRemoteAudioTrackPublication *)publication
                  forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are subscribed to the remote Participant's audio Track. We will start receiving the
    // remote Participant's audio now.
    
    [self logMessage:[NSString stringWithFormat:@"Subscribed to %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)didUnsubscribeFromAudioTrack:(TVIRemoteAudioTrack *)audioTrack
                         publication:(TVIRemoteAudioTrackPublication *)publication
                      forParticipant:(TVIRemoteParticipant *)participant {
    
    // We are unsubscribed from the remote Participant's audio Track. We will no longer receive the
    // remote Participant's audio.
    
    [self logMessage:[NSString stringWithFormat:@"Unsubscribed from %@ audio track for Participant %@",
                      publication.trackName, participant.identity]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      didEnableVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    
    //[self switchToVideoCall];
    
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didDisableVideoTrack:(TVIRemoteVideoTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ video track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
      didEnableAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ enabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)remoteParticipant:(TVIRemoteParticipant *)participant
     didDisableAudioTrack:(TVIRemoteAudioTrackPublication *)publication {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ disabled %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didFailToSubscribeToAudioTrack:(TVIRemoteAudioTrackPublication *)publication
                                 error:(NSError *)error
                        forParticipant:(TVIRemoteParticipant *)participant {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ failed to subscribe to %@ audio track.",
                      participant.identity, publication.trackName]];
}

- (void)didFailToSubscribeToVideoTrack:(TVIRemoteVideoTrackPublication *)publication
                                 error:(NSError *)error
                        forParticipant:(TVIRemoteParticipant *)participant {
    [self logMessage:[NSString stringWithFormat:@"Participant %@ failed to subscribe to %@ video track.",
                      participant.identity, publication.trackName]];
}

#pragma mark - TVIVideoViewDelegate

- (void)videoView:(TVIVideoView *)view videoDimensionsDidChange:(CMVideoDimensions)dimensions {
    NSLog(@"Dimensions changed to: %d x %d", dimensions.width, dimensions.height);
    [self.view setNeedsLayout];
}

#pragma mark - TVICameraSourceDelegate

- (void)cameraSource:(TVICameraSource *)source didFailWithError:(NSError *)error {
    [self logMessage:[NSString stringWithFormat:@"Capture failed with error.\ncode = %lu error = %@", error.code, error.localizedDescription]];
}

#pragma mark - CXProviderDelegate

- (void)providerDidReset:(nonnull CXProvider *)provider {
    
    [self logMessage:@"providerDidReset:"];
    //  AudioDevice is enabled by default
    [self.audioDevice setEnabled:YES];
    [self.room disconnect];
}

- (void)providerDidBegin:(CXProvider *)provider {
    [self logMessage:@"providerDidBegin"];
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
    [self logMessage:@"provider:didDeactivateAudioSession:"];
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
    
    [self logMessage:@"provider:didActivateAudioSession:"];
    [self.audioDevice setEnabled:YES];
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    [self logMessage:@"provider:timedOutPerformingAction:"];
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    
    [self logMessage:@"provider:performStartCallAction:"];
    
    /*
     * Configure the audio session, but do not start call audio here, since it must be done once
     * the audio session has been activated by the system after having its priority elevated.
     */
    
    // Stop the audio unit by setting isEnabled to `false`.
    [self.audioDevice setEnabled:NO];
    
    // Configure the AVAudioSession by executign the audio device's `block`.
    self.audioDevice.block();
    
    [self.callKitProvider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:nil];
    
    [self performRoomConnect:action.callUUID withRoomName:action.handle.value with:^(BOOL success) {
        
        if(success) {
            [provider reportOutgoingCallWithUUID:action.callUUID connectedAtDate:nil];
            [action fulfill];
        } else {
            [action fail];
        }
    }];
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {
    
    [self logMessage:@"provider:performAnswerCallAction:"];
    
    /*
     * Configure the audio session, but do not start call audio here, since it must be done once
     * the audio session has been activated by the system after having its priority elevated.
     */
    
    // Stop the audio unit by setting isEnabled to `false`.
    [self.audioDevice setEnabled:NO];
    
    // Configure the AVAudioSession by executign the audio device's `block`.
    self.audioDevice.block();
    
    [self performRoomConnect:action.callUUID withRoomName:self.meetingRoomName with:^(BOOL success) {
        
        if(success) {
            [action fulfillWithDateConnected:[NSDate date]];
        } else {
            [action fail];
        }
    }];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    
    NSLog(@"provider:performEndCallAction:");
    [self.room disconnect];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action {
    
    NSLog(@"provier:performSetMutedCallAction:");
    [self muteUnmuteAudio];
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action {
    
    NSLog(@"provier:performSetHeldCallAction:");
    
    CXCallObserver *cxObserver = _callKitCallController.callObserver;
    NSArray <CXCall *> *calls = cxObserver.calls;
    
    NSArray *filteredArray = [calls filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:
                                                                 @"UUID == %@",action.UUID]];
    
    CXCall *call = filteredArray.firstObject;
    
    if (call) {
        if (call.isOnHold) {
            [self holdCall:false];
        } else {
            [self holdCall:YES];
        }
    }
    
    [action fulfill];
}

-(void)performStartCallAction:(NSUUID *)uuid with:(NSString *)roomName {
    
    CXHandle *callHandle = [[CXHandle alloc]initWithType:CXHandleTypeGeneric value:roomName];
    
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc]initWithCallUUID:uuid handle:callHandle];
    
    [startCallAction setVideo:YES];
    
    CXTransaction *transaction = [[CXTransaction alloc]initWithAction:startCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@",error.localizedDescription);
            return;
        }
        NSLog(@"StartCallAction transaction request successful");
    }];
}

-(void)reportIncomingCallWith:(NSUUID *)uuid roomName:(NSString *)roomName with:(void (^)(NSError *))completion {
    
    CXHandle *callHandle = [[CXHandle alloc]initWithType:CXHandleTypeGeneric value:roomName];
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    [callUpdate setRemoteHandle:callHandle];
    [callUpdate setSupportsDTMF:NO];
    [callUpdate setSupportsHolding:YES];
    [callUpdate setSupportsUngrouping:NO];
    [callUpdate setSupportsGrouping:NO];
    [callUpdate setHasVideo:YES];
    
    [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError * _Nullable error) {
        if(error) {
            NSLog(@"Failed to report incoming call successfully: %@ .",error.localizedDescription);
        } else {
            NSLog(@"Incoming call successfully reported.");
        }
        completion(error);
    }];
}

-(void)performEndCallAction:(NSUUID *)uuid {
    
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc]initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc]initWithAction:endCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@.",error.localizedDescription);
            return;
        }else {
            NSLog(@"EndCallAction transaction request successful");
        }
    }];
}

#pragma mark - UserNotifications

-(void)registerForLocalNotifications {
    
    UNNotificationAction *inviteAction = [UNNotificationAction actionWithIdentifier:@"INVITE_ACTION" title:@"Simulate VoIP Push" options:UNNotificationActionOptionNone];
    
    UNNotificationAction *declineAction = [UNNotificationAction actionWithIdentifier:@"DECLINE_ACTION" title:@"Decline" options:UNNotificationActionOptionDestructive];
    
    UNUserNotificationCenter *notificationCenter = [UNUserNotificationCenter currentNotificationCenter];
    
    UNNotificationCategory *meetingInviteCategory = [UNNotificationCategory categoryWithIdentifier:@"ROOM_INVITATION" actions:[NSArray arrayWithObjects:inviteAction,declineAction, nil] intentIdentifiers:[[NSArray alloc]init] options:UNNotificationCategoryOptionCustomDismissAction];
    
    [notificationCenter setNotificationCategories:[NSSet setWithObjects:meetingInviteCategory, nil]];
    
    notificationCenter.delegate = self;
    
    [notificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert completionHandler:^(BOOL granted, NSError * _Nullable error) {
        
    }];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    
    NSLog(@"Will present notification %@",notification);
    [self reportIncomingCallWith:[NSUUID UUID] roomName:[self parseNotification:notification] with:^(NSError *error) {
        completionHandler(UNNotificationPresentationOptionNone);
    }];
}

-(NSString *)parseNotification:(UNNotification *)notification1 {
    
    if([notification1.request.content.userInfo valueForKey:@"roomName"] != nil) {
        return [notification1.request.content.userInfo valueForKey:@"roomName"];
    }
    return @"";
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    
    NSLog(@"Received notification response in %ld %@",(long)[[UIApplication sharedApplication] applicationState],response);
    
    NSString *roomName = [self parseNotification:response.notification];
    NSString *identifier = response.actionIdentifier;
    
    if([identifier isEqualToString:UNNotificationDefaultActionIdentifier]) {
        
        [self performStartCallAction:[NSUUID UUID] with:roomName];
        completionHandler();
        
    } else if ([identifier isEqualToString:@"INVITE_ACTION"]) {
        
        [self reportIncomingCallWith:[NSUUID UUID] roomName:roomName with:^(NSError *error) {
            completionHandler();
        }];
        
    } else {
        completionHandler();
    }
}

#pragma mark - PKPushRegistryDelegate

- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type withCompletionHandler:(void (^)(void))completion {
    
    NSString *uuidString = payload.dictionaryPayload[@"UUID"];
    NSString *identifier = payload.dictionaryPayload[@"identifier"];
    NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
    
    if (uuidString && identifier && uuid) {
        
        CXCallUpdate *update = [[CXCallUpdate alloc] init];
        [update setLocalizedCallerName:identifier];
        
        [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:update completion:^(NSError * _Nullable error) {
            if(error) {
                NSLog(@"Failed to report incoming call successfully: %@ .",error.localizedDescription);
            } else {
                NSLog(@"Incoming call successfully reported.");
            }
        }];
    }
}

- (void)pushRegistry:(nonnull PKPushRegistry *)registry didUpdatePushCredentials:(nonnull PKPushCredentials *)pushCredentials forType:(nonnull PKPushType)type {
    
    if([pushCredentials.token length] == 0) {
        NSLog(@"voip token NULL");
        return;
    }
    NSLog(@"PushCredentials: %@", pushCredentials.token);
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    NSLog(@"Voip token invalidate");
}


@end
