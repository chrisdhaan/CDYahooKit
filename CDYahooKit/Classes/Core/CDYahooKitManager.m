//
//  CDYahooKitManager.m
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import "CDYahooKitManager.h"

#import "CDYahooOAuthManager.h"

@implementation CDYahooKitManager

#pragma mark - Initialization Methods

- (id)initWithConsumerKey:(NSString *)consumerKey
           consumerSecret:(NSString *)consumerSecret {
    
    if (self = [super init]) {
        self.oAuthManager = [[CDYahooOAuthManager alloc] initWithConsumerKey:consumerKey
                                                              consumerSecret:consumerSecret];
    }
    return self;
}

@end
