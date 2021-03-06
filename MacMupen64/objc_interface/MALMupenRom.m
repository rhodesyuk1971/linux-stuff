//
//  MALMupenRom.m
//  mupen
//
//  Created by Rovolo on 8/25/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MALMupenRom.h"
#import "MALMupenCore.h"
#import "MALBackporting.h"
#import "MALAdditions.h"
#import "preferences.h"
#import "core_interface.h"
#import "cheat.h"

#import <sys/xattr.h>

NSString * const MALMupenRomNewROMOpened = @"MALMupenRom New ROM Loaded";

const char * const xattrMupenVersionKey = "Mupen64plus version";
const char * const xattrINIVersionKey = "Mupen64plus ini version";
const char * const xattrROMInfoKey = "Mupen64plus ROM Info";
const char * const xattrLastOpened = "Mupen64plus last opened";

NSImage * MALDefaultRomImage = nil;
NSMutableArray * recentlyOpenedROMS = nil;
NSMutableDictionary * romLists = nil;

static void fixSwap(m64p_rom_header * header) {
	int loadlength=sizeof(m64p_rom_header);
	char firstByte = header->init_PI_BSB_DOM1_LAT_REG;
	unsigned char * bytes = (unsigned char*)header;
	char temp;
	// Btyeswap if .v64 image.
	if(firstByte==0x37) {
		for (int i = 0; i < loadlength; i+=2) {
			temp=bytes[i];
			bytes[i]=bytes[i+1];
			bytes[i+1]=temp;
		}
	}
	// Wordswap if .n64 image. 
	else if(firstByte==0x40) {
		for (int i = 0; i < loadlength; i+=4) {
			temp=bytes[i];
			bytes[i]=bytes[1+3];
			bytes[i+3]=temp;
			temp=bytes[i+1];
			bytes[i+1]=bytes[i+2];
			bytes[i+2]=temp;
		}
	} //else is .z64
}
@implementation MALMupenRom
#pragma mark Accessors and Setters

@synthesize gameTitle,MD5,status,players,rumble,netplay,formattedInfo,path,isUsable,image,lastOpened;

-(NSDate*) lastOpened {
	return lastOpened;
}
-(void) setLastOpened:(NSDate *)lo {
	NSFileHandle * fh = [NSFileHandle fileHandleForReadingAtPath:[path relativePath]];
	NSTimeInterval ti = [lo timeIntervalSince1970];
	
	fsetxattr([fh fileDescriptor], xattrLastOpened, &ti, sizeof(ti), 0, 0);
	
	[self willChangeValueForKey:@"lastOpened"];
	[lo retain];
	[lastOpened release];
	lastOpened = lo;
	[self didChangeValueForKey:@"lastOpened"];
}

-(NSURL*) freezesPath {
	NSURL * folder = [MALFreezesFolder URLByAppendingPathComponent:self.gameTitle];
	
	NSString * folderPath = [folder relativePath];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ( ![fileManager fileExistsAtPath:folderPath] ) {
		[fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	return folder;
}

-(NSData*) contents {
	if(contents==nil) {
		NSFileHandle * fh = [NSFileHandle fileHandleForReadingAtPath:[path relativePath]];
		//[NSFileHandle fileHandleForReadingFromURL:path error:&error];  // 10.6+
		contents=[[fh readDataToEndOfFile] retain];
		[fh closeFile];
	}
	[self willChangeValueForKey:@"lastOpened"];
	if(recentlyOpenedROMS==nil) recentlyOpenedROMS=[[NSMutableArray alloc] init];
	if(lastOpened==nil) {
		[recentlyOpenedROMS addObject:self];
		[[NSNotificationCenter defaultCenter] postNotificationName:MALMupenRomNewROMOpened object:self];
	}
	self.lastOpened = [[NSDate date] retain];
	[NSKeyedArchiver archiveRootObject:recentlyOpenedROMS toFile:[MALRecentlyOpenedRomsFile relativePath]];
	[self didChangeValueForKey:@"lastOpened"];
	return contents;
}

#pragma mark Initializers and Creators
+(void) initialize {
	if(MALDefaultRomImage==nil) MALDefaultRomImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"mupen64plus_rom" ofType:@"icns"]];
	if(romLists==nil) romLists = [[NSMutableDictionary alloc] init];
}

