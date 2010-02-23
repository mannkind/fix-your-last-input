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

#import "TNPFixYourLastInputPlugin.h"
#import <Adium/AIAdiumProtocol.h>
#import <Adium/AIContentControllerProtocol.h>
#import <Adium/AIContentMessage.h>
#import <Adium/AIMenuControllerProtocol.h>
#import <Adium/AIPreferenceControllerProtocol.h>
#import <AIUtilities/AIMenuAdditions.h>
#import <AIUtilities/AIAttributedStringAdditions.h>
#import <AIUtilities/AIDictionaryAdditions.h>
#import <AIUtilities/AIStringUtilities.h>

@interface TNPFixYourLastInputPlugin (Private)
- (NSString *)replaceString:(NSString *)string withSubstitution:(NSString *)substitution;
- (NSString *)runReplacementOnString:(NSString *)string usingCommand:(NSString *)command;
- (NSString *)escapeShellCommand:(NSString *)string;
@end


@implementation TNPFixYourLastInputPlugin

- (NSString *)pluginAuthor {
	return @"Dustin Brewer";
}
- (NSString *)pluginURL {
    return @"http://www.dustinbrewer.name";
}
- (NSString *)pluginVersion {
	return @"2.3.2";
}
- (NSString *)pluginDescription {
	return @"Fix typos by writing regular expression substitutions like \"s/tyop/typo/g\". Sending a message comprising a substitution will output your previous message with this correction applied.";
}


- (void)installPlugin {
	NSLog(@"HNFixYourLastInputPlugin loaded!");
	[[adium contentController] registerContentFilter:self 
											  ofType:AIFilterContent 
										   direction:AIFilterOutgoing];

	lastOutgoingMessages = [[NSMutableDictionary alloc] init];
	enableCorrectionText = [[[adium preferenceController] preferenceForKey:@"enableCorrectionText" 
																	 group:@"HNFixYourLastInput"] boolValue];
		
	toggleCorrectionMI = [[NSMenuItem allocWithZone:[NSMenu menuZone]] initWithTitle:@"Show Regex Correction Text" 
																			  target:self
																			  action:@selector(toggleCorrection:) 
																	   keyEquivalent:@""];
	if (enableCorrectionText) {
		[toggleCorrectionMI setState:NSOnState];
	} else {
		[toggleCorrectionMI setState:NSOffState];
	}
	
	[[adium menuController] addMenuItem:toggleCorrectionMI toLocation:LOC_Edit_Additions];
}


- (void)uninstallPlugin {	
	[lastOutgoingMessages release];
	[toggleCorrectionMI release];
	
	[[adium contentController] unregisterContentFilter:self];
}

- (void)toggleCorrection:(id)sender {
	enableCorrectionText = enableCorrectionText ? NO : YES;
	
	[[adium preferenceController] setPreference:[NSNumber numberWithBool:enableCorrectionText]
										 forKey:@"enableCorrectionText" 
										  group:@"HNFixYourLastInput"];
	
	if (enableCorrectionText) {
		[toggleCorrectionMI setState:NSOnState];
	} else {
		[toggleCorrectionMI setState:NSOnState];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
	return YES;
}

- (NSAttributedString *)filterAttributedString:(NSAttributedString *)inAttributedString context:(id)context {
	BOOL isMessage = ([context isKindOfClass:[AIContentMessage class]] && 
        ![(AIContentMessage *)context isAutoreply]);
	
	// Bail unless it's a message
	if (!isMessage) { return inAttributedString; }

	id destination = [context destination];
	NSDate *date = [context date];
	NSString *messageString = [context messageString];

	// Bail if the message wasn't written just now
	// Casting from NSTimeInterval==double to int
	NSTimeInterval writtenSecondsAgo = [[NSDate date] timeIntervalSinceDate:date];

	if ((int)writtenSecondsAgo != 0) { return inAttributedString; }

	// Naive way of determining if it's a transform message
	BOOL isATransform = ([messageString hasPrefix:@"s/"] && 
		[[messageString componentsSeparatedByString:@"/"] count] > 3 &&
		[[messageString componentsSeparatedByString:@"\n"] count] == 1);
	
	NSString *lastMessageString = [lastOutgoingMessages valueForKey:[destination UID]];

	// Bail if last message wasn't a transform, or there is no history
	if (!isATransform || !lastMessageString) {
		[lastOutgoingMessages setValue:messageString forKey:[destination UID]];
		return inAttributedString;
	}
	
	NSString *transformedMessage = [self replaceString:lastMessageString withSubstitution:messageString];
	
	// Bail if an error occurred using the command
	if (transformedMessage == NO) { return inAttributedString; }
	
	// Set new message text
	NSString *newMessageRawText = [NSString stringWithFormat:AILocalizedString(@"Correction: %@", nil), transformedMessage];
	if (enableCorrectionText) { 
		newMessageRawText = [NSString stringWithFormat:AILocalizedString(@"Correction (%@): %@", nil), messageString, transformedMessage];	
	}
	
	NSDictionary *defaultFormatting = [[adium contentController] defaultFormattingAttributes];

	NSAttributedString *newMessageText = [[[NSAttributedString alloc] initWithString:newMessageRawText 
																		 attributes:defaultFormatting] autorelease];

	return newMessageText;
}


- (float)filterPriority {
	return DEFAULT_FILTER_PRIORITY;
}

- (NSString *)runReplacementOnString:(NSString *)string usingCommand:(NSString *)command {
	NSTask *task = [NSTask new];
	[task setLaunchPath:@"/bin/sh"];
	[task setArguments:[NSArray arrayWithObjects:@"-c", command, nil]];
	[task setStandardInput: [NSPipe pipe]]; 
	[task setStandardOutput:[NSPipe pipe]];
	[task setStandardError:[NSPipe pipe]];
	[task launch];
	
	NSFileHandle *writeHandle = [[task standardInput] fileHandleForWriting];
	[writeHandle writeData: [string dataUsingEncoding: NSUTF8StringEncoding]];
	[writeHandle closeFile];
	
	NSData *outputData = [[[task standardOutput] fileHandleForReading] readDataToEndOfFile];
	NSString *outputString = [[[NSString alloc] initWithData:outputData 
													encoding:NSUTF8StringEncoding] autorelease];
	
	// Trim string for comparison
	string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	outputString = [outputString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	NSData *errorData = [[[task standardError] fileHandleForReading] readDataToEndOfFile];
	
	NSString *errorString = [[NSString alloc] initWithData:errorData 
												  encoding:NSUTF8StringEncoding];

	[task release];
	
    // If errors
	if ([errorString length] > 0) {
		NSLog(@"Fix Your Last Input plugin error: %@", errorString);
		[errorString release];
		return NO;
	}
	
	[errorString release];
	
    // If nothing changed
	if ([outputString isEqualToString:string]) {
		return NO;
	}
	
	return outputString;	
}

// Applies substitution to string
- (NSString *)replaceString:(NSString *)string withSubstitution:(NSString*)substitution {
    string = [self escapeShellCommand:string];
    NSString *command = [[NSString alloc] initWithFormat:@"echo \"%@\" | sed -e '%@'", string, substitution];
	NSString *outputString = [self runReplacementOnString:string usingCommand:command];
	[command release];

    return outputString;
}

// Escaping characters for output to the shell... 
- (NSString *)escapeShellCommand:(NSString *)string {
	string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
	string = [string stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
	string = [string stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	string = [string stringByReplacingOccurrencesOfString:@"`" withString:@"\\`"];
	
	return string;
}


@end
