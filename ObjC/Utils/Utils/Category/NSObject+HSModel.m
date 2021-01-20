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

#import "NSObject+HSModel.h"
#import "NSObject+HSDebugger.h"
#import <objc/runtime.h>

@implementation NSObject (HSModel)

static const char * const HS_PROPERTYS_ASSOCIATED_OBJECT_KEY = "HS_PROPERTYS_ASSOCIATED_OBJECT_KEY";

@dynamic JSON;

#pragma mark - Life Cycle

// 初始化
- (instancetype)initWithJSON:(id)JSON {
    self.JSON = JSON;
    return [self init];
}

// 初始化
+ (instancetype)modelWithJSON:(id)JSON {
    return [[self alloc] initWithJSON:JSON];
}

// 初始化
+ (instancetype)model {
    return [[self alloc] init];
}

#pragma mark - Setter/Getter Methods

// JSON 数据
- (id)JSON {
    return [self createJSON];
}

// 设置 JSON 数据
- (void)setJSON:(id)JSON {
    [self parseJSON:JSON];
}

#pragma mark - Private Methods

// 创建 JSON
- (NSDictionary *)createJSON {
    // 获取类的所有属性
    NSDictionary *propertys = [self dictionaryWithValuesForKeys:self.propertys];
    
    // 深度读取
    NSMutableDictionary *JSON = [NSMutableDictionary dictionary];
    for (NSString *key in propertys) {
        if ([propertys[key] isKindOfClass:[NSNull class]]) {
            [JSON setValue:nil forKey:key];
        } else if (![NSStringFromClass([propertys[key] class]) hasPrefix:@"NS"] && ![NSStringFromClass([propertys[key] class]) hasPrefix:@"__NS"]) {
            [JSON setValue:[propertys[key] createJSON] forKey:key];
        } else if ([propertys[key] isKindOfClass:[NSArray class]]) {
            NSMutableArray *cls = [propertys[key] mutableCopy];
            [propertys[key] enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                cls[idx] = [obj createJSON];
            }];
            [JSON setValue:cls forKey:key];
        } else {
            [JSON setValue:propertys[key] forKey:key];
        }
    }
    
    return JSON;
}

// 解析 JSON
- (void)parseJSON:(id)JSON {
    NSArray *propertyList = [self propertys];
     
    [JSON enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
        if ([self.codingKeys.allKeys containsObject:key]) {
            key = self.codingKeys[key];
        }
        
        if ([propertyList containsObject:key]) {
            
            // 字典类型
            if ([obj isKindOfClass:NSClassFromString(@"__NSCFDictionary")] || [obj isKindOfClass:[NSDictionary class]]) {
                NSString *ivarType = self.unkeyedContainer[key];
                Class cls = NSClassFromString(ivarType);
                if (cls) {
                    id json = obj;
                    obj = [cls model];
                    [obj parseJSON:json];
                }
            }
            
            // 数组类型
            if ([obj isKindOfClass:NSClassFromString(@"__NSCFArray")] || [obj isKindOfClass:[NSArray class]]) {
                NSString *ivarType = self.unkeyedContainer[key];
                if (!ivarType) ivarType = key;
                Class cls = NSClassFromString(ivarType);
                NSMutableArray *models = [NSMutableArray array];
                for (id json in obj) {
                    if ([json isKindOfClass:NSClassFromString(@"__NSCFDictionary")] || [json isKindOfClass:[NSDictionary class]]) {
                        id model = [cls model];
                        [model parseJSON:json];
                        [models addObject:model];
                    } else {
                        [models addObject:json];
                    }
                }
                obj = models;
            }
            
            // 其它类型
            if (obj) [self setValue:obj forKey:key];
        }
    }];
}



// 获取属性列表
- (NSArray *)propertys {
    NSArray *propertys = objc_getAssociatedObject(self, &HS_PROPERTYS_ASSOCIATED_OBJECT_KEY);
    if (propertys) return propertys;
    
    /**
     * 参数1: 要获取得类
     * 参数2: 类属性的个数指针
     * 返回值: 所有属性的数组, C 语言中, 数组的名字, 就是指向第一个元素的地址
     *
     * 成员变量:
     * class_copyIvarList(__unsafe_unretained Class cls, unsigned int *outCount)
     * 方法:
     * class_copyMethodList(__unsafe_unretained Class cls, unsigned int *outCount)
     * 属性:
     * class_copyPropertyList(__unsafe_unretained Class cls, unsigned int *outCount)
     * 协议:
     * class_copyProtocolList(__unsafe_unretained Class cls, unsigned int *outCount)
     */
    /* retain, creat, copy 需要 release */
    unsigned int count = 0;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    
    NSMutableArray *array = [NSMutableArray array];
    
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property_t = propertyList[i];
        NSString *property = [NSString stringWithCString:property_getName(property_t) encoding:NSUTF8StringEncoding];
        [array addObject:property];
    }
    
    objc_setAssociatedObject(self, &HS_PROPERTYS_ASSOCIATED_OBJECT_KEY, array.copy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    /* 释放 */
    free(propertyList);
    
    return array.copy;
}

#pragma mark - Public Methods

- (NSDictionary *)unkeyedContainer {
    // TODO: Override
    return @{};
}

- (NSDictionary *)codingKeys {
    // TODO: Override
    return @{};
}

@end
