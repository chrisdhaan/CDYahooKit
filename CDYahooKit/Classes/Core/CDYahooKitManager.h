//
//  CDYahooKitManager.h
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import <Foundation/Foundation.h>

@class CDYahooOAuthManager;

@interface CDYahooKitManager : NSObject

@property (strong, nonatomic) CDYahooOAuthManager *oAuthManager;

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret;

@end
