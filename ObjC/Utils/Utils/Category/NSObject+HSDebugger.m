//
//  Copyright (c) 2021 faylib.cn
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "NSObject+HSDebugger.h"
#import <objc/runtime.h>

@implementation NSObject (HSDebugger)

+ (BOOL)debugMode {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

+ (void)setDebugMode:(BOOL)debugMode {
    objc_setAssociatedObject(self, @selector(debugMode), [NSNumber numberWithBool:debugMode], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)log:(NSString *)message, ... {
    if (self.class.debugMode) {
        printf("%s\n", [[NSString stringWithFormat:@"[ %@ ] %@", [self class], message] UTF8String]);
        va_list args;
        NSString *arg;
        va_start(args, message);
        while ((arg = va_arg(args, NSString *))) {
            printf("%s\n", [[NSString stringWithFormat:@"[ %@ ] %@", [self class], arg] UTF8String]);
        }
        va_end(args);
    }
}

@end
