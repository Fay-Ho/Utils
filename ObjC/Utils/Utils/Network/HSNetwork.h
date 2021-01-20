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

/*! 请求成功的回调
 
 @param statusCode 网络请求状态码
 
 @param resultData 请求结果
*/
typedef void(^HSSuccessHandler)(NSInteger statusCode, id _Nullable resultData);

/*! 请求失败的回调
 
 @param statusCode 网络请求状态码
 
 @param error 错误信息
*/
typedef void(^HSFailureHandler)(NSInteger statusCode, NSError * _Nullable error);

typedef NS_ENUM(NSUInteger, HSNetworkRequestMethod) {
    HSNetworkRequestMethodGet,
    HSNetworkRequestMethodPost,
    HSNetworkRequestMethodDelete,
};

@class HSNetwork;

@protocol HSNetworkDelegate <NSObject>

@optional

/*! 请求成功的代理方法
 
 @param network 实例
 
 @param statusCode 网络请求状态码
 
 @param resultData 请求结果
 */
- (void)network:(HSNetwork *)network request:(NSInteger)statusCode success:(id _Nullable)resultData;

/*! 请求失败的代理方法
 
 @param network 实例
 
 @param statusCode 网络请求状态码
 
 @param error 错误信息
 */
- (void)network:(HSNetwork *)network request:(NSInteger)statusCode failure:(NSError * _Nullable)error;

@end

@interface HSNetwork : NSObject

/*! 请求地址
 */
@property (strong, nonatomic) NSString *requestURL;

/*! 请求方法
*/
@property (nonatomic) HSNetworkRequestMethod requestMethod;

/*! 请求头
*/
@property (strong, nonatomic) NSDictionary<NSString *, NSString *> *requestHeaderFields;

/*! 请求参数
*/
@property (strong, nonatomic) NSDictionary<NSString *, id> *requestBody;

/*! 超时时长
 
 当网络请求的时长到达所设置的时长仍未成功，则自动判断为失败。
 
 不设置默认为60秒。
*/
@property (nonatomic) NSInteger timeoutInterval;

/*! 最大尝试次数
 
 设置此属性后，网络请求会在失败后自动发起重试，直至成功或达到最大尝试次数时结束。
 
 不设置或设置少于1时，默认请求1次。
*/
@property (nonatomic) NSInteger maximumRetryTimes;

/*! 主线程操作
 
 请求结束时是否自动返回到主线程
*/
@property (nonatomic) BOOL runInMainQueue;

/*! 网络请求代理
*/
@property (weak, nonatomic) id<HSNetworkDelegate> delegate;

/*! 发起网络请求
 
 @param success 请求成功的回调
 
 @param failure 请求失败的回调
*/
- (void)sendRequestWithSuccess:(HSSuccessHandler)success failure:(HSFailureHandler)failure;

/*! 发起网络请求
 */
- (void)sendRequest;

/*! 发起网络请求
 
 @param receiver 请求结果的接收者
*/
- (void)sendRequestForReceiver:(id)receiver;

@end

@interface HSNetwork ()

/*! 网络请求状态码
 */
@property (nonatomic) NSInteger statusCode;

/*! 请求结果
 */
@property (strong, nonatomic, nullable) id resultData;

/*! 错误信息
 */
@property (strong, nonatomic, nullable) NSError *error;

@end

@interface HSNetwork (HSNotification)

/*! 解析通知
 
 @param notification 请求结束接收的通知
 
 @return 实例
 */
+ (instancetype)parseNotification:(NSNotification *)notification;

@end

@interface NSObject (HSNetwork)

/*! 请求成功
 
 请求成功接收的通知的处理方法
 
 @param notification 接收到的通知
 */
- (void)handleRequestSuccessNotification:(NSNotification *)notification;

/*! 请求失败
 
 请求失败接收的通知的处理方法
 
 @param notification 接收到的通知
 */
- (void)handleRequestFailureNotification:(NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END
