#import "StringeePlugin.h"

// Events
static NSString *clientEvents = @"clientEvents";
static NSString *callEvents = @"callEvents";

// Client
static NSString *didConnect               = @"didConnect";
static NSString *didDisConnect            = @"didDisConnect";
static NSString *didFailWithError         = @"didFailWithError";
static NSString *requestAccessToken       = @"requestAccessToken";

static NSString *incomingCall               = @"incomingCall";

// Call
static NSString *didChangeSignalingState    = @"didChangeSignalingState";
static NSString *didChangeMediaState        = @"didChangeMediaState";
static NSString *didReceiveLocalStream      = @"didReceiveLocalStream";
static NSString *didReceiveRemoteStream     = @"didReceiveRemoteStream";
static NSString *didReceiveDtmfDigit        = @"didReceiveDtmfDigit";
static NSString *didReceiveCallInfo         = @"didReceiveCallInfo";
static NSString *didHandleOnAnotherDevice   = @"didHandleOnAnotherDevice";

@implementation StringeePlugin {
    StringeeClient *_client;
    NSMutableDictionary *callbackList;
    NSMutableDictionary *callList;
    NSMutableOrderedSet *signalingEndList;
    NSMutableOrderedSet *mediaEndList;
}

#pragma mark Common

-(void) pluginInitialize{
    // Make the web view transparent.
    [self.webView setOpaque:false];
    [self.webView setBackgroundColor:UIColor.clearColor];

    callbackList = [[NSMutableDictionary alloc] init];
    callList = [[NSMutableDictionary alloc] init];
    signalingEndList = [[NSMutableOrderedSet alloc] init];
    mediaEndList = [[NSMutableOrderedSet alloc] init];
}

- (void)addEvent:(CDVInvokedUrlCommand*)command {
    NSString* event = [command.arguments objectAtIndex:0];
    [callbackList setObject:command.callbackId forKey:event];
}

#pragma mark StringeeClient

- (void)initStringeeClient:(CDVInvokedUrlCommand *)command {
    // Khởi tạo client nếu chưa có
    if (!_client) {
        _client = [[StringeeClient alloc] initWithConnectionDelegate:self];
        _client.incomingCallDelegate = self;
    }
}

- (void)connect:(CDVInvokedUrlCommand*)command {
    NSString *token = [[command arguments] objectAtIndex:0];
    [_client connectWithAccessToken:token];
}

- (void)disconnect:(CDVInvokedUrlCommand*)command {
    if (_client) {
        [_client disconnect];
    }
}

- (void)registerPush:(CDVInvokedUrlCommand*)command {
    if (!_client || !_client.hasConnected) {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-1) forKey:@"code"];
        [eventData setObject:@"StringeeClient is not initialized or connected." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
        return;
    }

    NSString *deviceToken = [[command arguments] objectAtIndex:0];
    NSNumber *isProduction = [[command arguments] objectAtIndex:1];
    NSNumber *isVoip = [[command arguments] objectAtIndex:2];

    [_client registerPushForDeviceToken:deviceToken isProduction:[isProduction boolValue] isVoip:[isVoip boolValue] completionHandler:^(BOOL status, int code, NSString *message) {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(code) forKey:@"code"];
        [eventData setObject:message forKey:@"message"];
        [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
    }];
}

- (void)unregisterPush:(CDVInvokedUrlCommand*)command {
    if (!_client || !_client.hasConnected) {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-1) forKey:@"code"];
        [eventData setObject:@"StringeeClient is not initialized or connected." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
        return;
    }

    NSString *deviceToken = [[command arguments] objectAtIndex:0];

    [_client unregisterPushForDeviceToken:deviceToken completionHandler:^(BOOL status, int code, NSString *message) {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(code) forKey:@"code"];
        [eventData setObject:message forKey:@"message"];
        [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
    }];
}

#pragma mark Connection Delegate

- (void)didConnect:(StringeeClient *)stringeeClient isReconnecting:(BOOL)isReconnecting {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeClient.userId forKey:@"userId"];
    [eventData setObject:stringeeClient.projectId forKey:@"projectId"];
    [eventData setObject:@(isReconnecting) forKey:@"isReconnecting"];

    [self triggerJSEvent: clientEvents withType: didConnect withData: eventData];
}

- (void)didDisConnect:(StringeeClient *)stringeeClient isReconnecting:(BOOL)isReconnecting {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeClient.userId forKey:@"userId"];
    [eventData setObject:stringeeClient.projectId forKey:@"projectId"];
    [eventData setObject:@(isReconnecting) forKey:@"isReconnecting"];

    [self triggerJSEvent: clientEvents withType: didDisConnect withData: eventData];
}

