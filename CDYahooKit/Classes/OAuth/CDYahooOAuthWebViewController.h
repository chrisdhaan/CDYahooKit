//
//  CDYahooOAuthWebViewController.h
//  Pods
//
//  Created by Christopher de Haan on 8/20/16.
//
//

#import <UIKit/UIKit.h>

@interface CDYahooOAuthWebViewController : UIViewController

@property (strong, nonatomic) UIWebView *authorizationWebView;

- (id)initWithFrame:(CGRect)frame
andAuthorizationURL:(NSURL *)authorizationURL;

- (void)loadRequest;
- (void)displayWebView;

@end
