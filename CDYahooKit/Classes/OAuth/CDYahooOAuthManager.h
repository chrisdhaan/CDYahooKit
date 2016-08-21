//
//  CDYahooOAuthManager.h
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import <Foundation/Foundation.h>

#import <BDBOAuth1Manager/BDBOAuth1SessionManager.h>

@protocol CDYahooOAuthManagerDelegate <NSObject>

@required
- (void)didReceiveAuthorization:(NSURL *)authorizationURL;

@end

@interface CDYahooOAuthManager : NSObject

@property (strong, nonatomic) BDBOAuth1SessionManager *oAuthSessionManager;

@property (nonatomic, weak) id<CDYahooOAuthManagerDelegate> delegate;

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret;
- (void)fetchRequestToken;
- (void)parseAuthenticationResponse:(NSURLRequest *)authenticationRequest;
- (void)fetchAccessToken;

@end
