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

#import "HSReachability.h"
#import "NSObject+HSDebugger.h"
#import <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/SystemConfiguration.h>

/*! 网络可达性状态的回调 */
typedef void(^HSReachabilityStatusCallbackBlock)(void);

/*! 网络可达性状态改变的通知 */
NSString * const HSReachabilityStatusChangedNotification = @"HSReachabilityStatusChangedNotification";
/*! 代码块计数名 */
static NSString * const HS_REACHABILITY_STATUS_CHANGED_BLOCK = @"HS_REACHABILITY_STATUS_CHANGED_BLOCK";
/*! 通知方法 */
static NSString * const HS_REACHABILITY_HANDLE_STATUS_CHANGE_NOTIFICATION = @"handleReachabilityStatusChangedNotification:";

/*! 声明网络可达性状态发生变化回调的方法 */
static void HSReachabilityCallback(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void* info);
/*! 声明复制网络可达性状态改变回调的方法 */
static const void * HSReachabilityCallbackCopy(const void *info);
/*! 声明释放网络可达性状态改变回调的方法 */
static void HSReachabilityCallbackRelease(const void *info);

NSString * const HSReachabilityStatusConvert[6] = {
    [HSReachabilityStatusNone] = @"None",
    [HSReachabilityStatusWiFi] = @"WiFi",
    [HSReachabilityStatusWWAN2G] = @"2G",
    [HSReachabilityStatusWWAN3G] = @"3G",
    [HSReachabilityStatusWWAN4G] = @"4G",
    [HSReachabilityStatusUnknown] = @"Unknown"
};

@interface HSReachability ()

// 代理数组
@property (nonatomic, strong) NSPointerArray *delegates;

// 监听者数组
@property (nonatomic, strong) NSMapTable *monitors;

// 代码块数组
@property (nonatomic, strong) NSMutableDictionary *handlers;

// 网络可达性句柄
@property (nonatomic, assign) SCNetworkReachabilityRef reachabilityRef;

// 上一个网络状态
@property (nonatomic, assign) HSReachabilityStatus previousStatus;

// 代码块计数
@property (nonatomic) NSInteger blocksCount;

@end

@implementation HSReachability

#pragma mark - Life Cycle

// 初始化
- (instancetype)initWithReachabilityRef:(SCNetworkReachabilityRef)reachabilityRef {
    self = [super init];
    if (self) {
        self.reachabilityRef = reachabilityRef;
        self.previousStatus = HSReachabilityStatusUnknown;
    }
    return self;
}

// 检查是否可以连接到指定主机域名
+ (instancetype)reachabilityWithHostName:(NSString *)hostName {
    SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [hostName UTF8String]);
    if (reachabilityRef != NULL) {
        return [[self alloc] initWithReachabilityRef:reachabilityRef];
    }
    return nil;
}

// 检查是否可以连接到默认路由
+ (instancetype)reachability {
    // 本机地址 (0.0.0.0)
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef reachabilityRef = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    if (reachabilityRef != NULL) {
        return [[self alloc] initWithReachabilityRef:reachabilityRef];
    }
    return nil;
}

// 释放
- (void)dealloc {
    [self stopMonitor];
    if (self.reachabilityRef != NULL) {
        CFRelease(self.reachabilityRef);
    }
}

#pragma mark - Getter / Setter Methods

// 代理数组
- (NSPointerArray *)delegates {
    if (!_delegates) {
        _delegates = [NSPointerArray weakObjectsPointerArray];
    }
    return _delegates;
}

// 监听者数组
- (NSMapTable *)monitors {
    if (!_monitors) {
        _monitors = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory];
    }
    return _monitors;
}

// 代码块数组
- (NSMutableDictionary *)handlers {
    if (!_handlers) {
        _handlers = [NSMutableDictionary dictionary];
    }
    return _handlers;
}

// 设置代理
- (void)setDelegate:(id<HSReachabilityDelegate>)delegate {
    if ([delegate respondsToSelector:@selector(reachability:statusChanged:)]) {
        [self.delegates addPointer:(__bridge void*)delegate];
        
        HSLog(@"[ MONITOR ] Added", [NSString stringWithFormat:@"[ CLASS ] %@", [delegate class]], @"[ USING ] Delegate");
    }
}

#pragma mark - Private Methods

// 当前状态
- (HSReachabilityStatus)status {
    HSReachabilityStatus status = HSReachabilityStatusUnknown;
    SCNetworkReachabilityFlags flags;
    
    // 获取当前标记对应的网络可达性状态
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
        status = [self networkStatusForFlags:flags];
    }
    
    return status;
}

// 根据标记获取网络状态
- (HSReachabilityStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags {
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) { // 网络不通
        return HSReachabilityStatusNone;
    }
    
    // 网络可达性状态
    HSReachabilityStatus status = HSReachabilityStatusUnknown;
    
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) { // 可连上目标主机
        status = HSReachabilityStatusWiFi;
    }
    
    if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) { // 按需连接状态（CFSocketStream）
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) { // 不需用户干预
            status = HSReachabilityStatusWiFi;
        }
    }
    
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN) { // 使用的是 WWAN 网络接口（CFNetwork）
        // 获取当前数据网络的类型
        CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
        
        // 定义网络类型
        NSArray *WWAN2G = @[CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x];
        NSArray *WWAN3G = @[CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD];
        NSArray *WWAN4G = @[CTRadioAccessTechnologyLTE];
        
        // 当前网络类型
        NSString *technology = info.currentRadioAccessTechnology;
        
        // 获取当前网络状态
        if ([WWAN2G containsObject:technology]) {
            status = HSReachabilityStatusWWAN2G;
        } else if ([WWAN3G containsObject:technology]) {
            status = HSReachabilityStatusWWAN3G;
        } else if ([WWAN4G containsObject:technology]){
            status = HSReachabilityStatusWWAN4G;
        }
    }
    
    return status;
}

