//
//  HNFixYourLastInputPlugin.h
//  Perl regexp substitution plugin for Adium IM.
//
//  By Henrik Nyh, 2007-04-19.
//  Free to modify and redistribute with due credit.
//

#import <Adium/AIPlugin.h>
#import <Adium/AISharedAdium.h>
#import <AIUtilities/AITigerCompatibility.h>
#import <Cocoa/Cocoa.h>

@protocol AIContentFilter;

@interface HNFixYourLastInputPlugin : AIPlugin <AIContentFilter> {
	NSMutableDictionary *lastOutgoingMessages;
}

@end
