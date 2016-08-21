//
//  CDYahooOAuthWebViewController.m
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import "CDYahooOAuthWebViewController.h"

@implementation CDYahooOAuthWebViewController

#pragma mark - Initialization Methods

- (id)initWithFrame:(CGRect)frame
andAuthorizationURL:(NSURL *)authorizationURL {
    
    if (self = [super init]) {
        self.authorizationWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
        self.authorizationRequest = [NSURLRequest requestWithURL:authorizationURL];
        [self.view addSubview:self.authorizationWebView];
    }
    return self;
}

#pragma mark - UIWebView Methods

- (void)loadRequest {
    [self.authorizationWebView loadRequest:self.authorizationRequest];
}

@end
