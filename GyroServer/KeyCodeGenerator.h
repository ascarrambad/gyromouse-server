//
//  KeyCodeGeneratorWrapper.h
//  GyroServer
//
//  Created by Matteo Riva on 29/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

#import <Carbon/Carbon.h> /* For kVK_ constants, and TIS functions. */
/* Returns string representation of key, if it is printable.
 * Ownership follows the Create Rule; that is, it is the caller's
 * responsibility to release the returned object. */

//#import <ApplicationServices/ApplicationServices.h>

@interface KeyCodeGenerator : NSObject

+(nullable NSArray<NSNumber *>*)keyCodeForChar:(UniChar)c;

@end
