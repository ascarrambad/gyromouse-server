//
//  ScrollFunction.h
//  GyroServer
//
//  Created by Matteo Riva on 18/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <CoreServices/CoreServices.h>
#import <Carbon/Carbon.h>
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AppKit/AppKit.h>

@interface CFunctions : NSObject

+(void)scrollWithRoll:(double)roll;
+(OSStatus)sendAppleEventToSystemProcess:(AEEventID)EventToSend;
+(NSString*)localizedDisplayProductName:(NSScreen*)display;

@end