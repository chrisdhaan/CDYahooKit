//
//  CDOAuth1RequestSerializer.h
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

#import <AFNetworking/AFNetworking.h>
#import <CDOAuth1Kit/CDOAuth1Credential.h>

FOUNDATION_EXPORT NSString * const CDOAuth1ErrorDomain;

FOUNDATION_EXPORT NSString * const CDOAuth1OAuthSignatureParameter;
FOUNDATION_EXPORT NSString * const CDOAuth1OAuthCallbackParameter;

@interface CDOAuth1RequestSerializer : AFHTTPRequestSerializer

/**
 *  OAuth request token.
 */
@property (nonatomic, copy) CDOAuth1Credential *requestToken;

/**
 *  OAuth access token.
 */
@property (nonatomic, copy, readonly) CDOAuth1Credential *accessToken;


/**
 *  ---------------------------------------------------------------------------------------
 * @name Initialization
 *  ---------------------------------------------------------------------------------------
 */

#pragma mark - Initialization

/**
 *  Create a new CDOAuth1RequestSerializer instance for the given service with its consumerKey and consumerSecret.
 *
 *  @param service        Service (base URL) this request serializer is used for.
 *  @param consumerKey    OAuth consumer key.
 *  @param consumerSecret OAuth consumer secret.
 *
 *  @return New CDOAuth1RequestSerializer for the specified service.
 */
+ (instancetype)serializerForService:(NSString *)service
                     withConsumerKey:(NSString *)consumerKey
                      consumerSecret:(NSString *)consumerSecret;

/**
 *  Instantiate a new CDOAuth1RequestSerializer instance for the given service with its consumerKey and consumerSecret.
 *
 *  @param service        Service (base URL) this request serializer is used for.
 *  @param consumerKey    OAuth consumer key.
 *  @param consumerSecret OAuth consumer secret.
 *
 *  @return New CDOAuth1RequestSerializer for the specified service.
 */
- (instancetype)initWithService:(NSString *)service
                    consumerKey:(NSString *)consumerKey
                 consumerSecret:(NSString *)consumerSecret;


/**
 *  ---------------------------------------------------------------------------------------
 * @name Storing the Access Token
 *  ---------------------------------------------------------------------------------------
 */
#pragma mark - Storing the Access Token

/**
 *  Save the given OAuth access token in the user's keychain for future use with this serializer's service.
 *
 *  @param accessToken OAuth access token.
 *
 *  @return Success of keychain item add/update operation.
 */
- (BOOL)saveAccessToken:(CDOAuth1Credential *)accessToken;

/**
 *  Remove the access token currently stored in the keychain for this serializer's service.
 *
 *  @return Success of keychain item removal operation.
 */
- (BOOL)removeAccessToken;


/**
 *  ---------------------------------------------------------------------------------------
 * @name OAuth Parameters
 *  ---------------------------------------------------------------------------------------
 */
#pragma mark - OAuth Parameters

/**
 *  Retrieve the set of OAuth parameters to be included in authorized HTTP requests.
 *
 *  @return Dictionary of OAuth parameters.
 */
- (NSDictionary *)OAuthParameters;

@end
