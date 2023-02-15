//
//  ScrollFunction.m
//  GyroServer
//
//  Created by Matteo Riva on 18/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

#import "CFunctions.h"

@implementation CFunctions : NSObject

+(void)scrollWithRoll:(double)roll {
    CGEventRef scroll = CGEventCreateScrollWheelEvent(nil, kCGScrollEventUnitLine, 1, roll);
    CGEventPost(kCGHIDEventTap, scroll);
}

+(OSStatus)sendAppleEventToSystemProcess:(AEEventID)EventToSend {
    AEAddressDesc targetDesc;
    static const ProcessSerialNumber kPSNOfSystemProcess = { 0, kSystemProcess };
    AppleEvent eventReply = {typeNull, NULL};
    AppleEvent appleEventToSend = {typeNull, NULL};
    
    OSStatus error = noErr;
    
    error = AECreateDesc(typeProcessSerialNumber, &kPSNOfSystemProcess,
                         sizeof(kPSNOfSystemProcess), &targetDesc);
    
    if (error != noErr)
    {
        return(error);
    }
    
    error = AECreateAppleEvent(kCoreEventClass, EventToSend, &targetDesc,
                               kAutoGenerateReturnID, kAnyTransactionID, &appleEventToSend);
    
    AEDisposeDesc(&targetDesc);
    if (error != noErr)
    {
        return(error);
    }
    
    error = AESend(&appleEventToSend, &eventReply, kAENoReply,
                   kAENormalPriority, kAEDefaultTimeout, NULL, NULL);
    
    AEDisposeDesc(&appleEventToSend);
    if (error != noErr)
    {
        return(error);
    }
    
    AEDisposeDesc(&eventReply);
    
    return(error); 
}

static void KeyArrayCallback(const void* key, const void* value, void* context) { CFArrayAppendValue(context, key);  }

+(NSString*)localizedDisplayProductName:(NSScreen*)display {
    NSDictionary* screenDictionary = [display deviceDescription];
    NSNumber* screenID = [screenDictionary objectForKey:@"NSScreenNumber"];
    CGDirectDisplayID aID = [screenID unsignedIntValue];
    CFStringRef localName = NULL;
    io_connect_t displayPort = CGDisplayIOServicePort(aID);
    CFDictionaryRef dict = (CFDictionaryRef)IODisplayCreateInfoDictionary(displayPort, 0);
    CFDictionaryRef names = CFDictionaryGetValue(dict, CFSTR(kDisplayProductName));
    if(names)
    {
        CFArrayRef langKeys = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks );
        CFDictionaryApplyFunction(names, KeyArrayCallback, (void*)langKeys);
        CFArrayRef orderLangKeys = CFBundleCopyPreferredLocalizationsFromArray(langKeys);
        CFRelease(langKeys);
        if(orderLangKeys && CFArrayGetCount(orderLangKeys))
        {
            CFStringRef langKey = CFArrayGetValueAtIndex(orderLangKeys, 0);
            localName = CFDictionaryGetValue(names, langKey);
            CFRetain(localName);
        }
        CFRelease(orderLangKeys);
    }
    CFRelease(dict);
    return (__bridge NSString*)localName;
}


@end
