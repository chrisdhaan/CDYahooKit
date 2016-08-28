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

@property (strong, nonatomic) CDYahooOAuthWebViewController *oAuthWebVC;

@end

@implementation CDViewController

#pragma mark - Initialization Methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.manager = [[CDYahooKitManager alloc] initWithConsumerKey:@"<YOUR CONSUMER KEY>"
                                                   consumerSecret:@"<YOUR CONSUMER SECRET>"
                                                      callbackURL:[NSURL URLWithString:@"<YOUR CALLBACK URL>"]];
    [self.manager.oAuthManager setDelegate:self];
//    [self.manager.oAuthManager deauthorize];
    if ([self.manager.oAuthManager isAuthorized] == false) {
        NSLog(@"User is not authorized through Yahoo");
        [self.manager.oAuthManager fetchRequestToken];
    } else if ([self.manager.oAuthManager isAuthorizationExpired] == true) {
        NSLog(@"User authorization has expired");
        [self.manager.oAuthManager refreshAccessToken];
    } else {
        NSLog(@"%@", [self.manager.oAuthManager userGuid]);
    }
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

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self.oAuthWebVC displayWebView];
}

#pragma mark - Private Methods

- (void)displayAuthorizationWebViewForURL:(NSURL *)authorizationUrl {
    self.oAuthWebVC = [[CDYahooOAuthWebViewController alloc] initWithFrame:self.view.frame
                                                                                 andAuthorizationURL:authorizationUrl];
    [self.oAuthWebVC.authorizationWebView setDelegate:self];
    [self.oAuthWebVC loadRequest];
    [self presentViewController:self.oAuthWebVC animated:true completion:nil];
}

@end
