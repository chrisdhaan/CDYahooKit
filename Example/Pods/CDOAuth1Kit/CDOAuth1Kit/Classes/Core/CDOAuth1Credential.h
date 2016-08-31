//
//  CDOAuth1Credential.h
//  Pods
//
//  Created by Christopher de Haan on 8/29/16.
//
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const CDOAuth1OAuthTokenParameter;
FOUNDATION_EXPORT NSString * const CDOAuth1OAuthTokenSecretParameter;
FOUNDATION_EXPORT NSString * const CDOAuth1OAuthVerifierParameter;
FOUNDATION_EXPORT NSString * const CDOAuth1OAuthTokenDurationParameter;

@interface CDOAuth1Credential : NSObject
<NSCoding, NSCopying>

/**
 *  Token ('oauth_token')
 */
@property (nonatomic, copy, readonly) NSString *token;

/**
 *  Token secret ('oauth_token_secret')
 */
@property (nonatomic, copy, readonly) NSString *secret;

/**
 *  Verifier ('oauth_verifier')
 */
@property (nonatomic, copy) NSString *verifier;

/**
 *  Expiration ('oauth_timestamp')
 */
@property (nonatomic) NSDate *expiration;

/**
 *  Check whether or not this token is expired.
 */
@property (nonatomic, assign, readonly, getter = isExpired) BOOL expired;

/**
 *  Additional custom (non-OAuth) parameters included with this credential.
 */
@property (nonatomic) NSDictionary *userInfo;


/**
 *  ---------------------------------------------------------------------------------------
 * @name Initialization
 *  ---------------------------------------------------------------------------------------
 */

#pragma mark - Initialization

/**
 *  Create a new CDOAuth1Credential instance with the given token, token secret, and verifier.
 *
 *  @param token      OAuth token ('oauth_token').
 *  @param secret     OAuth token secret ('oauth_token_secret').
 *  @param expiration Expiration date or nil if the credential does not expire.
 *
 *  @return New CDOAuth1Credential.
 */
+ (instancetype)credentialWithToken:(NSString *)token
                             secret:(NSString *)secret
                         expiration:(NSDate *)expiration;

/**
 *  Instantiate a new CDOAuth1Credential instance with the given token, token secret, and verifier.
 *
 *  @param token      OAuth token ('oauth_token').
 *  @param secret     OAuth token secret ('oauth_token_secret').
 *  @param expiration Expiration date or nil if the credential does not expire.
 *
 *  @return New CDOAuth1Credential.
 */
- (instancetype)initWithToken:(NSString *)token
                       secret:(NSString *)secret
                   expiration:(NSDate *)expiration;

/**
 *  Create a new CDOAuth1Credential instance using parameters in the given URL query string.
 *
 *  @param queryString URL query string containing OAuth token parameters.
 *
 *  @return New CDOAuth1Credential.
 */
+ (instancetype)credentialWithQueryString:(NSString *)queryString;

/**
 *  Instantiate a new CDOAuth1Credential instance using parameters in the given URL query string.
 *
 *  @param queryString URL query string containing OAuth token parameters.
 *
 *  @return New CDOAuth1Credential.
 */
- (instancetype)initWithQueryString:(NSString *)queryString;

@end
