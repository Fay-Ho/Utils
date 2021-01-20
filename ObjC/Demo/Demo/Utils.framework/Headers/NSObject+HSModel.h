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

@interface NSObject (HSModel)

/*!
 JSON 数据
 
 对本类的属性 / 需要解析的 JSON 数据进行转化操作
 
 Setter: 将 JSON 数据的键值转化为数据模型的属性 (JSON -> Property)
 
 Getter: 将数据模型的属性转化为 JSON 数据的键值 (Property -> JSON)
 */
@property (nonatomic, strong) id JSON;

/*!
 初始化
 
 新建一个 MODEL 对象，并将 JSON 数据转化到数据模型的属性
 
 @param JSON 需要解析的 JSON 数据
 
 @return 实例
 */
- (instancetype)initWithJSON:(id)JSON;

/*!
 初始化
 
 新建一个 MODEL 对象，并将 JSON 数据转化到数据模型的属性
 
 @param JSON 需要解析的 JSON 数据
 
 @return 实例
 */
+ (instancetype)modelWithJSON:(id)JSON;

/*!
 初始化
 
 新建一个 MODEL 对象
 
 @return 实例
 */
+ (instancetype)model;

/*!
 设置类名
 
 该方法用于将 JSON 数据中的键转化为数据模型的类名
 
 需要转化的 JSON 数据的键(key) => 字典的键(key)
 
 接收数据的类名 => 字典的值(value)
 
 @return 需要命名的类名列表
 */
- (nonnull NSDictionary<NSString *, NSString *> *)unkeyedContainer;

/*! 更换属性名
 
 该方法用于当 JSON 数据转化为数据模型的属性并遇到了不可用的属性名时，将数据转化到其它的属性
 
 需要换名的 JSON 数据的键(key) => 字典的键(key)
 
 接收数据的 MODEL 的属性(property) => 字典的值(value)
 
 @return 需要更名的属性列表
 */
- (nonnull NSDictionary<NSString *, NSString *> *)codingKeys;

@end

NS_ASSUME_NONNULL_END
