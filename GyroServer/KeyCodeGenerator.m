//
//  KeyCodeGeneratorWrapper.m
//  GyroServer
//
//  Created by Matteo Riva on 29/08/15.
//  Copyright © 2015 Matteo Riva. All rights reserved.
//

#import "KeyCodeGenerator.h"

@interface KeyCodeGenerator()

@property (assign, nonatomic) UCKeyboardLayout *currentKeyboardLayout;

+(NSString *)createStringForKey:(CGKeyCode)keyCode WithModifier:(UInt32)modif;

@end

@implementation KeyCodeGenerator : NSObject

+(nullable NSArray<NSNumber*>*)keyCodeForChar:(UniChar)c {
    static NSMutableDictionary *charToCodeDict = NULL;
    
    if (charToCodeDict == NULL) {
        charToCodeDict = [[NSMutableDictionary alloc] init];
        for (int i = 0; i < 128; ++i) {
            for (int j = 0; j < 4; j++) {
                int pow = j == 0 ? 0 : 1 << j;
                pow = j == 2 ? 10 : pow;
                NSString *string = [KeyCodeGenerator createStringForKey:i WithModifier:pow];
                if (string != NULL) {
                    if ([string isEqualToString:@"@"])
                        string = @"chiocciola";
                    [charToCodeDict setObject:@[[NSNumber numberWithInt:i],
                                                [NSNumber numberWithInt:pow]]
                                       forKey: string];
                }
            }
        }
    }
    
    NSString *searchString = [NSString stringWithCharacters:&c length:1];
    if ([searchString isEqualToString:@"@"])
        searchString = @"chiocciola";
    NSArray<NSNumber *>* retArr = [charToCodeDict valueForKey:searchString];
    return retArr;
    
}

+(NSString *)createStringForKey:(CGKeyCode)keyCode WithModifier:(UInt32)modif {
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = (CFDataRef) TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    const UCKeyboardLayout *keyboardLayout =
    (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
    UInt32 keysDown = 0;
    UniChar chars[4];
    UniCharCount realLength;
    UCKeyTranslate(keyboardLayout,
                   keyCode,
                   kUCKeyActionDisplay,
                   modif,
                   LMGetKbdType(),
                   kUCKeyTranslateNoDeadKeysBit,
                   &keysDown,
                   sizeof(chars) / sizeof(chars[0]),
                   &realLength,
                   chars);
    CFRelease(currentKeyboard);
    return [NSString stringWithCharacters:chars length:1];
}

@end
