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

#import "HSNetwork.h"
#import "NSObject+HSModel.h"
#import "NSObject+HSDebugger.h"

@implementation HSNetwork

/*!
 */
static NSString * const HS_NETWORK_REQUEST_SUCCESS_NOTIFICATION_NAME = @"HS_NETWORK_REQUEST_SUCCESS_NOTIFICATION_NAME";
static NSString * const HS_NETWORK_REQUEST_FAILURE_NOTIFICATION_NAME = @"HS_NETWORK_REQUEST_FAILURE_NOTIFICATION_NAME";
static NSString * const HS_NETWORK_HANDLE_REQUEST_SUCCESS_NOTIFICATION = @"handleRequestSuccessNotification:";
static NSString * const HS_NETWORK_HANDLE_REQUEST_FAILURE_NOTIFICATION = @"handleRequestFailureNotification:";

/*!
 */
static NSString * const HS_NETWORK_REQUEST_MAXIMUM_RETRY_TIMES = @"HS_NETWORK_REQUEST_MAXIMUM_RETRY_TIMES";
static NSString * const HS_NETWORK_REQUEST_RUN_IN_MAIN_QUEUE = @"HS_NETWORK_REQUEST_RUN_IN_MAIN_QUEUE";

/*!
 */
static NSString * const HS_NETWORK_SENDER_SUCCESS_BLOCK = @"HS_NETWORK_SENDER_SUCCESS_BLOCK";
static NSString * const HS_NETWORK_SENDER_FAILURE_BLOCK = @"HS_NETWORK_SENDER_FAILURE_BLOCK";
static NSString * const HS_NETWORK_SENDER_DELEGATE = @"HS_NETWORK_SENDER_DELEGATE";
static NSString * const HS_NETWORK_SENDER_RECEIVER = @"HS_NETWORK_SENDER_RECEIVER";

/*!
 */
static NSString * const HS_NETWORK_REQUEST_STATUS_CODE = @"statusCode";
static NSString * const HS_NETWORK_REQUEST_RESULT_DATA = @"resultData";
static NSString * const HS_NETWORK_REQUEST_ERROR = @"error";

#pragma mark - Private Methods

- (NSMutableDictionary *)settings:(void (^)(NSMutableDictionary *settings))addition {
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithDictionary:@{
        HS_NETWORK_REQUEST_MAXIMUM_RETRY_TIMES: [NSNumber numberWithInteger:self.maximumRetryTimes],
        HS_NETWORK_REQUEST_RUN_IN_MAIN_QUEUE: [NSNumber numberWithBool:self.runInMainQueue]
    }];
    addition(settings);
    return settings;
}

- (void)setupWithSettings:(NSDictionary *)settings {
    NSURLSession *session = [self setupSession];
    NSURLRequest *request = [self setupRequest];
    HSLog(@"Request started.");
    [self fetchWithSettings:settings session:session request:request retryCount:self.maximumRetryTimes];
}

- (NSURLSession *)setupSession {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    return session;
}

- (NSURLRequest *)setupRequest {
    NSURL *URL = [NSURL URLWithString:self.requestURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = [self requestMethodConvert:self.requestMethod];
    
    if (self.timeoutInterval > 0) {
        request.timeoutInterval = self.timeoutInterval;
    }
    
    if (self.requestHeaderFields) {
        [self.requestHeaderFields enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull field, NSString * _Nonnull value, BOOL * _Nonnull stop) {
            [request addValue:value forHTTPHeaderField:field];
        }];
    }
    
    if (self.requestBody) {
        NSError *error;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:self.requestBody options:0 error:&error];
    }
    
    return request;
}

- (NSString *)requestMethodConvert:(HSNetworkRequestMethod)method {
    NSArray *methods = @[@"GET", @"POST", @"DELETE"];
    return methods[method];
}

- (void)fetchWithSettings:(NSDictionary *)settings session:(NSURLSession *)session request:(NSURLRequest *)request retryCount:(NSInteger)count {
    HSLog([NSString stringWithFormat:@"URL: %@", request.URL],
          [NSString stringWithFormat:@"Method: %@", request.HTTPMethod],
          [NSString stringWithFormat:@"Header: %@", request.allHTTPHeaderFields],
          [NSString stringWithFormat:@"Body: %@", [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil]]);
    
    count--;
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSString *url = response.URL ? [NSString stringWithFormat:@"%@", response.URL] :  [NSString stringWithFormat:@"%@", request.URL];
        BOOL retry = [self handleWithSettings:settings url:url statusCode:httpResponse.statusCode resultData:data error:error retryCount:count];
        if (retry) {
            NSInteger maximumRetryTimes = [settings[HS_NETWORK_REQUEST_MAXIMUM_RETRY_TIMES] integerValue];
            HSLog(@"Request retrying.",
                  [NSString stringWithFormat:@"Count: %ld", (long)(maximumRetryTimes - count)]);
            [self fetchWithSettings:settings session:session request:request retryCount:count];
        }
    }];
    [task resume];
}

- (BOOL)handleWithSettings:(NSDictionary *)settings url:(NSString *)url statusCode:(NSInteger)code resultData:(id)data error:(NSError *)error retryCount:(NSInteger)count {
    if (error && count > 0) {
        return YES;
    }
    
    if (data) {
        data = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
    }
    
    if (error) {
        HSLog(@"Request failure.", [NSString stringWithFormat:@"URL: %@", url]);
        [self responseWithSettings:settings statusCode:code error:error];
    } else {
        HSLog(@"Request success.", [NSString stringWithFormat:@"URL: %@", url]);
        [self responseWithSettings:settings statusCode:code resultData:data];
    }
    
    return NO;
}

