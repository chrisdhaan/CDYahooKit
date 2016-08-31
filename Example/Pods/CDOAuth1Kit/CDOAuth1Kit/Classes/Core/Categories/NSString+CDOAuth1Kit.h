//
//  NSString+CDOAuth1Kit.h
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

#import <Foundation/Foundation.h>

/**
 *  Additions to NSString.
 */
@interface NSString (CDOAuth1Kit)

/**
 *  ---------------------------------------------------------------------------------------
 * @name URL Encoding/Decoding
 *  ---------------------------------------------------------------------------------------
 */

#pragma mark - URL Encoding/Decoding

/**
 *  Returns a properly URL-decoded representation of the given string.
 *
 *  See http://cybersam.com/ios-dev/proper-url-percent-encoding-in-ios for more details.
 *
 *  @return URL-decoded string
 */
- (NSString *)cd_URLDecode;

/**
 *  Returns a properly URL-encoded representation of the given string.
 *
 *  See http://cybersam.com/ios-dev/proper-url-percent-encoding-in-ios for more details.
 *
 *  @return URL-encoded string
 */

- (NSString *)cd_URLEncode;


/**
 *  Returns the given string with the '/' and '?' characters URL-encoded.
 *
 *  AFNetworking 2.6 no longer encodes '/' and '?' characters. See https://github.com/AFNetworking/AFNetworking/pull/2908
 *
 *  @return '?' and '/' URL-encoded string
 */
- (NSString *)cd_URLEncodeSlashesAndQuestionMarks;

@end
