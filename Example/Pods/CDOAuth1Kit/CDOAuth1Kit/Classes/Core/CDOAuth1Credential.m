//
//  CDOAuth1Credential.m
//  Pods
//
//  Created by Christopher de Haan on 8/29/16.
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

#import "CDOAuth1Credential.h"

#import "NSDictionary+CDOAuth1Kit.h"

// Exported
NSString * const CDOAuth1OAuthTokenParameter           = @"oauth_token";
NSString * const CDOAuth1OAuthTokenSecretParameter     = @"oauth_token_secret";
NSString * const CDOAuth1OAuthVerifierParameter        = @"oauth_verifier";
NSString * const CDOAuth1OAuthTokenDurationParameter   = @"oauth_token_duration";

@interface CDOAuth1Credential ()

@property (nonatomic, copy, readwrite) NSString *token;
@property (nonatomic, copy, readwrite) NSString *secret;

@end

@implementation CDOAuth1Credential

#pragma mark - Initialization

+ (instancetype)credentialWithToken:(NSString *)token
                             secret:(NSString *)secret
                         expiration:(NSDate *)expiration {
    return [[[self class] alloc] initWithToken:token
                                        secret:secret
                                    expiration:expiration];
}

- (instancetype)initWithToken:(NSString *)token
                       secret:(NSString *)secret
                   expiration:(NSDate *)expiration {
    NSParameterAssert(token);
    
    self = [super init];
    
    if (self) {
        _token = token;
        _secret = secret;
        _expiration = expiration;
    }
    
    return self;
}

+ (instancetype)credentialWithQueryString:(NSString *)queryString {
    return [[[self class] alloc] initWithQueryString:queryString];
}

- (instancetype)initWithQueryString:(NSString *)queryString {
    NSDictionary *attributes = [NSDictionary cd_dictionaryFromQueryString:queryString];
    
    NSString *token    = attributes[CDOAuth1OAuthTokenParameter];
    NSString *secret   = attributes[CDOAuth1OAuthTokenSecretParameter];
    NSString *verifier = attributes[CDOAuth1OAuthVerifierParameter];
    
    NSDate *expiration = nil;
    
    if (attributes[CDOAuth1OAuthTokenDurationParameter]) {
        expiration = [NSDate dateWithTimeIntervalSinceNow:[attributes[CDOAuth1OAuthTokenDurationParameter] doubleValue]];
    }
    
    self = [self initWithToken:token secret:secret expiration:expiration];
    
    if (self) {
        _verifier = verifier;
        
        NSMutableDictionary *mutableUserInfo = [attributes mutableCopy];
        [mutableUserInfo removeObjectsForKeys:@[CDOAuth1OAuthTokenParameter,
                                                CDOAuth1OAuthTokenSecretParameter,
                                                CDOAuth1OAuthVerifierParameter,
                                                CDOAuth1OAuthTokenDurationParameter]];
        
        if (mutableUserInfo.count > 0) {
            _userInfo = [NSDictionary dictionaryWithDictionary:mutableUserInfo];
        }
    }
    
    return self;
}

#pragma mark - Properties

- (BOOL)isExpired {
    if (!self.expiration) {
        return NO;
    } else {
        return [self.expiration compare:[NSDate date]] == NSOrderedAscending;
    }
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    
    if (self) {
        _token      = [decoder decodeObjectForKey:NSStringFromSelector(@selector(token))];
        _secret     = [decoder decodeObjectForKey:NSStringFromSelector(@selector(secret))];
        _verifier   = [decoder decodeObjectForKey:NSStringFromSelector(@selector(verifier))];
        _expiration = [decoder decodeObjectForKey:NSStringFromSelector(@selector(expiration))];
        _userInfo   = [decoder decodeObjectForKey:NSStringFromSelector(@selector(userInfo))];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.token forKey:NSStringFromSelector(@selector(token))];
    [coder encodeObject:self.secret forKey:NSStringFromSelector(@selector(secret))];
    [coder encodeObject:self.verifier forKey:NSStringFromSelector(@selector(verifier))];
    [coder encodeObject:self.expiration forKey:NSStringFromSelector(@selector(expiration))];
    [coder encodeObject:self.userInfo forKey:NSStringFromSelector(@selector(userInfo))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CDOAuth1Credential *copy = [[[self class] allocWithZone:zone] initWithToken:self.token
                                                                         secret:self.secret
                                                                     expiration:self.expiration];
    copy.verifier = self.verifier;
    copy.userInfo = self.userInfo;
    
    return copy;
}

@end
