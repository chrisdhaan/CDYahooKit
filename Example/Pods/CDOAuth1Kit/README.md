# CDOAuth1Kit

[![CI Status](http://img.shields.io/travis/chrisdhaan/CDOAuth1Kit.svg?style=flat)](https://travis-ci.org/chrisdhaan/CDOAuth1Kit)
[![Version](https://img.shields.io/cocoapods/v/CDOAuth1Kit.svg?style=flat)](http://cocoapods.org/pods/CDOAuth1Kit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![License](https://img.shields.io/cocoapods/l/CDOAuth1Kit.svg?style=flat)](http://cocoapods.org/pods/CDOAuth1Kit)
[![Platform](https://img.shields.io/cocoapods/p/CDOAuth1Kit.svg?style=flat)](http://cocoapods.org/pods/CDOAuth1Kit)

This pod is currently in development. As of release 0.9.0 the code is stable and in a usable state to install in applications.

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

---

## Requirements

- iosSDK: 8.0

---

## Installation

### Installation via CocoaPods

CDOAuth1Kit is available through [CocoaPods](http://cocoapods.org). CocoaPods is a dependency manager that automates and simplifies the process of using 3rd-party libraries like CDOAuth1Kit in your projects. You can install CocoaPods with the following command:

```ruby
gem install cocoapods
```

To integrate CDOAuth1Kit into your Xcode project using CocoaPods, simply add the following line to your Podfile:

```ruby
pod "CDOAuth1Kit"
```

Afterwards, run the following command:

```ruby
pod install
```

### Installation via Carthage

CDOAuth1Kit is available through [Carthage](https://github.com/Carthage/Carthage). Carthage is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

You can install Carthage via [Homebrew](http://brew.sh) with the following command:

```ruby
brew update
brew install carthage
```

To integrate CDOAuth1Kit into your Xcode project using Carthage, simply add the following line to your Cartfile:

```ruby
github "chrisdhaan/CDOAuth1Kit
```

Afterwards, run the following command:

```ruby
carthage update
```

## Usage

### Initialization

Prior to using CDOAuth1Kit you will want to register your application with whichever API you are looking to gain OAuth 1.0 authorization from. Traditionally, you will provide some basic application information (name, description, etc.) and a **callback URL**, which will be used during the OAuth process. A callback URL can be either a web URL (https://www.myapplicationwebsite.com) or a mobile callback URL (myApplicationName://oauthRequest). Instructions for creating a mobile callback URL can be found below. After your application is approved, the API will provide a **consumer key** and a **consumer secret**, both of which will be used during the OAuth process.

```objective-c
NSURL *apiOAuthURL = [NSURL URLWithString:@"https://api.login.thisisafakeurl.com/oauth"]
self.oAuth1SessionManager = [[CDOAuth1SessionManager alloc] initWithBaseURL:[NSURL URLWithString:apiOAuthURL]
                                                                consumerKey:consumerKey
                                                             consumerSecret:consumerSecret];
```

Once you've created a CDOAuth1SessionManager object you can request authorization from the API that you registered your application with. 

### Defining an OAuth Callback URL

The snapshot below displays how to define a mobile callback URL in Xcode.

![Alt text](/README.md.assets/mobileCallbackURL.jpg?raw=true "")

### OAuth Handshake

The first step of the OAuth 1.0 authorization process requires the application to recieve an OAuth request token from the API. The following method is used to acquire an OAuth request token.

```objective-c
[self.oAuth1SessionManager fetchRequestTokenWithPath:@"get_request_token"
                                              method:@"POST"
                                         callbackURL:@"myApplicationName://oauthRequest"
                                               scope:nil
                                             success:^(CDOAuth1Credential *requestToken) {
                                               NSString *authURL = [NSString stringWithFormat:@"https://api.login.thisisafakeurl.com/oauth/authorize?oauth_token=%@", requestToken.token];
                                               [[UIApplication sharedApplication] openURL:[NSURL URLWithString:authURL]];
                                           } failure:^(NSError *error) {
                                               NSLog(@"Fetch Request Token Error: %@", error.localizedDescription);
                                           }];
```

After successfully receiving an OAuth request token from the API, you can then allow the user to authorize your application to retrieve data via the API by displaying the API's OAuth authorization web page. Traditionally, the URL will expect the request token as a parameter.

### Responding to the OAuth Callback URL

Once the user has authorized your application, the API's OAuth authorization web page will redirect to the OAuth callback URL you provided when registering your application with the API. The callback URL will trigger the following method in your applications AppDelegate class.

```objective-c
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    // Handle response
}
```

You will have to add the above method to your applications AppDelegate class as it is not one of the pre-defined methods added during application creation. The next step of the OAuth process requires the application to receive an OAuth access token from the API. The following lines of code can be used to acquire an OAuth access token (this would replace **// Handle response** in the above method).

```objective-c
// Check that the url that opened your application was the OAuth callback URL
if ([CDOAuth1Helper isAuthorizationCallbackURL:url
                             callbackURLScheme:@"myApplicationName"
                               callbackURLHost:@"oauthRequest"] == YES) {
    // Get the request token from the OAuth callback URL query parameters
    CDOAuth1Credential *requestToken = [CDOAuth1Credential credentialWithQueryString:url.query];
    // Request an OAuth access token
    [self.oAuth1SessionManager fetchAccessTokenWithPath:@"get_token"
                                                method:@"POST"
                                          requestToken:requestToken
                                               success:^(CDOAuth1Credential *accessToken) {
                                                 [self.oAuth1SessionManager.requestSerializer saveAccessToken:accessToken];
                                             } failure:^(NSError *error) {
                                                 NSLog(@"Fetch Access Token Error: %@", error.localizedDescription);
                                             }];
    return YES;                          
} else {
    return NO;
}
```

After successfully receiving an OAuth access token from the API, you will be able to retrieve data by using the CDOAuth1SessionManager object to query the API's respective endpoints.

### Refreshing an OAuth Token

Most API's will set an expiration date on the OAuth access token. Once the OAuth access token has expired a new one is needed to continue successfully retreiving data from the API. The following method is used to refresh an OAuth access token.

```objective-c
// Get the expired OAuth access token
CDOAuth1Credential *accessToken = self.oAuth1SessionManager.requestSerializer.accessToken;
// Add any additional parameters required by the API to refresh the OAuth access token.
NSDictionary *parameters = @{
                             @"oauth_session_handle": accessToken.userInfo[@"oauth_session_handle"]
                             };
// Refresh the OAuth access token
[self.oAuth1SessionManager refreshAccessTokenWithPath:@"get_token"
                                           parameters:parameters
                                               method:@"POST"
                                          accessToken:accessToken
                                              success:^(CDOAuth1Credential *accessToken) {
                                                [self.oAuth1SessionManager.requestSerializer saveAccessToken:accessToken];
                                            } failure:^(NSError *error) {
                                                NSLog(@"Refresh Access Token Error: %@", error.localizedDescription);
                                            }];
```

After successfully receiving the refreshed OAuth access token from the API, you can continue to retrieve data by using the CDOAuth1SessionManager object to query the API's respective endpoints.

---

## Author

Christopher de Haan, contact@christopherdehaan.me

## Credits

CDOAuth1Kit was influenced by [BDBOAuth1SessionManager](https://github.com/bdbergeron/BDBOAuth1Manager), an OAuth 1.0 library developed by [Bradley David Bergeron](https://www.bradbergeron.com).

## License

CDOAuth1Kit is available under the MIT license. See the LICENSE file for more info.

---