- (void)responseWithSettings:(NSDictionary *)settings statusCode:(NSInteger)code resultData:(id _Nullable)data {
    HSSuccessHandler handler = settings[HS_NETWORK_SENDER_SUCCESS_BLOCK];
    if (handler) {
        [self runWithSettings:settings exec:^{
            handler(code, data);
        }];
    }

    id<HSNetworkDelegate> delegate = settings[HS_NETWORK_SENDER_DELEGATE];
    if (delegate) {
        [self runWithSettings:settings exec:^{
            [delegate network:self request:code success:data];
        }];
    }
    
    id receiver = settings[HS_NETWORK_SENDER_RECEIVER];
    if (receiver) {
        NSMutableDictionary *object = [NSMutableDictionary dictionaryWithDictionary:@{HS_NETWORK_REQUEST_STATUS_CODE: @(code)}];
        if (data) [object addEntriesFromDictionary:@{HS_NETWORK_REQUEST_RESULT_DATA: data}];
        [self runWithSettings:settings exec:^{
            [self postName:HS_NETWORK_REQUEST_SUCCESS_NOTIFICATION_NAME resultData:object];
        }];
    }
}

- (void)responseWithSettings:(NSDictionary *)settings statusCode:(NSInteger)code error:(NSError * _Nullable)error {
    HSFailureHandler handler = settings[HS_NETWORK_SENDER_FAILURE_BLOCK];
    if (handler) {
        [self runWithSettings:settings exec:^{
            handler(code, error);
        }];
    }
    
    id<HSNetworkDelegate> delegate = settings[HS_NETWORK_SENDER_DELEGATE];
    if (delegate) {
        [self runWithSettings:settings exec:^{
            [delegate network:self request:code failure:error];
        }];
    }
    
    id receiver = settings[HS_NETWORK_SENDER_RECEIVER];
    if (receiver) {
        NSMutableDictionary *object = [NSMutableDictionary dictionaryWithDictionary:@{HS_NETWORK_REQUEST_STATUS_CODE: @(code)}];
        if (error) [object addEntriesFromDictionary:@{HS_NETWORK_REQUEST_ERROR: error}];
        [self runWithSettings:settings exec:^{
            [self postName:HS_NETWORK_REQUEST_FAILURE_NOTIFICATION_NAME resultData:object];
        }];
    }
}

- (void)runWithSettings:(NSDictionary *)settings exec:(void (^)(void))exec {
    BOOL runInMainQueue = [settings[HS_NETWORK_REQUEST_RUN_IN_MAIN_QUEUE] boolValue];
    if (runInMainQueue) {
        dispatch_async(dispatch_get_main_queue(), ^{
            exec();
        });
    } else {
        exec();
    }
}

- (void)addReceiver:(id)receiver {
    [[NSNotificationCenter defaultCenter] addObserver:receiver selector:NSSelectorFromString(HS_NETWORK_HANDLE_REQUEST_SUCCESS_NOTIFICATION) name:HS_NETWORK_REQUEST_SUCCESS_NOTIFICATION_NAME object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:receiver selector:NSSelectorFromString(HS_NETWORK_HANDLE_REQUEST_FAILURE_NOTIFICATION) name:HS_NETWORK_REQUEST_FAILURE_NOTIFICATION_NAME object:nil];
}

- (void)removeReceiver:(id)receiver {
    [[NSNotificationCenter defaultCenter] removeObserver:receiver name:HS_NETWORK_REQUEST_SUCCESS_NOTIFICATION_NAME object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:receiver name:HS_NETWORK_REQUEST_FAILURE_NOTIFICATION_NAME object:nil];
}

- (void)postName:(NSString *)name resultData:(id)data {
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:data];
}

#pragma mark - Public Methods

- (void)sendRequestWithSuccess:(HSSuccessHandler)success failure:(HSFailureHandler)failure {
    [self setupWithSettings:[self settings:^(NSMutableDictionary *settings) {
        settings[HS_NETWORK_SENDER_SUCCESS_BLOCK] = success;
        settings[HS_NETWORK_SENDER_FAILURE_BLOCK] = failure;
    }]];
}

- (void)sendRequest {
    [self setupWithSettings:[self settings:^(NSMutableDictionary *settings) {
        settings[HS_NETWORK_SENDER_DELEGATE] = self.delegate;
    }]];
}

- (void)sendRequestForReceiver:(id)receiver {
    [self setupWithSettings:[self settings:^(NSMutableDictionary *settings) {
        settings[HS_NETWORK_SENDER_RECEIVER] = receiver;
        [self removeReceiver:receiver];
        [self addReceiver:receiver];
    }]];
}

@end

@implementation HSNetwork (HSNotification)

+ (instancetype)parseNotification:(NSNotification *)notification {
    HSNetwork *network = notification.object;
    network.JSON = notification.userInfo;
    return network;
}

@end

@implementation NSObject (HSNetwork)

- (void)handleRequestSuccessNotification:(NSNotification *)notification {
    // TODO: Override request success event.
}

- (void)handleRequestFailureNotification:(NSNotification *)notification {
    // TODO: Override request failure event.
}

- (void)network:(HSNetwork *)network request:(NSInteger)statusCode success:(id)resultData {
    // TODO: Override request success event.
}

- (void)network:(HSNetwork *)network request:(NSInteger)statusCode failure:(NSError *)error {
    // TODO: Override request failure event.
}

@end
