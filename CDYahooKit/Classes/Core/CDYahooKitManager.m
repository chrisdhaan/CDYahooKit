//
//  CDYahooKitManager.m
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
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

#import "CDYahooKitManager.h"

#import "CDYahooOAuthManager.h"

@implementation CDYahooKitManager

#pragma mark - Initialization Methods

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret
              callbackURL:(NSURL *)callbackURL {
    
    NSAssert(consumerKey != nil && ![consumerKey isEqualToString:@""], @"A consumer key must be provided to utilize CDYahooKit.");
    NSAssert(consumerSecret != nil && ![consumerSecret isEqualToString:@""], @"A consumer secret must be provided to utilize CDYahooKit.");
    NSAssert(callbackURL != nil, @"A callback URL must be provided to utilize CDYahooKit.");
    
    if (self = [super init]) {
        self.oAuthManager = [[CDYahooOAuthManager alloc] initWithConsumerKey:consumerKey
                                                              consumerSecret:consumerSecret
                                                                 callbackURL:callbackURL];
    }
    return self;
}

@end
