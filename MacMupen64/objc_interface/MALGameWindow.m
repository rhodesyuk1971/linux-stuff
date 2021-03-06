//
//  MALEmulationScreen.m
//  mupen
//
//  Created by Rovolo on 8/30/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MALGameWindow.h"
#import <OpenGL/OpenGL.h>
#import "MALAdditions.h"
#import "MALMupenEngine.h"

static void drawGlRect() {
	glBegin(GL_QUADS);
	glTexCoord2f(0, 0); glVertex3f(0, 0, 0);
	glTexCoord2f(0, 1); glVertex3f(0, 1, 0);
	glTexCoord2f(1, 1); glVertex3f(1, 1, 0);
	glTexCoord2f(1, 0); glVertex3f(1, 0, 0);
	glEnd();
}
static void drawAnObject ()
{
    glColor3f(1.0f, 0.85f, 0.35f);
    glBegin(GL_TRIANGLES);
    {
        glVertex3f(  0.0,  0.6, 0.0);
        glVertex3f( -0.2, -0.3, 0.0);
        glVertex3f(  0.2, -0.3, 0.0);
    }
    glEnd();
}

#define REPORTGLERROR() { GLenum tGLErr; while((tGLErr = glGetError()) != GL_NO_ERROR) { printf("OpenGL error %d : %s\n",tGLErr, __PRETTY_FUNCTION__); } }

#define splitSize(size) size.width, size.height
#define splitPoint(point) point.x, point.y
#define splitRect(rect) splitPoint(rect.origin), splitSize(rect.size)

@implementation MALGameWindow
@synthesize engine,oldTitle;
-(NSOpenGLView*) openGLview {return openGLview;}
-(void) setOpenGLview:(NSOpenGLView *)glview {
	[glview retain];
	[openGLview release];
	openGLview = glview;
	
	// Let's us shrink the size of NSOpenGLView in fullscreen
	NSView * backingView = [[NSView alloc] init];
	[self setContentView:backingView];
	[backingView release];
	[backingView addSubview:openGLview];
	[openGLview setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[openGLview setFrame:backingView.frame];
}

+(NSWindowController*) gameWindow {
	NSWindowController * wc = [[NSWindowController alloc] initWithWindowNibName:@"GameWindow"];
	MALGameWindow * emu = (MALGameWindow*)[wc window];
	[emu setBackgroundColor:[NSColor blackColor]];
	[emu setDelegate:emu];
	return [wc autorelease];
}

-(NSSize) expandSize:(NSSize)size toAspectRatio:(NSSize)ratio {
	return NSMakeSize(MAX(size.width ,size.height * ( ratio.width/ratio.height)),
					  MAX(size.height,size.width  * (ratio.height/ ratio.width)));
}
-(NSSize) shrinkSize:(NSSize)size toAspectRatio:(NSSize)ratio {
	return NSMakeSize(MIN(size.width ,size.height * ( ratio.width/ratio.height)),
					  MIN(size.height,size.width  * (ratio.height/ ratio.width)));
}

-(void) setFramebufferSize:(NSSize)size attributes:(NSArray*)pixelAttributes {
	if(![NSThread isMainThread]) {
		NSInvocation * invocation;
		[[NSInvocation invocationWithTarget:self invocationOut:&invocation] setFramebufferSize:size attributes:pixelAttributes];
		[invocation performSelectorOnMainThread:@selector(invoke) withObject:nil waitUntilDone:YES];
		
		[offscreenGLview.openGLContext makeCurrentContext];
		return;
	}
	
	NSOpenGLPixelFormat * onscreenPixFormat = [NSOpenGLPixelFormat pixelFormatFromArrayOfAttributes:pixelAttributes],
	*offscreenPixFormat = [NSOpenGLPixelFormat pixelFormatFromArrayOfAttributes:[pixelAttributes arrayByAddingObject:@(NSOpenGLPFAOffScreen)]];
	
	[self setContentSize:size];
	self.openGLview = [[NSOpenGLView alloc] initWithFrame:self.frame pixelFormat:onscreenPixFormat];
	
	[openGLview.openGLContext makeCurrentContext];
	
	glClearColor(0, 0, 0, 0);
	glGenTextures(1, &renderTexture);
	glBindTexture(GL_TEXTURE_2D, renderTexture);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri (GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL);
	
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, size.width, size.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0.0, 1, 0.0, 1, -1.0, 1.0);
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glEnable(GL_TEXTURE_2D);
	glViewport(0,0, splitSize(size));
	
	GLint dim[2] = {size.width, size.height};
	// ctx must be a valid context
	void *ctx =[openGLview.openGLContext CGLContextObj];
	CGLSetParameter(ctx, kCGLCPSurfaceBackingSize, dim);
	CGLEnable (ctx, kCGLCESurfaceBackingSize);
	
	// Setup offscreen buffer
	NSRect frame = NSMakeRect(100, 100, splitSize(size));
	hiddenWindow  = [[NSWindow alloc] initWithContentRect:frame
												styleMask:NSBorderlessWindowMask
												  backing:NSBackingStoreBuffered
													defer:NO];
	
	offscreenGLview = [[NSOpenGLView alloc] initWithFrame:hiddenWindow.frame pixelFormat:offscreenPixFormat];
	[hiddenWindow setContentView:offscreenGLview];
	offscreenBuffer = malloc(sizeof(GLubyte) * size.width * size.height * 3);
}