// 网络可达性状态改变
- (void)statusChanged {
    HSLog(@"[ STATUS ] Changed", [NSString stringWithFormat:@"[ TYPE ] %@", HSReachabilityStatusConvert[self.previousStatus]]);
    
    // 使用代码块回调
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.handlers.count > 0) {
            NSArray *keys = [self.monitors.keyEnumerator.allObjects sortedArrayUsingSelector:@selector(compare:)];
            
            for (NSString *key in keys) {
                HSReachabilityStatusHandler handler = self.handlers[key];
                handler(self.previousStatus);
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                for (NSString *key in self.handlers.allKeys) {
                    if (![keys containsObject:key]) {
                        [self.handlers removeObjectForKey:key];
                    }
                }
            });
        }
    });
    
    // 使用代理回调
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.delegates.count > 0) {
            for (id<HSReachabilityDelegate> delegate in self.delegates.allObjects) {
                [delegate reachability:self statusChanged:self.previousStatus];
            }
        }
    });
    
    // 使用通知回调
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:HSReachabilityStatusChangedNotification object:self];
    });
}

#pragma mark - Public Methods

// 打开网络监听
- (BOOL)startMonitor {
    [self stopMonitor];
    
    BOOL started = NO;
    
    // 回调网络可达性状态改变
    HSReachabilityStatusCallbackBlock block = ^() {
        // 判断当前网络可达性状态是否发生了改变
        if (self.previousStatus != [self status]) {
            self.previousStatus = [self status];
            
            // 网络可达性状态改变时，发起回调
            [self statusChanged];
        }
    };
    
    // 获取网络可达性上下文
    SCNetworkReachabilityContext context = {0, (__bridge void *)block, HSReachabilityCallbackCopy, HSReachabilityCallbackRelease, NULL};
    
    // 设置网络状态改变的回调
    if (SCNetworkReachabilitySetCallback(self.reachabilityRef, HSReachabilityCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            started = YES;
            
            HSLog(@"[ MONITOR ] Started");
            
            // 后台获取网络可达性的标记并设置回调
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                SCNetworkReachabilityFlags flags;
                if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)) {
                    HSReachabilityCallback(self.reachabilityRef, flags, (__bridge void *)(block));
                }
            });
        }
    }
    
    return started;
}

// 关闭网络监听
- (BOOL)stopMonitor {
    BOOL stopped = NO;
    
    if (self.reachabilityRef != NULL) {
        if (SCNetworkReachabilityUnscheduleFromRunLoop(self.reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)) {
            stopped = YES;
            
            HSLog(@"[ MONITOR ] Stopped");
        }
    }
    
    return stopped;
}

#pragma mark -

// 添加网络可达性状态改变的监听者并设置回调
- (void)addMonitor:(id)monitor statusChanged:(HSReachabilityStatusHandler)block {
    [self.monitors setObject:monitor forKey:[NSString stringWithFormat:@"%@_%ld", HS_REACHABILITY_STATUS_CHANGED_BLOCK, (long)self.blocksCount]];
    [self.handlers setObject:block forKey:[NSString stringWithFormat:@"%@_%ld", HS_REACHABILITY_STATUS_CHANGED_BLOCK, (long)self.blocksCount]];
    self.blocksCount++;
    
    HSLog(@"[ MONITOR ] Added", [NSString stringWithFormat:@"[ CLASS ] %@", [monitor class]], @"[ USING ] Block");
}

// 添加网络可达性状态改变的监听者
- (void)addMonitor:(id)monitor {
    [[NSNotificationCenter defaultCenter] addObserver:monitor selector:NSSelectorFromString(HS_REACHABILITY_HANDLE_STATUS_CHANGE_NOTIFICATION) name:HSReachabilityStatusChangedNotification object:nil];
    
    HSLog(@"[ MONITOR ] Added", [NSString stringWithFormat:@"[ CLASS ] %@", [monitor class]], @"[ USING ] Notification");
}

// 移除网络可达性状态改变的监听者
- (void)removeMonitor:(id)monitor {
    [[NSNotificationCenter defaultCenter] removeObserver:monitor name:HSReachabilityStatusChangedNotification object:nil];
    
    HSLog(@"[ MONITOR ] Removed", [NSString stringWithFormat:@"[ CLASS ] %@", [monitor class]], @"[ USING ] Notification");
}

// 当前网络可达性状态
- (HSReachabilityStatus)currentStatus {
    return self.previousStatus;
}

@end

#pragma mark - Supporting Functions

// 网络可达性状态发生变化的回调
static void HSReachabilityCallback(SCNetworkReachabilityRef ref, SCNetworkReachabilityFlags flags, void* info) {
    HSReachabilityStatusCallbackBlock block = (__bridge HSReachabilityStatusCallbackBlock)info;
    block();
}

// 复制网络可达性状态改变的回调
static const void * HSReachabilityCallbackCopy(const void* info) {
    return Block_copy(info);
}

// 释放网络可达性状态改变的回调
static void HSReachabilityCallbackRelease(const void* info) {
    if (info) {
        Block_release(info);
    }
}

@implementation NSObject (HSReachability)

// 处理网络可达性状态改变的通知
- (void)handleReachabilityStatusChangedNotification:(NSNotification *)notification {
    // TODO: Override reachability status changed event.
    
}

@end
