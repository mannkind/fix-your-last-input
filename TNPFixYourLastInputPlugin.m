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
#import "objpcre.h"

@implementation TNPFixYourLastInputPlugin

- (NSString *)pluginAuthor {
	return @"Dustin Brewer";
}
- (NSString *)pluginURL {
    return @"http://www.thenullpointer.net";
}
- (NSString *)pluginVersion {
	return @"2.4";
}
- (NSString *)pluginDescription {
	return @"Fix typos by writing regular expression substitutions like \"s/tyop/typo/g\". Sending a message comprising a substitution will output your previous message with this correction applied.";
}


- (void)installPlugin {
	NSLog(@"TNPFixYourLastInputPlugin loaded!");
	[[adium contentController] registerContentFilter:self 
											  ofType:AIFilterContent 
										   direction:AIFilterOutgoing];

	lastOutgoingMessages = [[NSMutableDictionary alloc] init];
	enableCorrectionText = [[[adium preferenceController] preferenceForKey:@"enableCorrectionText" 
																	 group:@"TNPFixYourLastInput"] boolValue];
		
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
										  group:@"TNPFixYourLastInput"];
	
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
	// Determine if the string is a real message
	BOOL isMessage = [context isKindOfClass:[AIContentMessage class]] && ![(AIContentMessage *)context isAutoreply];
	
	// Bail unless it's a message
	if (!isMessage) { 
		return inAttributedString; 
	}

	id destination = [context destination];
	NSString *messageString = [context messageString];

	// Bail if the message wasn't written just now
	// Casting from NSTimeInterval==double to int
	if ((int)[[NSDate date] timeIntervalSinceDate:[context date]] != 0) { 
		return inAttributedString; 
	}

	ObjPCRE *searchReplacePattern = [ObjPCRE regexWithPattern:@"s/(.*)/(.*)/([ig]+)?"];
	BOOL isATransform = [searchReplacePattern matches:messageString];
	NSString *lastMessageString = [lastOutgoingMessages valueForKey:[destination UID]];
	
	// Bail if last message wasn't a transform, or there is no history
	if (!isATransform || !lastMessageString) {
		[lastOutgoingMessages setValue:messageString 
								forKey:[destination UID]];
		
		return inAttributedString;
	}
	
	NSString *pattern = [searchReplacePattern match:messageString atMatchIndex:1];
	NSString *replacement = [searchReplacePattern match:messageString atMatchIndex:2];
	NSString *opts = @"";
	if ([searchReplacePattern matchCount] == 4) {
		opts = [searchReplacePattern match:messageString atMatchIndex:3];
	}
	NSRange caseInsensitive = [opts rangeOfString:@"i"];
	NSRange globalReplacement = [opts rangeOfString:@"g"];
	
	ObjPCRE *regex;
	if (caseInsensitive.location != NSNotFound) {
		regex = [[ObjPCRE alloc] initWithPattern:pattern 
									  andOptions:PCRE_CASELESS];
	} else {
		regex = [[ObjPCRE alloc] initWithPattern:pattern];
	}
	
	NSString *transformedMessage = [NSString stringWithString: lastMessageString];
	if (globalReplacement.location != NSNotFound) {
		[regex replaceAll:&transformedMessage
			  replacement:replacement];
	} else {
		[regex replaceFirst:&transformedMessage
				replacement:replacement];
	}
	
	[regex release];
	
	// Set new message text
	NSString *newMessageRawText;
	if (enableCorrectionText) { 
		newMessageRawText = [NSString stringWithFormat:AILocalizedString(@"Correction (%@): %@", nil), messageString, transformedMessage];	
	} else {
		newMessageRawText = [NSString stringWithFormat:AILocalizedString(@"Correction: %@", nil), transformedMessage];
	}
	
	NSDictionary *defaultFormatting = [[adium contentController] defaultFormattingAttributes];
	NSAttributedString *newMessageText = [[[NSAttributedString alloc] initWithString:newMessageRawText 
																		 attributes:defaultFormatting] autorelease];
	return newMessageText;
}


- (float)filterPriority {
	return DEFAULT_FILTER_PRIORITY;
}

@end
