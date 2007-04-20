//
//  Slasher.m
//  Slasher
//
//  Created by Henrik Nyh on 2007-04-19.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

/* TODO:
 - Tidywork
 - Åäö problems with Björn
 - Don't repeat "Correction:" when re-correcting (Don't log corrections)
 - Localized "Correction"?
 - Fix smaller size in correction mess
 - Check memory management
*/

#import "Slasher.h"
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>

@implementation Slasher

- (void)installPlugin {
	NSLog(@"Hello");
	lastOutgoing = [[NSMutableDictionary alloc] init];
	[[adium notificationCenter] addObserver:self selector:@selector(adiumSentOrReceivedContent:) name:Content_ContentObjectAdded object:nil];
}

- (void)uninstallPlugin {
	NSLog(@"Goodbye");
	[lastOutgoing release];
	[[adium notificationCenter] removeObserver:self name:Content_ContentObjectAdded object:nil];
}


//Content was sent or recieved
- (void)adiumSentOrReceivedContent:(NSNotification *)notification {
	
	AIContentMessage *content = [[notification userInfo] objectForKey:@"AIContentObject"];

  // Bail unless it's a message
  if (![[content type] isEqualToString:CONTENT_MESSAGE_TYPE] && ![content postProcessContent]) return;

	AIChat          *chat = [notification object];
	AIListObject    *source = [content source];
	AIListObject    *destination = [content destination];
	AIAccount       *account = [chat account];
	NSAttributedString *message = [content messageString];
	
	NSAttributedString *lastMessage = [lastOutgoing valueForKey:[destination UID]];
	
	// Bail unless it's outgoing
	if (![content isOutgoing]) return;

	// Bail if the message wasn't written now (is old)
	// Cast from NSTimeInterval==double
	int writtenSecondsAgo = [[NSDate date] timeIntervalSinceDate:[content date]];
	NSLog(@"Written seconds ago: %d", writtenSecondsAgo);
	if (writtenSecondsAgo != 0) return;
	
	NSLog(@"Dest UID: %@", [destination UID]);
	NSLog(@"Message: %@", message);
	
	// Hash by sender?
	if (lastOutgoing)
		NSLog(@"Last message: %@", lastOutgoing);
		
	BOOL isATransform = [message hasPrefix:@"s/"] && ([[message componentsSeparatedByString:@"/"] count] == 4) && ([[message componentsSeparatedByString:@"\n"] count] == 1);
	NSLog(@"Is a transform? %d", isATransform);
	

	if (isATransform && lastMessage) {
		NSLog(@"Transform ''%@'' by %@", lastMessage, message);
		
	NSString *perlOneLiner = [[@"($s=<>)=~" stringByAppendingString:message] stringByAppendingString:@"; print $s;"];
		
     NSTask *task = [NSTask new];
    [task setLaunchPath:@"/usr/bin/perl"];
    [task setArguments:[NSArray arrayWithObjects:@"-e", perlOneLiner, nil]];
	[task setStandardInput: [NSPipe pipe]];  	
    [task setStandardOutput:[NSPipe pipe]];
    [task setStandardError:[task standardOutput]];
    [task launch];
	
    NSFileHandle *writeHandle = [[task standardInput] fileHandleForWriting];
	
	// Pipe in last message
    [writeHandle writeData: [lastMessage dataUsingEncoding: NSUTF8StringEncoding]];
    [writeHandle closeFile];
	
    NSData* output = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
    NSString* transformedMessage = [[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding] autorelease];
	[task release];
		
	NSAttributedString *newMessageText = [[NSAttributedString alloc] initWithString:[@"Correction: " stringByAppendingString:transformedMessage]];
	// Uncomment to crash :p
	// TODO: Figure out what to collect
//	[transformedMessage release];

		AIContentMessage *newMessage = [[AIContentMessage alloc] initWithChat:chat source:source destination:destination date:[NSDate date] message:newMessageText];
	[[adium contentController] sendContentObject:newMessage];
	
	// Uncomment to crash :p
	//	[newMessageText release];

	[newMessage release];

		
	} else {  // Conditional to avoid loops
		[lastOutgoing setValue:[content messageString] forKey:[destination UID]];
	}
}


@end