- (void)didFailWithError:(StringeeClient *)stringeeClient code:(int)code message:(NSString *)message {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeClient.userId forKey:@"userId"];
    [eventData setObject:@(code) forKey:@"code"];
    [eventData setObject:message forKey:@"message"];

    [self triggerJSEvent: clientEvents withType: didFailWithError withData: eventData];
}

- (void)requestAccessToken:(StringeeClient *)stringeeClient {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeClient.userId forKey:@"userId"];

    [self triggerJSEvent: clientEvents withType: requestAccessToken withData: eventData];
}

#pragma mark IncomingCall Delegate

- (void)incomingCallWithStringeeClient:(StringeeClient *)stringeeClient stringeeCall:(StringeeCall *)stringeeCall {
    [callList setObject:stringeeCall forKey:stringeeCall.callId];

    int index = 0;

    if (stringeeCall.callType == CallTypeCallIn) {
        // Phone-to-app
        index = 3;
    } else if (stringeeCall.callType == CallTypeCallOut) {
        // App-to-phone
        index = 2;
    } else if (stringeeCall.callType == CallTypeInternalIncomingCall) {
        // App-to-app-incoming-call
        index = 1;
    } else {
        // App-to-app-outgoing-call
        index = 0;
    }

    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeClient.userId forKey:@"userId"];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [eventData setObject:stringeeCall.from forKey:@"from"];
    [eventData setObject:stringeeCall.to forKey:@"to"];
    [eventData setObject:stringeeCall.fromAlias forKey:@"fromAlias"];
    [eventData setObject:stringeeCall.toAlias forKey:@"toAlias"];
    [eventData setObject:@(index) forKey:@"callType"];
    [eventData setObject:@(stringeeCall.isVideoCall) forKey:@"isVideoCall"];
    [eventData setObject:stringeeCall.customDataFromYourServer forKey:@"customDataFromYourServer"];

    [self triggerJSEvent: clientEvents withType: incomingCall withData: eventData];    
}

#pragma mark StringeeCall

- (void)initStringeeCall:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSString *from = [[command arguments] objectAtIndex:1];
    NSString *to = [[command arguments] objectAtIndex:2];
    NSNumber *isVideoCall = [[command arguments] objectAtIndex:3];
    NSString *videoResolution = [[command arguments] objectAtIndex:4];
    NSString *customData = [[command arguments] objectAtIndex:5];

    StringeeCall *outgoingCall = [[StringeeCall alloc] initWithStringeeClient:_client from:from to:to];
    outgoingCall.delegate = self;
    outgoingCall.isVideoCall = [isVideoCall boolValue];

    if (customData.length) {
        outgoingCall.customData = customData;
    }

    if ([videoResolution isEqualToString:@"HD"]) {
        outgoingCall.videoResolution = VideoResolution_HD;
    }

    [callList setObject:outgoingCall forKey:iden];
}

