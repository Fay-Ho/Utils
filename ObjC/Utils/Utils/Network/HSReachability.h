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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*! 获取当前网络可达性状态
 
 该方法用于接收当前已发生了改变的网络可达性状态
 
 传入的对象用于接收网络可达性状态
 
 @warning 使用通知方式监听网络可达性状态时调用
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
#define HSGetCurrentReachabilityStatus(status) \
HSReachability *reachability = notification.object; \
HSReachabilityStatus status = [reachability currentStatus]

/*! 网络可达性状态
 */
typedef NS_ENUM(NSUInteger, HSReachabilityStatus) {
    HSReachabilityStatusNone = 0,   // 无网络
    HSReachabilityStatusWiFi,       // 通过 WiFi 连接
    HSReachabilityStatusWWAN2G,     // 通过 2G 连接
    HSReachabilityStatusWWAN3G,     // 通过 3G 连接
    HSReachabilityStatusWWAN4G,     // 通过 4G 连接
    HSReachabilityStatusUnknown     // 未知网络状态
};

/*! 网络可达性状态改变的代码块
 
 @param status 网络可达性状态
 */
typedef void(^HSReachabilityStatusHandler)(HSReachabilityStatus status);

/*! 网络可达性状态转化
 
 将当前网络可达性状态转化为字符串
 */
extern NSString * _Nonnull const HSReachabilityStatusConvert[];

/*! 网络可达性状态改变的通知名
 
 使用通知监听网络可达性状态时监听此通知名，所有监听此通知名的类都会接收到网络可达性状态改变的消息
 
 @warning 使用通知方式监听网络可达性状态时实现
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
extern NSString * const HSReachabilityStatusChangedNotification;

@class HSReachability;

@protocol HSReachabilityDelegate <NSObject>

/*! 网络可达性状态发生改变的代理方法
 
 此方法用于接收网络可达性状态改变的消息，由一个代理的队列管理，所有实现此代理方法的监听者都会接收到网络可达性状态改变的消息
 
 @param reachability 网络可达性实例
 
 @param status 网络可达性状态
 
 @warning 使用代理方式监听网络可达性状态时实现
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
- (void)reachability:(HSReachability *)reachability statusChanged:(HSReachabilityStatus)status;

@end

@interface HSReachability : NSObject

/*! 网络可达性助手代理
 
 此代理将被作为监听者添加到网络可达性状态的监听队列
 
 若此监听者被从内存中释放，监听队列会自动移除此监听者，不需手动管理
 
 @warning 使用代理方式监听网络可达性状态时实现
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
@property (nonatomic, weak) id<HSReachabilityDelegate> delegate;

#pragma mark -

/*! 新建实例
 
 检查是否可以连接到指定主机域名
 
 @param hostName 指定主机域名
 
 @return 实例
 */
+ (instancetype)reachabilityWithHostName:(NSString *)hostName;

/*! 新建实例
 
 检查是否可以连接到默认路由
 
 @return 实例
 */
+ (instancetype)reachability;

#pragma mark -

/*! 打开网络可达性监听
 
 @return 打开监听是否成功
 */
- (BOOL)startMonitor;

/*! 关闭网络可达性监听
 
 @return 关闭监听是否成功
 */
- (BOOL)stopMonitor;

/*! 添加网络可达性状态改变的监听者并设置回调
 
 此方法用于将监听者添加到网络可达性状态监听队列，所有实现此方法的监听者都会接收到网络可达性状态改变的消息
 
 若此监听者被从内存中释放，监听队列会自动移除此监听者，不需手动管理
 
 @param monitor 网络可达性监听者
 
 @param block 网络可达性状态发生改变时的回调
  
 @warning 使用代码块方式监听网络可达性状态时调用
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
- (void)addMonitor:(id)monitor statusChanged:(nonnull HSReachabilityStatusHandler)block;

/*!添加网络可达性状态改变的监听者
 
 此方法用于将监听者添加到网络可达性状态监听队列，所有实现此方法的监听者都会接收到网络可达性状态改变的消息
 
 若要从监听队列移除此监听者，需要调用 `-removeMonitor:` 方法
  
 @param monitor 网络可达性监听者
 
 @warning 使用通知方式监听网络可达性状态时调用
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
- (void)addMonitor:(id)monitor;

/*! 移除网络可达性状态改变的监听者
 
 此方法用于将监听者从网络可达性状态监听队列移除
  
 @param monitor 网络可达性监听者
 
 @warning 使用通知方式监听网络可达性状态时调用
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
- (void)removeMonitor:(id)monitor;

#pragma mark -

/*! 当前网络可达性状态
 
 @return 网络可达性状态
 
 @warning 使用通知方式监听网络可达性状态时调用
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 */
- (HSReachabilityStatus)currentStatus;

@end

@interface NSObject (HSReachability)

/*! 处理网络可达性状态改变的通知
 
 该方法用于接收网络可达性状态发生改变的消息
 
 通知的对象 `notification.object` 返回 `HSReachability` 实例
 
 可通过 `HSGetCurrentReachabilityStatus(status)` 宏同时接收 `HSReachability` 实例和当前网络可达性状态
 
 @param notification 网络可达性状态改变的通知
 
 @warning 使用通知方式监听网络可达性状态时实现
 
 网络可达性助手集成了代码块，代理，通知三种方式进行网络可达性状态监听，使用时只需实现其中一种方式即可
 
 需子类重写此方法实现功能
 */
- (void)handleReachabilityStatusChangedNotification:(NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END
