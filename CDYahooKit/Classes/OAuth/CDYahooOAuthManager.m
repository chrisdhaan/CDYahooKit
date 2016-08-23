//
//  CDYahooOAuthManager.m
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

#import "CDYahooOAuthManager.h"

static NSString *YahooAPIV2OAuthEndpoint = @"https://api.login.yahoo.com/oauth/v2/";

@interface CDYahooOAuthManager ()

@property (strong, nonatomic) BDBOAuth1SessionManager *oAuthSessionManager;

@property (strong, nonatomic) NSURL *callbackURL;

@end

@implementation CDYahooOAuthManager

#pragma mark - Initialization Methods

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret
              callbackURL:(NSURL *)callbackURL {
    
    if (self = [super init]) {
        
        self.oAuthSessionManager = [[BDBOAuth1SessionManager alloc] initWithBaseURL:[NSURL URLWithString:YahooAPIV2OAuthEndpoint]
                                                                        consumerKey:consumerKey
                                                                     consumerSecret:consumerSecret];
        self.callbackURL = callbackURL;
    }
    return self;
}

#pragma mark - OAuth Methods

- (BOOL)isAuthorized {
    return [self.oAuthSessionManager isAuthorized];
}

- (BOOL)isAuthorizationExpired {
    if (self.oAuthSessionManager.requestSerializer.accessToken && self.oAuthSessionManager.requestSerializer.accessToken.expired) {
        return true;
    }
    return false;
}

- (void)deauthorize {
    [self.oAuthSessionManager deauthorize];
}

- (void)fetchRequestToken {
    [self.oAuthSessionManager fetchRequestTokenWithPath:@"get_request_token"
                                                 method:@"POST"
                                            callbackURL:self.callbackURL
                                                  scope:nil
                                                success:^(BDBOAuth1Credential *requestToken) {
                                                    NSString *authURL = [NSString stringWithFormat:@"%@request_auth?oauth_token=%@", YahooAPIV2OAuthEndpoint, requestToken.token];
                                                    if (self.delegate) {
                                                        [self.delegate didReceiveAuthorization:[NSURL URLWithString:authURL]];
                                                    }
                                                } failure:^(NSError *error) {
                                                    NSLog(@"Fetch Request Token Error: %@", error.localizedDescription);
                                                }];
}

- (void)parseAuthenticationResponse:(NSURLRequest *)authenticationRequest {
    NSString *requestQueryString = authenticationRequest.URL.query;
    BDBOAuth1Credential *requestToken = [BDBOAuth1Credential credentialWithQueryString:requestQueryString];
    [self fetchAccessTokenWithRequestToken:requestToken];
}

- (void)fetchAccessTokenWithRequestToken:(BDBOAuth1Credential *)requestToken {
    [self.oAuthSessionManager fetchAccessTokenWithPath:@"get_token"
                                                method:@"POST"
                                          requestToken:requestToken
                                               success:^(BDBOAuth1Credential *accessToken) {
                                                   [self.oAuthSessionManager.requestSerializer saveAccessToken:accessToken];
                                               } failure:^(NSError *error) {
                                                   NSLog(@"Fetch Access Token Error: %@", error.localizedDescription);
                                               }];
}

- (void)refreshAccessToken {
    [self fetchAccessTokenWithRequestToken:self.oAuthSessionManager.requestSerializer.accessToken];
}

- (NSString *)userGuid {
    BDBOAuth1Credential *accessToken = self.oAuthSessionManager.requestSerializer.accessToken;
    return accessToken.userInfo[@"xoauth_yahoo_guid"] ? accessToken.userInfo[@"xoauth_yahoo_guid"] : @"";
}

@end
