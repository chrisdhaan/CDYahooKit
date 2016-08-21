//
//  CDYahooOAuthManager.m
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import "CDYahooOAuthManager.h"

static NSString *YahooAPIV2OAuthEndpoint = @"https://api.login.yahoo.com/oauth/v2/";

@interface CDYahooOAuthManager ()

@property (strong, nonatomic) BDBOAuth1Credential *requestToken;

@end

@implementation CDYahooOAuthManager

#pragma mark - Initialization Methods

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret {
    
    if (self = [super init]) {
        
        self.oAuthSessionManager = [[BDBOAuth1SessionManager alloc] initWithBaseURL:[NSURL URLWithString:YahooAPIV2OAuthEndpoint]
                                                                        consumerKey:consumerKey
                                                                     consumerSecret:consumerSecret];
    }
    return self;
}

#pragma mark - OAuth Methods

- (void)fetchRequestToken {
    [self.oAuthSessionManager fetchRequestTokenWithPath:@"get_request_token"
                                                 method:@"POST"
                                            callbackURL:[NSURL URLWithString:@"https://www.christopherdehaan.me"]
                                                  scope:nil
                                                success:^(BDBOAuth1Credential *requestToken) {
                                                    self.requestToken = requestToken;
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
    BDBOAuth1Credential *accessToken = [BDBOAuth1Credential credentialWithQueryString:requestQueryString];
    [self.oAuthSessionManager.requestSerializer saveAccessToken:accessToken];
}

- (void)fetchAccessToken {
    [self.oAuthSessionManager fetchAccessTokenWithPath:@"get_token"
                                                method:@"POST"
                                          requestToken:self.requestToken
                                               success:^(BDBOAuth1Credential *accessToken) {
                                                   NSLog(@"%@", accessToken);
                                               } failure:^(NSError *error) {
                                                   NSLog(@"Fetch Access Token Error: %@", error.localizedDescription);
                                               }];
}

@end
