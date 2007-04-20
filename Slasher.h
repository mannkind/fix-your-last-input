//
//  Slasher.h
//  Slasher substitution plugin for Adium IM
//
//  Created by Henrik Nyh on 2007-04-19.
//  Free to modify and redistribute with due credit.
//

#import <Adium/AIPlugin.h>
#import <Cocoa/Cocoa.h>

@interface Slasher : AIPlugin {
	NSMutableDictionary *lastOutgoingMessages;
	BOOL correctionComing;
}

@end
