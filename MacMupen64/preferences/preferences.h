/*
 *  preferences.h
 *  mupen64plus
 *
 *  Created by Rovolo on 8/22/10.
 *  Copyright 2010 __MyCompanyName__. All rights reserved.
 *
 */
#import "m64p_types.h"

extern NSString * const MALDefaultOpenPanelDirectoryKey;
extern NSString * const MALDefaultROMExtensionsKey;

extern NSString * const MALDefaultROMFoldersKey;

extern NSString * const MALDefaultPluginPathsKey;
extern NSString * const MALDefaultPluginIconPathsKey;

//other strings
extern NSString * const MALApplicationName;
extern NSString * const MALDefaultKeyBindings;

extern NSURL * getApplicationSupportFolder(void);

// Plugin strings
extern NSString * const RSPString;
extern NSString * const VideoString;
extern NSString * const AudioString;
extern NSString * const InputString;
extern NSString * const CoreString;