-(void) close {
	[super close];
}
-(void) drawOpenglWindow {
	[openGLview.openGLContext makeCurrentContext];
	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	
	glColor3f(1, 1, 1);
	glBegin(GL_QUADS);
	glTexCoord2f(0, 0); glVertex3f(0, 0, 0);
	glTexCoord2f(0, 1); glVertex3f(0, 1, 0);
	glTexCoord2f(1, 1); glVertex3f(1, 1, 0);
	glTexCoord2f(1, 0); glVertex3f(1, 0, 0);
	glEnd();
	
	glFlush();
#define REPORTGLERROR() { GLenum tGLErr; while((tGLErr = glGetError()) != GL_NO_ERROR) { printf("OpenGL error %d : %s\n",tGLErr, __PRETTY_FUNCTION__); } }
	
	REPORTGLERROR();
	[openGLview.openGLContext flushBuffer];
}

-(void) drawFramebuffer {
	[offscreenGLview.openGLContext flushBuffer];
	
	// read from the offscreen buffer
	NSSize texSize = hiddenWindow.frame.size;
	glReadPixels(0, 0, splitSize(texSize), GL_RGB, GL_UNSIGNED_BYTE, offscreenBuffer);
	
	[openGLview.openGLContext makeCurrentContext];
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, splitSize(texSize), 0, GL_RGB, GL_UNSIGNED_BYTE, offscreenBuffer);
	
	// Can interfere with driver initializing the view on the main thread, so put in queue
	[self performSelectorOnMainThread:@selector(drawOpenglWindow) withObject:nil waitUntilDone:YES];
	
	[offscreenGLview.openGLContext makeCurrentContext];
}

-(void) setFullscreen:(BOOL)fullscreen {
	NSSize emuSize = offscreenGLview.frame.size;
	if (fullscreen) {
		oldLevel = self.level;
		oldFrame = self.frame;
		self.oldTitle = self.title;
		[self setStyleMask:NSBorderlessWindowMask];
		[self setLevel:NSMainMenuWindowLevel+1];
		[self setHidesOnDeactivate:YES];
		[self setFrame:[[NSScreen mainScreen] frame] display:YES animate:NO];
		
		NSSize newViewport = shrinkSizeToAspectRatio(self.frame.size, emuSize);
		NSSize fullSize = self.frame.size;
		[openGLview setFrameOrigin:NSMakePoint((fullSize.width - newViewport.width)/2, (fullSize.height - newViewport.height)/2)];
		[openGLview setFrameSize:newViewport];
	} else {
		[openGLview setFrame:self.frame];
		
		
		[self setStyleMask:NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask | NSMiniaturizableWindowMask];
		[self setTitle:self.oldTitle];
		[self setFrame:oldFrame display:YES animate:NO];
		[self setLevel:oldLevel];
		[self setHidesOnDeactivate:NO];
	}
	
	glViewport(0,0, splitSize(emuSize));
	
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	glOrtho(0.0, 1, 0.0, 1, -1.0, 1.0);

}

#pragma mark <NSWindowDelegate>
-(BOOL) windowShouldClose:(id)sender {
	if(engine.isRunning) {
		[engine stopEmulation];
		return NO;
	} else {
		return YES;
	}
}
-(NSSize) windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
	frameSize = expandSizeToAspectRatio(frameSize, hiddenWindow.frame.size);
	engine.videoSize = frameSize;
	return frameSize;
}
-(void) windowDidResignMain:(NSNotification *)notification {
	
}
-(void) windowDidResignKey:(NSNotification *)notification {
	[engine pauseEmulation];
}
-(void) windowDidBecomeKey:(NSNotification *)notification {
	[engine resumeEmulation];
}
-(void) windowWillClose:(NSNotification *)notification {
	[hiddenWindow close];
}
@end

