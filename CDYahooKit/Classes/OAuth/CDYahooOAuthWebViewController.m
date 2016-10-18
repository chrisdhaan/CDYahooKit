//
//  CDYahooOAuthWebViewController.m
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

#import "CDYahooOAuthWebViewController.h"

@interface CDYahooOAuthWebViewController ()

@property (strong, nonatomic) NSURLRequest *authorizationRequest;

@property (weak, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation CDYahooOAuthWebViewController

#pragma mark - Initialization Methods

- (id)initWithFrame:(CGRect)frame
andAuthorizationURL:(NSURL *)authorizationURL {
    
    NSAssert(authorizationURL != nil, @"An authorization URL is required to complete the OAuth 1.0 process for CDYahooKit.");
    
    if (self = [super init]) {
        // Set controller background color for when web view is hidden
        [self.view setBackgroundColor:[UIColor whiteColor]];
        
        // Create cancel button to dismiss controller
        UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(cancelButtonPressed:)];
        [cancelBarButtonItem setTintColor:[UIColor whiteColor]];
        
        // Add cancel button to navigation item
        self.navigationItem.leftBarButtonItem = cancelBarButtonItem;
        
        // Create loading indicator and start loading animation
        UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        activityIndicatorView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        [activityIndicatorView setColor:[UIColor colorWithRed:(33.0/255.0) green:(28.0/255.0) blue:(86.0/255.0) alpha:1.0]];
        [activityIndicatorView startAnimating];
        [self.view addSubview:activityIndicatorView];
        self.activityIndicatorView = activityIndicatorView;
        
        // Create web view, hide web view, and load request
        UIWebView *authorizationWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 64, frame.size.width, frame.size.height - 64)];
        authorizationWebView.alpha = 0;
        [self.view addSubview:authorizationWebView];
        self.authorizationWebView = authorizationWebView;
        
        NSURLRequest *authorizationRequest = [NSURLRequest requestWithURL:authorizationURL];
        self.authorizationRequest = authorizationRequest;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - UIWebView Methods

- (void)loadRequest {
    [self.authorizationWebView loadRequest:self.authorizationRequest];
}

- (void)displayWebView {
    // Stop activity indicator loading animation
    [self.activityIndicatorView stopAnimating];
    // Animate in web view
    [UIView animateWithDuration:0.3 animations:^{
        self.authorizationWebView.alpha = 1.0;
    }];
}

#pragma mark - Button Methods

- (void)cancelButtonPressed:(UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:true completion:nil];
}

@end
