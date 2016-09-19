//
//  CDOAuth1SessionManager.m
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

#import "CDOAuth1SessionManager.h"

#import "CDOAuth1ErrorCode.h"
#import "NSDictionary+CDOAuth1Kit.h"

// Exported
NSString * const CDOAuth1BadRequestTokenErrorKey            = @"CDOAuth1BadRequestTokenKey";
NSString * const CDOAuth1BadRequestTokenErrorDescription    = @"An invalid request token was passed to the server.";
NSString * const CDOAuth1BadAccessTokenErrorKey             = @"CDOAuth1BadAccessTokenKey";
NSString * const CDOAuth1BadAccessTokenErrorDescription     = @"An invalid expired access token was passed to the server.";

@implementation CDOAuth1SessionManager

@dynamic requestSerializer;

#pragma mark - Initialization

- (instancetype)initWithBaseURL:(NSURL *)baseURL
                    consumerKey:(NSString *)consumerKey
                 consumerSecret:(NSString *)consumerSecret {
    
    NSAssert(baseURL != nil, @"A base URL is traditionally required when interacting with an OAuth 1.0 API. If none is needed in this case, pass in a NSURL object with an empty string.");
    NSAssert(consumerKey != nil, @"A consumer key is traditionally required when interacting with an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(consumerSecret != nil, @"A consumer secret is traditionally required when interacting with an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    
    self = [super initWithBaseURL:baseURL];
    
    if (self) {
        self.requestSerializer  = [CDOAuth1RequestSerializer serializerForService:baseURL.host
                                                                  withConsumerKey:consumerKey
                                                                   consumerSecret:consumerSecret];
    }
    
    return self;
}

#pragma mark - Authorization Status

- (BOOL)isAuthorized {
    return (self.requestSerializer.accessToken && !self.requestSerializer.accessToken.expired);
}

- (BOOL)deauthorize {
    return [self.requestSerializer removeAccessToken];
}

#pragma mark - OAuth Handshake

- (void)fetchRequestTokenWithPath:(NSString *)requestPath
                           method:(NSString *)method
                      callbackURL:(NSURL *)callbackURL
                            scope:(NSString *)scope
                          success:(void (^)(CDOAuth1Credential *requestToken))success
                          failure:(void (^)(NSError *error))failure {
    
    NSAssert(requestPath != nil, @"A unique URL path is traditionally required when fetching a request token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(method != nil, @"A method type [POST, GET, etc...] is traditionally required when fetching a request token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(callbackURL != nil, @"A callback URL is traditionally required when fetching a request token from an OAuth 1.0 API. If none is needed in this case, pass in a NSURL object with an empty string.");
    
    self.requestSerializer.requestToken = nil;
    
    AFHTTPResponseSerializer *defaultSerializer = self.responseSerializer;
    self.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NSMutableDictionary *parameters = [[self.requestSerializer OAuthParameters] mutableCopy];
    parameters[CDOAuth1OAuthCallbackParameter] = [callbackURL absoluteString];
    
    if (scope && !self.requestSerializer.accessToken) {
        parameters[@"scope"] = scope;
    }
    
    NSString *URLString = [[NSURL URLWithString:requestPath relativeToURL:self.baseURL] absoluteString];
    NSError *error;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:&error];
    
    if (error) {
        failure(error);
        
        return;
    }
    
    void (^completionBlock)(NSURLResponse * __unused, id, NSError *) = ^(NSURLResponse * __unused response, id responseObject, NSError *completionError) {
        self.responseSerializer = defaultSerializer;
        
        if (completionError) {
            failure(completionError);
            
            return;
        }
        
        CDOAuth1Credential *requestToken = [CDOAuth1Credential credentialWithQueryString:[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]];
        self.requestSerializer.requestToken = requestToken;
        
        success(requestToken);
    };
    
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:completionBlock];
    [task resume];
}

