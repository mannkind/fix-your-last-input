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
 - Localized "Correction"?
 - Fix smaller size in correction mess
 - Check memory management
 - Use a filter to _replace_ outgoing message? See Source/CBActionSupportPlugin.*
 - Escape issues?
 - Get rid of warnings
*/

#import "Slasher.h"
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>

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


//Content was sent or recieved
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
	AIAccount *account = [chat account];
	NSAttributedString *messageString = [message messageString];
	
	NSAttributedString *lastMessageString = [lastOutgoingMessages valueForKey:[destination UID]];
	
	// Bail unless it's outgoing
	if (![message isOutgoing]) return;

	// Bail if the message wasn't written now (is old)
	// Casting from NSTimeInterval==double to int
	int writtenSecondsAgo = [[NSDate date] timeIntervalSinceDate:[message date]];
	if (writtenSecondsAgo != 0) return;

	// Naive way of determining if it's a transform message
	BOOL isATransform = [messageString hasPrefix:@"s/"] && ([[messageString componentsSeparatedByString:@"/"] count] == 4) && ([[messageString componentsSeparatedByString:@"\n"] count] == 1);

	if (isATransform && lastMessageString) {
		
		NSString *perlOneLiner = [[@"($s=<>)=~" stringByAppendingString:messageString] stringByAppendingString:@"; print $s;"];
		
		NSTask *task = [NSTask new];
		[task setLaunchPath:@"/usr/bin/perl"];
		[task setArguments:[NSArray arrayWithObjects:@"-e", perlOneLiner, nil]];
		[task setStandardInput: [NSPipe pipe]];  	
		[task setStandardOutput:[NSPipe pipe]];
		[task launch];
	
		NSFileHandle *writeHandle = [[task standardInput] fileHandleForWriting];
	
		// Pipe in last message
		[writeHandle writeData: [lastMessageString dataUsingEncoding: NSUTF8StringEncoding]];
		[writeHandle closeFile];
	
		NSData* output = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
		NSString* transformedMessage = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
		[task release];
		
		// An error occurred - so bail
		if ([transformedMessage length] == 0) {
			[transformedMessage release];
			return;
		}
	
		NSAttributedString *newMessageText = [[NSAttributedString alloc] initWithString:[@"Correction: " stringByAppendingString:transformedMessage]];

		[transformedMessage release];

		AIContentMessage *newMessage = [[AIContentMessage alloc] initWithChat:chat source:source destination:destination date:[NSDate date] message:newMessageText];


		// Send message
		BOOL success = [[adium contentController] sendContentObject:newMessage];

		// Display an error message if the message was not delivered
		if (!success) {
			[[adium interfaceController] handleMessage:AILocalizedString(@"Contact Alert Error", nil)
										withDescription:[NSString stringWithFormat:AILocalizedString(@"Unable to send message to %@.", nil), [destination displayName]]
										withWindowTitle:@""];
		} else {
			// Delivered correction
			correctionComing = YES;
		}
	
		// Uncomment to crash :p
		//	[newMessageText release];

		[newMessage release];

		
	} else {  // Conditional to avoid loops
		[lastOutgoingMessages setValue:[message messageString] forKey:[destination UID]];
	}
}


@end
