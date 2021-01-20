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

#import <UIKit/UIKit.h>
#import "HSRouter.h"
#import "NSObject+HSModel.h"

@implementation HSRouter

+ (instancetype)router {
    static dispatch_once_t onceToken;
    static HSRouter *router;
    dispatch_once(&onceToken, ^{
        router = [[HSRouter alloc] init];
    });
    return router;
}

- (void)navigateToIndex:(NSInteger)index {
    if (index == 0) {
        return;
    }
    
    NSString *class = NSStringFromClass([[self currentViewController] class]);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"viewController = %@", class];
    NSArray *route = [[HSRouter router].routes filteredArrayUsingPredicate:predicate];
    NSInteger currentIndex = [[HSRouter router].routes indexOfObject:route.firstObject];
    if (currentIndex == NSNotFound) {
        return;
    }
    
    NSInteger nextIndex = currentIndex + index;
    if (nextIndex < [HSRouter router].routes.count) {
        Class Cls = NSClassFromString([HSRouter router].routes[nextIndex].viewController);
        UIViewController *viewController = [[Cls alloc] init];
        [[self currentViewController] presentViewController:viewController animated:YES completion:NULL];
    }
}

- (void)navigateToViewController:(NSString *)viewController {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"viewController = %@", viewController];
    NSArray<HSRoute *> *route = [[HSRouter router].routes filteredArrayUsingPredicate:predicate];
    Class Cls = NSClassFromString(route.firstObject.viewController);
    UIViewController *nextViewController = [[Cls alloc] init];
    [[self currentViewController] presentViewController:nextViewController animated:YES completion:NULL];
}

- (UIViewController *)currentViewController {
    UIWindow *window  = [UIApplication sharedApplication].keyWindow;
    UIViewController *viewController = window.rootViewController;
    while (viewController.presentedViewController) {
        viewController = viewController.presentedViewController;
        if ([viewController isKindOfClass:[UINavigationController class]]) {
            viewController = [(UINavigationController *)viewController visibleViewController];
        } else if ([viewController isKindOfClass:[UITabBarController class]]) {
            viewController = [(UITabBarController *)viewController selectedViewController];
        }
    }
    return viewController;
}

- (NSDictionary<NSString *,NSString *> *)unkeyedContainer {
    return @{@"routes": @"HSRoute"};
}

@end
