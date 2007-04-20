//
//  Slasher.m
//  Perl regexp substitution plugin for Adium IM
//
//  Created by Henrik Nyh on 2007-04-19.
//  Free to modify and redistribute with due credit.
//

// Inspired by http://colloquy.info/extras/details.php?file=50.

/* TODO:
 - Encoding problems? E.g. Swedish åäö aren't handled well.
 - Handle command injection? Probably not.
*/

#import "Slasher.h"
#import <Adium/AIAdiumProtocol.h>
#import <Adium/AIInterfaceControllerProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <AIUtilities/AIStringUtilities.h>


@interface Slasher (Private)
- (NSString *)string: (NSString *)string withSubstitution:(NSString*)substitution;
@end


@implementation Slasher


- (NSString *)pluginAuthor {
	return @"Henrik Nyh";
}
- (NSString *)pluginURL {
	return @"http://henrik.nyh.se/";
}
- (NSString *)pluginVersion {
	return @"1.0";
}
- (NSString *)pluginDescription {
	return @"Messages like \"s/foo/bar/g\" cause your previous message to be passed through that substitution and resent. Perl syntax.";
}


- (void)installPlugin {

	NSLog(@"Slasher plugin loaded!");

	lastOutgoingMessages = [[NSMutableDictionary alloc] init];

	[[adium contentController] registerContentFilter:self ofType:AIFilterContent direction:AIFilterOutgoing];
}


- (void)uninstallPlugin {

	[lastOutgoingMessages release];

	[[adium contentController] unregisterContentFilter:self];
}


- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context {

	BOOL isMessage = ([context isKindOfClass:[AIContentMessage class]] && ![(AIContentMessage *)context isAutoreply]);
	
	// Bail unless it's a message
	if (!isMessage)
		return inAttributedString;

	id destination = [context destination];
	NSDate *date = [context date];
	NSString *messageString = [context messageString];

	// Bail if the message wasn't written just now
	// Casting from NSTimeInterval==double to int
	NSTimeInterval writtenSecondsAgo = [[NSDate date] timeIntervalSinceDate:date];
	if ((int)writtenSecondsAgo != 0)
		return inAttributedString;

	// Naive way of determining if it's a transform message
	BOOL isATransform = [messageString hasPrefix:@"s/"] && ([[messageString componentsSeparatedByString:@"/"] count] == 4) && ([[messageString componentsSeparatedByString:@"\n"] count] == 1);
	
	NSString *lastMessageString = [lastOutgoingMessages valueForKey:[destination UID]];

	// Bail if last message wasn't a transform, or there is no history
	if (!isATransform || !lastMessageString) {
		[lastOutgoingMessages setValue:messageString forKey:[destination UID]];
		return inAttributedString;
	}
	
	NSString *transformedMessage = [self string:lastMessageString withSubstitution:messageString];
	
	// Bail if an error occurred in Perl
	if ([transformedMessage length] == 0)
		return inAttributedString;
	
	// Set new message text
	NSString *newMessageRawText = [NSString stringWithFormat:AILocalizedString(@"Correction (%@): %@", nil), messageString, transformedMessage];
	NSDictionary *defaultFormatting = [[adium contentController] defaultFormattingAttributes];
	NSAttributedString *newMessageText = [[NSAttributedString alloc] initWithString:newMessageRawText attributes:defaultFormatting];

	return newMessageText;
}


- (float)filterPriority {
	return DEFAULT_FILTER_PRIORITY;
}


// Applies substitution to string
- (NSString *)string: (NSString *)string withSubstitution:(NSString*)substitution {

	NSString *perlOneLiner = [[@"use utf8; binmode STDIN, ':utf8'; binmode STDOUT, ':utf8'; ($s=<>)=~" stringByAppendingString:substitution] stringByAppendingString:@"; print $s;"];
	
	NSTask *task = [NSTask new];
	[task setLaunchPath:@"/usr/bin/perl"];
	[task setArguments:[NSArray arrayWithObjects:@"-e", perlOneLiner, nil]];
	[task setStandardInput: [NSPipe pipe]]; 
	[task setStandardOutput:[NSPipe pipe]];
	[task launch];
	
	NSFileHandle *writeHandle = [[task standardInput] fileHandleForWriting];
	[writeHandle writeData: [string dataUsingEncoding: NSUTF8StringEncoding]];
	[writeHandle closeFile];
	
	NSData* outputData = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSString* outputString = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
	[task release];
		
	return [outputString autorelease];
}


@end
