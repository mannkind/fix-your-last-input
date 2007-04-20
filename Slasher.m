//
//  Slasher.m
//  Slasher substitution plugin for Adium IM
//
//  Created by Henrik Nyh on 2007-04-19.
//  Free to modify and redistribute with due credit.
//

/* TODO:
 - Tidywork
 - Åäö problems with Björn
 - Fix smaller size in correction mess
 - Use a filter to _replace_ outgoing message? See Source/CBActionSupportPlugin.*
 - Any escape issues?
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


- (void)installPlugin {

	NSLog(@"Slasher plugin loaded!");

	lastOutgoingMessages = [[NSMutableDictionary alloc] init];
	correctionComing = NO;

	[[adium notificationCenter] addObserver:self selector:@selector(adiumSentOrReceivedContent:) name:Content_ContentObjectAdded object:nil];
}


- (void)uninstallPlugin {

	[lastOutgoingMessages release];

	[[adium notificationCenter] removeObserver:self name:Content_ContentObjectAdded object:nil];
}



// Content was sent or recieved
- (void)adiumSentOrReceivedContent:(NSNotification *)notification {

	// Bail if the message is a correction
	if (correctionComing) {
		correctionComing = NO;
		return;
	}
	
	AIContentMessage *message = [[notification userInfo] objectForKey:@"AIContentObject"];

	// Bail unless it's a message
	if (![[message type] isEqualToString:CONTENT_MESSAGE_TYPE] && ![message postProcessContent]) return;

	AIChat *chat = [notification object];
	AIListObject *source = [message source];
	AIListObject *destination = [message destination];
	NSString *messageString = [message messageString];
	
	// Bail unless it's outgoing
	if (![message isOutgoing]) return;

	// Bail if the message wasn't written just now
	// Casting from NSTimeInterval==double to int
	NSTimeInterval writtenSecondsAgo = [[NSDate date] timeIntervalSinceDate:[message date]];
	if ((int)writtenSecondsAgo != 0) return;

	// Naive way of determining if it's a transform message
	BOOL isATransform = [messageString hasPrefix:@"s/"] && ([[messageString componentsSeparatedByString:@"/"] count] == 4) && ([[messageString componentsSeparatedByString:@"\n"] count] == 1);
	
	NSString *lastMessageString = [lastOutgoingMessages valueForKey:[destination UID]];

	// Bail if last message wasn't a transform, or there is no history
	if (!isATransform || !lastMessageString) {
		[lastOutgoingMessages setValue:[message messageString] forKey:[destination UID]];
		return;
	}
	
	NSString *transformedMessage = [self string:lastMessageString withSubstitution:messageString];
	
	// Bail if an error occurred in Perl
	if ([transformedMessage length] == 0) {
	
		[[adium interfaceController] handleMessage:AILocalizedString(@"Invalid Substitution Error", nil)
									withDescription:AILocalizedString(@"Perl threw a syntax error. You probably mistyped something.", nil) 
									withWindowTitle:@""];
		return;
	}
	
	// Compose new message
	
	// Set text
	NSAttributedString *newMessageText = [[NSAttributedString alloc] initWithString:[AILocalizedString(@"Correction: ", nil) stringByAppendingString:transformedMessage]];

	// Create message proper
	AIContentMessage *newMessage = [[AIContentMessage alloc] initWithChat:chat source:source destination:destination date:[NSDate date] message:newMessageText];
	[newMessageText release];

	// Send message
	BOOL success = [[adium contentController] sendContentObject:newMessage];
	[newMessage release];

	// Display an error message if the message was not delivered
	if (!success) {
		[[adium interfaceController] handleMessage:AILocalizedString(@"Contact Alert Error", nil)
									withDescription:[NSString stringWithFormat:AILocalizedString(@"Unable to send message to %@.", nil), [destination displayName]]
									withWindowTitle:@""];
	} else {
		// We delivered a correction
		correctionComing = YES;  // Let's not track it in our substitution history
	}

}

// Applies s/// substitution to string
- (NSString *)string: (NSString *)string withSubstitution:(NSString*)substitution {

	NSString *perlOneLiner = [[@"($s=<>)=~" stringByAppendingString:substitution] stringByAppendingString:@"; print $s;"];
	
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