-(id) initWithURL:(NSURL*)url {
	if(self = [super init]) {
		NSFileHandle * fh = [NSFileHandle fileHandleForReadingAtPath:[url relativePath]];
		if (!fh) {[self release]; return nil;}
		
		// get the header
		m64p_rom_header header;
		[[fh readDataOfLength:sizeof(header)] getBytes:&header length:sizeof(header)];
		fixSwap(&header);
		
		// use header to get the better info
		m64p_rom_settings settings;
		BOOL gotSettings=NO;
		if(fgetxattr([fh fileDescriptor], xattrROMInfoKey, &settings, sizeof(settings), 0, 0) != -1) {
			gotSettings=YES;
		} else if (CoreGetRomSettings!=nil && (*CoreGetRomSettings)(&settings,sizeof(settings),sl(header.CRC1),sl(header.CRC2)) == M64ERR_SUCCESS) {
			gotSettings=YES;
			int fd = [fh fileDescriptor];
			fsetxattr(fd, xattrROMInfoKey, &settings, sizeof(settings), 0, 0);
			NSString * version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
			fsetxattr(fd, xattrMupenVersionKey, [version UTF8String] , 16, 0, 0);
		}
		// set all the attributes
		if(gotSettings) {
			[self setGameTitle:[NSString stringWithUTF8String:settings.goodname]];
			[self setMD5:[NSString stringWithUTF8String:settings.MD5]];
			[self setStatus:settings.status];
			[self setPlayers:(settings.players > 4 ? settings.players - 3 : settings.players)];
			[self setNetplay:settings.players > 4];
			[self setRumble:settings.rumble];
			
			NSMutableAttributedString * info = [[NSMutableAttributedString alloc] init];
			[info addBoldString:gameTitle]; [info addReturn];
			//[info addSmallString:MD5]; 
			[info addReturn];
			[info addRegularString:[NSString stringWithFormat:@"Players: %i   Reliability: %i/5\n",players,status]];
			if(netplay) [info addRegularString:@"Netplay   "];
			if(rumble)  [info addRegularString:@"Rumble"];
			[self setFormattedInfo:info];
			[info release];
		} else {
			[self setGameTitle:[NSString stringWithUTF8String:(char const *)header.Name]];
			[self setMD5:nil];
			[self setPath:nil];
			[self setFormattedInfo:[[[NSAttributedString alloc] initWithString:gameTitle] autorelease]];
		}
		NSTimeInterval ti;
		if(fgetxattr([fh fileDescriptor], xattrLastOpened, &ti, sizeof(ti), 0, 0) != -1) {
			lastOpened = [[NSDate alloc] initWithTimeIntervalSince1970:ti];
		}
		
		[self setPath:url];
		[self setIsUsable:YES];
		
		[self setImage:MALDefaultRomImage];
		[romLists setObject:self forKey:[url relativePath]];
		[fh closeFile];
	}
	return self;
}
-(id) initWithPath:(NSString*)romPath {
	return [self initWithURL:[NSURL fileURLWithPath:romPath]];
}
+(MALMupenRom*) mupenROMAtPath:(NSString*)rompath {
	return [self mupenROMAtURL:[NSURL fileURLWithPath:rompath]];
}
+(MALMupenRom*) mupenROMAtURL:(NSURL*)url {
	MALMupenRom * retVal=nil;
	retVal = [romLists objectForKey:[url relativePath]];
	if(retVal!=nil) {
		return retVal;
	}
	retVal = [[[self alloc] initWithURL:url] autorelease];
	return retVal;
}
-(NSUInteger) hash {
	NSUInteger result = [[[self MD5] substringToIndex:sizeof(NSUInteger)*2] hexIntegerValue];
	return result;
}
-(BOOL) isEqual:(id)object {
	if([object isKindOfClass:[self class]] && [[object MD5] isEqual:MD5]) return YES;
	else return NO;
}
#pragma mark recently opened roms
+(NSArray*) recentlyOpenedROMs {
	if(recentlyOpenedROMS==nil) {
		NSURL * appFolder = MALRecentlyOpenedRomsFile;
		NSArray * array = nil;
		if([[NSFileManager defaultManager] fileExistsAtPath:[appFolder relativePath]]) {
//			id a = [appFolder relativePath];
//				array = [NSKeyedUnarchiver unarchiveObjectWithFile:a];
			// MAKE THIS A FLAT FILE
		}
		recentlyOpenedROMS = [[NSMutableArray arrayWithArray:array] retain];
	}
	return recentlyOpenedROMS;
}

#pragma mark NSCoding

- (void)encodeWithCoder:(NSCoder*)encoder {
	[encoder encodeObject:[path absoluteString] forKey:@"path"];
	[encoder encodeObject:lastOpened forKey:@"last opened"];
}
- (id)initWithCoder:(NSCoder*)decoder {
	self = [self initWithURL:[NSURL URLWithString:[decoder decodeObjectForKey:@"path"]]];
	lastOpened = [[decoder decodeObjectForKey:@"last opened"] retain];
	return self;
}

@end