- (void)makeCall:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    // [callbackList setObject:command.callbackId forKey:iden];

    StringeeCall *outgoingCall = [callList objectForKey:iden];
    if (outgoingCall) {
        [outgoingCall makeCallWithCompletionHandler:^(BOOL status, int code, NSString *message, NSString *data) {
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(code) forKey:@"code"];
            [eventData setObject:message forKey:@"message"];
            [eventData setObject:data forKey:@"customDataFromYourServer"];

            [eventData setObject:outgoingCall.callId forKey:@"callId"];
            [eventData setObject:outgoingCall.from forKey:@"from"];
            [eventData setObject:outgoingCall.to forKey:@"to"];
            [eventData setObject:outgoingCall.fromAlias forKey:@"fromAlias"];
            [eventData setObject:outgoingCall.toAlias forKey:@"toAlias"];
            [eventData setObject:@(outgoingCall.callType) forKey:@"callType"];

            [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
            if (!status) {
                [callbackList removeObjectForKey:iden];
            }
        }];
    } else {
        [callbackList removeObjectForKey:iden];

        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Make call failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)initAnswer:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    // [callbackList setObject:command.callbackId forKey:iden];
 
    StringeeCall *incomingCall = [callList objectForKey:iden];

    if (incomingCall) {
        incomingCall.delegate = self;
        [incomingCall initAnswerCall];

        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Init answer call successful" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        // Khong tim duoc cuoc goi thi xoa luon callbackId
        [callbackList removeObjectForKey:iden];
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Init answer call failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)answer:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
 
    StringeeCall *incomingCall = [callList objectForKey:iden];

    if (incomingCall) {
        [incomingCall answerCallWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(code) forKey:@"code"];
            [eventData setObject:message forKey:@"message"];
            [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
        }];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Answer call failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)hangup:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
 
    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
        [call hangupWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(code) forKey:@"code"];
            [eventData setObject:message forKey:@"message"];
            [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
        }];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Hangup call failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)reject:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
 
    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
        [call rejectWithCompletionHandler:^(BOOL status, int code, NSString *message) {
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(code) forKey:@"code"];
            [eventData setObject:message forKey:@"message"];
            [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
        }];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Reject call failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)sendDTMF:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSString *dtmf = [[command arguments] objectAtIndex:1];

    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
            NSArray *DTMF = @[@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"*", @"#"];
            if ([DTMF containsObject:dtmf]) {

                CallDTMF dtmfParam;
        
                if ([dtmf isEqualToString:@"0"]) {
                    dtmfParam = CallDTMFZero;
                }
                else if ([dtmf isEqualToString:@"1"]) {
                    dtmfParam = CallDTMFOne;
                }
                else if ([dtmf isEqualToString:@"2"]) {
                    dtmfParam = CallDTMFTwo;
                }
                else if ([dtmf isEqualToString:@"3"]) {
                    dtmfParam = CallDTMFThree;
                }
                else if ([dtmf isEqualToString:@"4"]) {
                    dtmfParam = CallDTMFFour;
                }
                else if ([dtmf isEqualToString:@"5"]) {
                    dtmfParam = CallDTMFFive;
                }
                else if ([dtmf isEqualToString:@"6"]) {
                    dtmfParam = CallDTMFSix;
                }
                else if ([dtmf isEqualToString:@"7"]) {
                    dtmfParam = CallDTMFSeven;
                }
                else if ([dtmf isEqualToString:@"8"]) {
                    dtmfParam = CallDTMFEight;
                }
                else if ([dtmf isEqualToString:@"9"]) {
                    dtmfParam = CallDTMFNine;
                }
                else if ([dtmf isEqualToString:@"*"]) {
                    dtmfParam = CallDTMFStar;
                }
                else {
                    dtmfParam = CallDTMFPound;
                }

                [call sendDTMF:dtmfParam completionHandler:^(BOOL status, int code, NSString *message) {
                    NSString *msgParam;
                    int codeParam;
                    if (status) {
                        msgParam = @"Send DTMF successfully";
                        codeParam = 0;
                    } else {
                        msgParam = @"Send DTMF failed. The client is not connected to Stringee Server.";
                        codeParam = -1;
                    }

                    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
                    [eventData setObject:@(codeParam) forKey:@"code"];
                    [eventData setObject:msgParam forKey:@"message"];
                    [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
                }];
            } else {
                NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
                [eventData setObject:@(-4) forKey:@"code"];
                [eventData setObject:@"Send DTMF failed. The dtmf is invalid." forKey:@"message"];
                [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
            }
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Send DTMF failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)sendCallInfo:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSString *callInfo = [[command arguments] objectAtIndex:1];

    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
        NSError *jsonError;
        NSData *objectData = [callInfo dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *data = [NSJSONSerialization JSONObjectWithData:objectData
                                                        options:NSJSONReadingMutableContainers 
                                                        error:&jsonError];

        if (jsonError) {
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(-4) forKey:@"code"];
            [eventData setObject:@"Send call info failed. The call info format is invalid." forKey:@"message"];
            [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
        } else {
            [call sendCallInfo:data completionHandler:^(BOOL status, int code, NSString *message) {
                NSString *msgParam;
                int codeParam;
                if (status) {
                    msgParam = @"Send call info successfully";
                    codeParam = 0;
                } else {
                    msgParam = @"Send call info failed. The client is not connected to Stringee Server.";
                    codeParam = -1;
                }

                NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
                [eventData setObject:@(codeParam) forKey:@"code"];
                [eventData setObject:msgParam forKey:@"message"];
                [self triggerCallbackWithStatus:status withData:eventData withCallbackId:command.callbackId];
            }];
        }
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Send call info failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)getCallStats:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
 
    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
        [call statsWithCompletionHandler:^(NSDictionary<NSString *,NSString *> *values) {
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:values
                                            options:NSJSONWritingPrettyPrinted
                                            error:nil];
            NSString *jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@" " withString:@""];
            NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
            [eventData setObject:@(0) forKey:@"code"];
            [eventData setObject:@"Success" forKey:@"message"];
            [eventData setObject:jsonString forKey:@"stats"];
            [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
        }];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Can not get call stats. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)mute:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSNumber *mute = [[command arguments] objectAtIndex:1];

    StringeeCall *call = [callList objectForKey:iden];
    if (call) {
        [call mute:[mute boolValue]];
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Success" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)setSpeakerphoneOn:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSNumber *speaker = [[command arguments] objectAtIndex:1];

    StringeeCall *call = [callList objectForKey:iden];
    if (call) {
        [[StringeeAudioManager instance] setLoudspeaker:[speaker boolValue]];
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Success" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)switchCamera:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
 
    StringeeCall *call = [callList objectForKey:iden];
    if (call) {
        [call switchCamera];
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Success" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)enableVideo:(CDVInvokedUrlCommand *)command {
    NSString *iden = [[command arguments] objectAtIndex:0];
    NSNumber *enableVideo = [[command arguments] objectAtIndex:1];

    StringeeCall *call = [callList objectForKey:iden];
    if (call) {
        [call enableLocalVideo:[enableVideo boolValue]];
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Success" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

- (void)renderVideo:(CDVInvokedUrlCommand*)command {
    NSString* callback = command.callbackId;
    NSString *iden = [[command arguments] objectAtIndex:0];
    BOOL isLocal = [[command.arguments objectAtIndex:1] boolValue];
    int top = [[command.arguments objectAtIndex:2] intValue];
    int left = [[command.arguments objectAtIndex:3] intValue];
    int width = [[command.arguments objectAtIndex:4] intValue];
    int height = [[command.arguments objectAtIndex:5] intValue];
    int zIndex = [[command.arguments objectAtIndex:6] intValue];

    StringeeCall *call = [callList objectForKey:iden];

    if (call) {
        if (isLocal) {
            [self.webView.scrollView addSubview:call.localVideoView];
            [call.localVideoView setFrame:CGRectMake(left, top, width, height)];
            // Set depth location of camera view based on CSS z-index.
            call.localVideoView.layer.zPosition = zIndex;
        } else {
            UIView *containRemoteView = [[UIView alloc] init];
            [containRemoteView setBackgroundColor:[UIColor blackColor]];
            [containRemoteView setFrame:CGRectMake(left, top, width, height)];
            [containRemoteView addSubview:call.remoteVideoView];
            [self.webView.scrollView addSubview:containRemoteView];
            call.remoteVideoView.delegate = self;
            [call.remoteVideoView setFrame:CGRectMake(left, top, width, height)];
            // Set depth location of camera view based on CSS z-index.
            call.remoteVideoView.layer.zPosition = zIndex;
        }
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(0) forKey:@"code"];
        [eventData setObject:@"Success" forKey:@"message"];
        [self triggerCallbackWithStatus:true withData:eventData withCallbackId:command.callbackId];
    } else {
        NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
        [eventData setObject:@(-3) forKey:@"code"];
        [eventData setObject:@"Failed. The call is not found." forKey:@"message"];
        [self triggerCallbackWithStatus:false withData:eventData withCallbackId:command.callbackId];
    }
}

#pragma mark RemoteView Delegate

- (void)videoView:(StringeeRemoteVideoView *)videoView didChangeVideoSize:(CGSize)size {

    // Thay đổi frame của StringeeRemoteVideoView khi kích thước video thay đổi
    CGFloat superWidth = videoView.superview.bounds.size.width;
    CGFloat superHeight = videoView.superview.bounds.size.height;
    
    CGFloat newWidth;
    CGFloat newHeight;
    
    if (size.width > size.height) {
        newWidth = superWidth;
        newHeight = newWidth * size.height / size.width;
        
        [videoView setFrame:CGRectMake(0, (superHeight - newHeight) / 2, newWidth, newHeight)];
        
    } else {
        newHeight = superHeight;
        newWidth = newHeight * size.width / size.height;
        
        [videoView setFrame:CGRectMake((superWidth - newWidth) / 2, 0, newWidth, newHeight)];
    }
}

#pragma mark Call Delegate

- (void)didChangeSignalingState:(StringeeCall *)stringeeCall signalingState:(SignalingState)signalingState reason:(NSString *)reason sipCode:(int)sipCode sipReason:(NSString *)sipReason {
    
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [eventData setObject:@(signalingState) forKey:@"code"];
    [eventData setObject:reason forKey:@"reason"];
    [eventData setObject:@(sipCode) forKey:@"sipCode"];
    [eventData setObject:sipReason forKey:@"sipReason"];

    [self triggerEventForCall:stringeeCall withType:didChangeSignalingState withData:eventData];

    if (signalingState == SignalingStateBusy || signalingState == SignalingStateEnded) {
        [signalingEndList addObject:stringeeCall.callId];
    }

    [self checkAndReleaseCall:stringeeCall];
}

- (void)didChangeMediaState:(StringeeCall *)stringeeCall mediaState:(MediaState)mediaState {

    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    switch (mediaState) {
        case MediaStateConnected:
            [eventData setObject:@(0) forKey:@"code"];
            [eventData setObject:@"Connected" forKey:@"description"];
            [mediaEndList removeObject:stringeeCall.callId];
            break;
        case MediaStateDisconnected:
            [eventData setObject:@(1) forKey:@"code"];
            [eventData setObject:@"Disconnected" forKey:@"description"];
            [mediaEndList addObject:stringeeCall.callId];
            break;
        default:
            break;
    }

    [self triggerEventForCall:stringeeCall withType:didChangeMediaState withData:eventData];

    [self checkAndReleaseCall:stringeeCall];
}

- (void)didReceiveLocalStream:(StringeeCall *)stringeeCall {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [self triggerEventForCall:stringeeCall withType:didReceiveLocalStream withData:eventData];
}

- (void)didReceiveRemoteStream:(StringeeCall *)stringeeCall {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [self triggerEventForCall:stringeeCall withType:didReceiveRemoteStream withData:eventData];
}

- (void)didReceiveDtmfDigit:(StringeeCall *)stringeeCall callDTMF:(CallDTMF)callDTMF {
    NSString * digit = @"";
    if ((long)callDTMF <= 9) {
        digit = [NSString stringWithFormat:@"%ld", (long)callDTMF];
    } else if (callDTMF == 10) {
        digit = @"*";
    } else if (callDTMF == 11) {
        digit = @"#";
    }

    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [eventData setObject:digit forKey:@"dtmf"];
    [self triggerEventForCall:stringeeCall withType:didReceiveDtmfDigit withData:eventData];

}

- (void)didReceiveCallInfo:(StringeeCall *)stringeeCall info:(NSDictionary *)info {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:info
                                            options:NSJSONWritingPrettyPrinted
                                            error:nil];
    NSString *jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@" " withString:@""];

    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [eventData setObject:jsonString forKey:@"data"];
    [self triggerEventForCall:stringeeCall withType:didReceiveCallInfo withData:eventData];
}

- (void)didHandleOnAnotherDevice:(StringeeCall *)stringeeCall signalingState:(SignalingState)signalingState reason:(NSString *)reason sipCode:(int)sipCode sipReason:(NSString *)sipReason {
    NSMutableDictionary* eventData = [[NSMutableDictionary alloc] init];
    [eventData setObject:stringeeCall.callId forKey:@"callId"];
    [eventData setObject:@(signalingState) forKey:@"code"];
    [eventData setObject:reason forKey:@"description"];
    [self triggerEventForCall:stringeeCall withType:didHandleOnAnotherDevice withData:eventData];
}

#pragma mark Helper

- (void)triggerJSEvent:(NSString*)event withType:(NSString*)type withData:(id)data {
    NSMutableDictionary* message = [[NSMutableDictionary alloc] init];
    [message setObject:type forKey:@"eventType"];
    if (data) {
        [message setObject:data forKey:@"data"];
    }
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
    [pluginResult setKeepCallbackAsBool:YES];

    NSString* callbackId = [callbackList objectForKey:event];

    if (!callbackId.length) {
        return;
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)triggerEventForCall:(StringeeCall *)stringeeCall withType:(NSString*)type withData:(id)data {
    // Tìm identifier của JSCall
    NSString *iden = [[callList allKeysForObject:stringeeCall] firstObject];
    
    if (!iden.length) {
        return;
    }

    [self triggerJSEvent: iden withType: type withData: data];
}

- (void)triggerCallbackWithStatus:(BOOL)status withData:(id)data withCallbackId:(NSString *)callbackId {
    CDVPluginResult *pluginResult;
    if (status) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:data];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:data];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)checkAndReleaseCall:(StringeeCall *)stringeeCall {
    if ([signalingEndList containsObject:stringeeCall.callId] && [mediaEndList containsObject:stringeeCall.callId]) {
        [signalingEndList removeObject:stringeeCall.callId];
        [mediaEndList removeObject:stringeeCall.callId];
        NSString *key = [[callList allKeysForObject:stringeeCall] firstObject];
        if (key) {
            [callbackList removeObjectForKey:key];
            [callList removeObjectForKey:key];
        }
    }
}





@end
