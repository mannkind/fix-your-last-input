/**
 * TNPFixYourLastInputPlugin
 * Regex substitution plugin for Adium
 *
 * Inspired by http://colloquy.info/extras/details.php?file=50.
 *
 * Originally By Henrik Nyh (using Perl), 2007-04-19
 * Modified By Dustin Brewer (using Sed), 2008-02-20
 * Modified By Dustin Brewer (using ObjPCRE), 2010-04-24
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