- (void)fetchAccessTokenWithPath:(NSString *)accessPath
                          method:(NSString *)method
                    requestToken:(CDOAuth1Credential *)requestToken
                         success:(void (^)(CDOAuth1Credential *accessToken))success
                         failure:(void (^)(NSError *error))failure {
    
    NSAssert(accessPath != nil, @"A unique URL path is traditionally required when fetching an access token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(method != nil, @"A method type [POST, GET, etc...] is traditionally required when fetching an access token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(requestToken != nil, @"A request token is required when fetching an access token from an OAuth 1.0 API.");
    
    if (!requestToken.token || !requestToken.verifier) {
        NSError *error = [[NSError alloc] initWithDomain:CDOAuth1ErrorDomain
                                                    code:CDOAuth1BadRequestTokenErrorCode
                                                userInfo:@{CDOAuth1BadRequestTokenErrorKey:CDOAuth1BadRequestTokenErrorDescription}];
        
        failure(error);
        
        return;
    }
    
    AFHTTPResponseSerializer *defaultSerializer = self.responseSerializer;
    self.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NSMutableDictionary *parameters = [[self.requestSerializer OAuthParameters] mutableCopy];
    parameters[CDOAuth1OAuthTokenParameter]    = requestToken.token;
    parameters[CDOAuth1OAuthVerifierParameter] = requestToken.verifier;
    
    NSString *URLString = [[NSURL URLWithString:accessPath relativeToURL:self.baseURL] absoluteString];
    NSError *error;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:&error];
    
    if (error) {
        failure(error);
        
        return;
    }
    
    void (^completionBlock)(NSURLResponse * __unused, id, NSError *) = ^(NSURLResponse * __unused response, id responseObject, NSError *completionError) {
        self.responseSerializer = defaultSerializer;
        self.requestSerializer.requestToken = nil;
        
        if (completionError) {
            failure(completionError);
            
            return;
        }
        
        CDOAuth1Credential *accessToken = [CDOAuth1Credential credentialWithQueryString:[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]];
        [self.requestSerializer saveAccessToken:accessToken];
        
        success(accessToken);
    };
    
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:completionBlock];
    [task resume];
}

- (void)refreshAccessTokenWithPath:(NSString *)accessPath
                        parameters:(NSDictionary *)parameters
                            method:(NSString *)method
                       accessToken:(CDOAuth1Credential *)accessToken
                           success:(void (^)(CDOAuth1Credential *))success
                           failure:(void (^)(NSError *))failure {
    
    NSAssert(accessPath != nil, @"A unique URL path is traditionally required when refreshing an access token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(method != nil, @"A method type [POST, GET, etc...] is traditionally required when refreshing an access token from an OAuth 1.0 API. If none is needed in this case, pass in an empty string.");
    NSAssert(accessToken != nil, @"An expired access token is required when refreshing an access token from an OAuth 1.0 API.");
    
    if (!accessToken.token) {
        NSError *error = [[NSError alloc] initWithDomain:CDOAuth1ErrorDomain
                                                    code:CDOAuth1BadAccessTokenErrorCode
                                                userInfo:@{CDOAuth1BadAccessTokenErrorKey:CDOAuth1BadAccessTokenErrorDescription}];
        
        failure(error);
        
        return;
    }
    
    AFHTTPResponseSerializer *defaultSerializer = self.responseSerializer;
    self.responseSerializer = [AFHTTPResponseSerializer serializer];
    
    NSString *URLString = [[NSURL URLWithString:accessPath relativeToURL:self.baseURL] absoluteString];
    NSError *error;
    NSMutableURLRequest *request = [self.requestSerializer requestWithMethod:method URLString:URLString parameters:parameters error:&error];
    
    if (error) {
        failure(error);
        
        return;
    }
    
    void (^completionBlock)(NSURLResponse * __unused, id, NSError *) = ^(NSURLResponse * __unused response, id responseObject, NSError *completionError) {
        self.responseSerializer = defaultSerializer;
        self.requestSerializer.requestToken = nil;
        
        if (completionError) {
            failure(completionError);
            
            return;
        }
        
        CDOAuth1Credential *accessToken = [CDOAuth1Credential credentialWithQueryString:[[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]];
        [self.requestSerializer saveAccessToken:accessToken];
        
        success(accessToken);
    };
    
    NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:completionBlock];
    [task resume];
}

@end
