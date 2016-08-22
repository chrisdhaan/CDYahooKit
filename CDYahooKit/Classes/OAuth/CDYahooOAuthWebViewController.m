//
//  CDYahooOAuthWebViewController.m
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import "CDYahooOAuthWebViewController.h"

@interface CDYahooOAuthWebViewController ()

@property (strong, nonatomic) NSURLRequest *authorizationRequest;

@property (strong, nonatomic) UIActivityIndicatorView *activityIndicatorView;

@end

@implementation CDYahooOAuthWebViewController

#pragma mark - Initialization Methods

- (id)initWithFrame:(CGRect)frame
andAuthorizationURL:(NSURL *)authorizationURL {
    
    if (self = [super init]) {
        // Set controller background color for when web view is hidden
        [self.view setBackgroundColor:[UIColor whiteColor]];
        // Create navigation bar for contorller interaction
        UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, frame.size.height - 44, frame.size.width, 44)];
        [navigationBar setBarStyle:UIBarStyleBlack];
        [navigationBar setBarTintColor:[UIColor colorWithRed:(33.0/255.0) green:(28.0/255.0) blue:(86.0/255.0) alpha:1.0]];
        // Create cancel button to dismiss controller
        UIBarButtonItem *cancelBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                                                style:UIBarButtonItemStylePlain
                                                                               target:self
                                                                               action:@selector(cancelButtonPressed:)];
        [cancelBarButtonItem setTintColor:[UIColor whiteColor]];
        // Add cancel button to navigation item
        UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:@""];
        navigationItem.leftBarButtonItem = cancelBarButtonItem;
        // Add navigation item to navigation bar
        navigationBar.items = @[navigationItem];
        [self.view addSubview:navigationBar];
        // Create loading indicator and start loading animation
        self.activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        self.activityIndicatorView.center = CGPointMake(frame.size.width/2, frame.size.height/2);
        [self.activityIndicatorView setColor:[UIColor colorWithRed:(33.0/255.0) green:(28.0/255.0) blue:(86.0/255.0) alpha:1.0]];
        [self.activityIndicatorView startAnimating];
        [self.view addSubview:self.activityIndicatorView];
        // Create web view, hide web view, and load request
        self.authorizationWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, frame.size.height - 44)];
        self.authorizationWebView.alpha = 0;
        self.authorizationRequest = [NSURLRequest requestWithURL:authorizationURL];
        [self.view addSubview:self.authorizationWebView];
    }
    return self;
}

- (BOOL)prefersStatusBarHidden {
    return true;
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
