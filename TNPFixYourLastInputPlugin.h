/**
 * TNPFixYourLastInputPlugin
 * Regex substitution plugin for Adium
 *
 * Inspired by http://colloquy.info/extras/details.php?file=50.
 *
 * Originally By Henrik Nyh, 2007-04-19
 * Modified By Dustin Brewer, 2008-02-20
 *
 */

#import <Adium/AIPlugin.h>
#import <Adium/AISharedAdium.h>
#import <Cocoa/Cocoa.h>

@protocol AIContentFilter;

@interface TNPFixYourLastInputPlugin : AIPlugin <AIContentFilter> {
	NSMutableDictionary *lastOutgoingMessages;
	NSMenuItem			*toggleCorrectionMI;
	BOOL				enableCorrectionText;
}

@end
