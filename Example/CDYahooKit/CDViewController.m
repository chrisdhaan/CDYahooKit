//
//  CDViewController.m
//  CDYahooKit
//
//  Created by Christopher de Haan on 07/29/2016.
//  Copyright (c) 2016 Christopher de Haan. All rights reserved.
//

#import "CDViewController.h"

#import "CDYahooKitManager.h"
#import "CDYahooOAuthManager.h"
#import "CDYahooOAuthWebViewController.h"

@interface CDViewController () <CDYahooOAuthManagerDelegate, UIWebViewDelegate>

@property (strong, nonatomic) CDYahooKitManager *manager;

@end

@implementation CDViewController

#pragma mark - Initialization Methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.manager = [[CDYahooKitManager alloc] initWithConsumerKey:@"dj0yJmk9S2JNTElkQkxUdlUwJmQ9WVdrOVFreE5ZM1k0TkhVbWNHbzlNQS0tJnM9Y29uc3VtZXJzZWNyZXQmeD05ZQ--"
                                                   consumerSecret:@"fcf6a6eb4dc648bf9738ef1613998a3c8381fd81"];
    [self.manager.oAuthManager setDelegate:self];
    [self.manager.oAuthManager fetchRequestToken];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CDYahooOAuthManager Delegate Methods

- (void)didReceiveAuthorization:(NSURL *)authorizationURL {
    [self displayAuthorizationWebViewForURL:authorizationURL];
}

#pragma mark - UIWebViewDelegate Methods

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType {
    // Check if authorization accepted. Save token verifier and close webView.
    if ([request.URL.absoluteString rangeOfString:@"&oauth_verifier="].location != NSNotFound) {
        
        // Parse and save accessToken
        [self.manager.oAuthManager parseAuthenticationResponse:request];
        // Dismiss OAuthWebViewController
        [self dismissViewControllerAnimated:true completion:nil];
        
        return NO;
    }
    return YES;
}

#pragma mark - Private Methods

- (void)displayAuthorizationWebViewForURL:(NSURL *)authorizationUrl {
    CDYahooOAuthWebViewController *oAuthWebVC = [[CDYahooOAuthWebViewController alloc] initWithFrame:self.view.frame
                                                                                 andAuthorizationURL:authorizationUrl];
    [oAuthWebVC.authorizationWebView setDelegate:self];
    [oAuthWebVC loadRequest];
    [self presentViewController:oAuthWebVC animated:true completion:nil];
}

@end
