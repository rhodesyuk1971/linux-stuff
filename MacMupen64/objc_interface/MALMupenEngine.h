//
//  MALMupenPlugins.h
//  mupen
//
//  Created by Rovolo on 8/24/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MALGameWindow.h"

extern NSString * MALMupenEngineStarted;
extern NSString * MALMupenEngineFinished;

@class MALMupenRom,MALMupenCore;
@interface MALMupenEngine : NSObject <MALGameWindowEventDelegate,NSWindowDelegate> {
	NSMutableArray * plugins;
	NSWindowController * gameWindow;
	NSUInteger modFlags;
	BOOL isRunning, muted;
	int volume;
}
@property (readwrite, retain) NSMutableArray * plugins;
@property (readonly) MALMupenCore * core;
@property (readonly) BOOL isRunning;
@property (readwrite, retain) MALMupenRom * mainROM;
@property (readonly) NSArray * controllerBindings;

@property (readwrite) BOOL muted;
@property (readwrite) int volume;

-(void) runWithRom:(MALMupenRom*)rom;
-(void) takeScreenShot;
+(MALMupenEngine*) shared;
@end
