//
//  NSString+CDOAuth1Kit.m
//  Pods
//
//  Created by Christopher de Haan on 8/28/16.
//
//  Copyright (c) 2016 Christopher de Haan <chrisdhaan@gmail.com>
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

#import <CommonCrypto/CommonDigest.h>

#import "NSString+CDOAuth1Kit.h"

@implementation NSString (CDOAuth1Kit)

#pragma mark - URL Encoding/Decoding

- (NSString *)cd_URLEncode {
    return (__bridge_transfer NSString *)
    CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                            (__bridge CFStringRef)self,
                                            NULL,
                                            (__bridge CFStringRef)@"!*'\"();:@&=+$,/?%#[] ",
                                            kCFStringEncodingUTF8);
}

- (NSString *)cd_URLDecode {
    return (__bridge_transfer NSString *)
    CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                            (__bridge CFStringRef)self,
                                                            (__bridge CFStringRef)@"",
                                                            kCFStringEncodingUTF8);
}

- (NSString *)cd_URLEncodeSlashesAndQuestionMarks {
    NSString *selfWithSlashesEscaped = [self stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
    NSString *selfWithQuestionMarksEscaped = [selfWithSlashesEscaped stringByReplacingOccurrencesOfString:@"?" withString:@"%3F"];
    return selfWithQuestionMarksEscaped;
}

@end
