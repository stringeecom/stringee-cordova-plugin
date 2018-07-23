#import <Cordova/CDV.h>
#import <Stringee/Stringee.h>

@interface StringeePlugin : CDVPlugin <StringeeConnectionDelegate, StringeeIncomingCallDelegate, StringeeCallDelegate, StringeeRemoteViewDelegate>

// Common
- (void)addEvent:(CDVInvokedUrlCommand *)command;

// Client
- (void)initStringeeClient:(CDVInvokedUrlCommand *)command;
- (void)connect:(CDVInvokedUrlCommand *)command;
- (void)disconnect:(CDVInvokedUrlCommand *)command;
- (void)registerPush:(CDVInvokedUrlCommand *)command;
- (void)unregisterPush:(CDVInvokedUrlCommand *)command;

// Call
- (void)initStringeeCall:(CDVInvokedUrlCommand *)command;
- (void)makeCall:(CDVInvokedUrlCommand *)command;
- (void)initAnswer:(CDVInvokedUrlCommand *)command;
- (void)answer:(CDVInvokedUrlCommand *)command;

- (void)hangup:(CDVInvokedUrlCommand *)command;
- (void)reject:(CDVInvokedUrlCommand *)command;
- (void)sendDTMF:(CDVInvokedUrlCommand *)command;
- (void)sendCallInfo:(CDVInvokedUrlCommand *)command;
- (void)getCallStats:(CDVInvokedUrlCommand *)command;
- (void)mute:(CDVInvokedUrlCommand *)command;
- (void)setSpeakerphoneOn:(CDVInvokedUrlCommand *)command;
- (void)switchCamera:(CDVInvokedUrlCommand *)command;
- (void)enableVideo:(CDVInvokedUrlCommand *)command;

- (void)renderVideo:(CDVInvokedUrlCommand *)command;

@end