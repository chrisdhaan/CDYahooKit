//
//  NSDictionary+CDOAuth1Kit.m
//  Pods
//
//  Created by Christopher de Haan on 8/28/16.
//
//  Copyright (c) 2016 Christopher de Haan <contact@christopherdehaan.me>
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

#import "NSDictionary+CDOAuth1Kit.h"

#import "NSString+CDOAuth1Kit.h"

@implementation NSDictionary (CDOAuth1Kit)

#pragma mark - Query String

+ (instancetype)cd_dictionaryFromQueryString:(NSString *)queryString {
    NSArray *components = [queryString componentsSeparatedByString:@"&"];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        dictionary[[keyValue[0] cd_URLDecode]] = [keyValue[1] cd_URLDecode];
    }
    
    return [[[self class] alloc] initWithDictionary:dictionary];
}

- (NSString *)cd_queryStringRepresentation {
    NSMutableArray *paramArray = [NSMutableArray array];
    
    [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *param = [NSString stringWithFormat:@"%@=%@", [key cd_URLEncode], [obj cd_URLEncode]];
        [paramArray addObject:param];
    }];
    
    return [paramArray componentsJoinedByString:@"&"];
}

@end
