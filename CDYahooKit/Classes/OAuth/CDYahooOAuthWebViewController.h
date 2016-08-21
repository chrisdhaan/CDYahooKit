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
@property (strong, nonatomic) NSURLRequest *authorizationRequest;

- (id)initWithFrame:(CGRect)frame
andAuthorizationURL:(NSURL *)authorizationURL;

- (void)loadRequest;

@end
