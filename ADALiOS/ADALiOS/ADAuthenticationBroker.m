// Copyright © Microsoft Open Technologies, Inc.
//
// All Rights Reserved
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
// OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
// ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A
// PARTICULAR PURPOSE, MERCHANTABILITY OR NON-INFRINGEMENT.
//
// See the Apache License, Version 2.0 for the specific language
// governing permissions and limitations under the License.

#import "ADOAuth2Constants.h"
#import "UIApplication+ADExtensions.h"
#import "ADAuthenticationContext.h"
#import "ADAuthenticationDelegate.h"
#import "ADAuthenticationWebViewController.h"
#import "ADAuthenticationViewController.h"
#import "ADAuthenticationBroker.h"
#import "ADAuthenticationSettings.h"

NSString *const AD_FAILED_NO_CONTROLLER = @"The Application does not have a current view controller";
NSString *const AD_FAILED_NO_RESOURCES  = @"The required resource bundle could not be loaded. Please read read the ADALiOS readme on how to build your application with ADAL provided authentication UI resources.";
NSString *const AD_IPAD_STORYBOARD = @"ADAL_iPad_Storyboard";
NSString *const AD_IPHONE_STORYBOARD = @"ADAL_iPhone_Storyboard";

// Private interface declaration
@interface ADAuthenticationBroker () <ADAuthenticationDelegate>
@end

// Implementation
@implementation ADAuthenticationBroker
{
    UIViewController* parentController;
    ADAuthenticationViewController    *_authenticationViewController;
    
    NSLock                             *_completionLock;
    BOOL                               _clientTLSSession;
}

#pragma mark Shared Instance Methods

+ (ADAuthenticationBroker *)sharedInstance
{
    static ADAuthenticationBroker *broker     = nil;
    static dispatch_once_t predicate;
    
    dispatch_once( &predicate, ^{
        broker = [[self allocPrivate] init];
    });
    
    return broker;
}

+ (id)alloc
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

+ (id)allocPrivate
{
    return [super alloc];
}

- (id)copy
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)mutableCopy
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - Initialization

- (id)init
{
    self = [super init];
    
    if ( self )
    {
        _completionLock = [[NSLock alloc] init];
        _clientTLSSession = NO;
    }
    
    return self;
}

#pragma mark - Private Methods

// Retrive the bundle containing the resources for the library. May return nil, if the bundle
// cannot be loaded.
+ (NSBundle *)frameworkBundle
{
    static NSBundle       *bundle     = nil;
    static dispatch_once_t predicate;
    
    @synchronized(self)
    {
        dispatch_once( &predicate,
                      ^{
                          NSString* mainBundlePath      = [[NSBundle mainBundle] resourcePath];
                          AD_LOG_VERBOSE_F(@"Resources Loading", @"Attempting to load resources from: %@", mainBundlePath);
                          
                          NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"ADALiOS.bundle"];
                          bundle = [NSBundle bundleWithPath:frameworkBundlePath];
                          if (!bundle)
                          {
                              AD_LOG_INFO_F(@"Resource Loading", @"Failed to load framework bundle. Application main bundle will be attempted.");
                          }
                      });
    }
    
    return bundle;
}

+(NSString*) getStoryboardName
{
    return (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
    ? AD_IPAD_STORYBOARD
    : AD_IPHONE_STORYBOARD;
}

// Retrieve the current storyboard from the resources for the library. Attempts to use ADALiOS bundle first
// and if the bundle is not present, assumes that the resources are build with the application itself.
// Raises an error if both the library resources bundle and the application fail to locate resources.
+ (UIStoryboard *)storyboard: (ADAuthenticationError* __autoreleasing*) error
{
    NSBundle* bundle = [self frameworkBundle];//May be nil.
    if (!bundle)
    {
        //The user did not use ADALiOS.bundle. The resources may be manually linked
        //to the app by referencing the storyboards directly.
        bundle = [NSBundle mainBundle];
    }
    NSString* storyboardName = [self getStoryboardName];
    if ([bundle pathForResource:storyboardName ofType:@"storyboardc"])
    {
        //Despite Apple's documentation, storyboard with name actually throws, crashing
        //the app if the story board is not present, hence the if above.
        UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:storyboardName bundle:bundle];
        if (storyBoard)
            return storyBoard;
    }
    
    ADAuthenticationError* adError = [ADAuthenticationError errorFromAuthenticationError:AD_ERROR_MISSING_RESOURCES protocolCode:nil errorDetails:AD_FAILED_NO_RESOURCES];
    if (error)
    {
        *error = adError;
    }
    return nil;
}

-(NSURL*) addToURL: (NSURL*) url
     correlationId: (NSUUID*) correlationId
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"%@&%@=%@",
                                 [url absoluteString], OAUTH2_CORRELATION_ID_REQUEST_VALUE, [correlationId UUIDString]]];
}

#pragma mark - Public Methods

- (void)start:(NSURL *)startURL
          end:(NSURL *)endURL
parentController:(ViewController *)parent
     webView : (WebViewType *)webView
   fullScreen:(BOOL)fullScreen
correlationId:(NSUUID *)correlationId
   completion:(ADBrokerCallback)completionBlock
{
#pragma unused(fullScreen)
    THROW_ON_NIL_ARGUMENT(startURL);
    THROW_ON_NIL_ARGUMENT(endURL);
    THROW_ON_NIL_ARGUMENT(correlationId);
    THROW_ON_NIL_ARGUMENT(completionBlock)
    //AD_LOG_VERBOSE(@"Authorization", startURL.absoluteString);
    
    startURL = [self addToURL:startURL correlationId:correlationId];//Append the correlation id
    
    // Save the completion block
    _completionBlock = [completionBlock copy];
    ADAuthenticationError* error = nil;
    
    if (webView)
    {
        // Use the application provided WebView
        _authenticationWebViewController = [[ADAuthenticationWebViewController alloc] initWithWebView:webView startAtURL:startURL endAtURL:endURL];
        
        if ( _authenticationWebViewController )
        {
            // Show the authentication view
            _authenticationWebViewController.delegate = self;
            [_authenticationWebViewController start];
        }
        else
        {
            // Dispatch the completion block
            error = [ADAuthenticationError errorFromAuthenticationError:AD_ERROR_MISSING_RESOURCES
                                                           protocolCode:nil
                                                           errorDetails:AD_FAILED_NO_RESOURCES];
        }
    }
    else
    {
        if (!parent)
        {
            // Must have a parent view controller to start the authentication view
            parent = [UIApplication adCurrentViewController];
        }
        if ( parent )
        {
            parentController = parent;
            // Load our resource bundle, find the navigation controller for the authentication view, and then the authentication view
            UINavigationController *navigationController = [[self.class storyboard:&error] instantiateViewControllerWithIdentifier:@"LogonNavigator"];
            
            if (navigationController)
            {
                _authenticationPageController = (ADAuthenticationViewController *)[navigationController.viewControllers objectAtIndex:0];
                
                _authenticationPageController.delegate = self;
                
                if ( fullScreen == YES )
                    [navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
                else
                    [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
                
                // Show the authentication view
                [parent presentViewController:navigationController animated:YES completion:^{
                    // Instead of loading the URL immediately on completion, get the UI on the screen
                    // and then dispatch the call to load the authorization URL
                    dispatch_async( dispatch_get_main_queue(), ^{
                        [_authenticationPageController startWithURL:startURL endAtURL:endURL];
                    });
                }];
            }
            else //Navigation controller
            {
                error = [ADAuthenticationError errorFromAuthenticationError:AD_ERROR_MISSING_RESOURCES
                                                               protocolCode:nil
                                                               errorDetails:AD_FAILED_NO_RESOURCES];
            }
        }
        else
        {
            error = [ADAuthenticationError errorFromAuthenticationError:AD_ERROR_NO_MAIN_VIEW_CONTROLLER
                                                           protocolCode:nil
                                                           errorDetails:AD_FAILED_NO_CONTROLLER];
            
        }
    }
    
    //Error occurred above. Dispatch the callback to the caller:
    if (error)
    {
        dispatch_async( [ADAuthenticationSettings sharedInstance].dispatchQueue, ^{
            _completionBlock( error, nil );
        });
    }
}

- (void)cancel
{
    [self webAuthenticationDidCancel];
}

#pragma mark - Private Methods

- (void)dispatchCompletionBlock:(ADAuthenticationError *)error URL:(NSURL *)url
{
    // NOTE: It is possible that race between a successful completion
    //       and the user cancelling the authentication dialog can
    //       occur causing this method to be called twice. The race
    //       cannot be blocked at its root, and so this method must
    //       be resilient to this condition and should not generate
    //       two callbacks.
    [_completionLock lock];
    if ( _completionBlock )
    {
        if ( _completionBlock )
        {
            void (^completionBlock)( ADAuthenticationError *, NSURL *) = _completionBlock;
            _completionBlock = nil;
            
            dispatch_async( [ADAuthenticationSettings sharedInstance].dispatchQueue, ^{
                completionBlock( error, url );
            });
        }
    }
    
    [_completionLock unlock];
}

#pragma mark - ADAuthenticationDelegate

// The user cancelled authentication
- (void)webAuthenticationDidCancel
{
    @synchronized(self)//Prevent running between cancellation and navigation
    {
        DebugLog();
        
        // Dispatch the completion block
        
        ADAuthenticationError* error = [ADAuthenticationError errorFromCancellation];
        
        if ( _authenticationPageController)
        {
            // Dismiss the authentication view and dispatch the completion block
            [parentController dismissViewControllerAnimated:YES completion:^{
                [self dispatchCompletionBlock:error URL:nil];
            }];
        }
        else
        {
            [_authenticationWebViewController stop];
            [self dispatchCompletionBlock:error URL:nil];
        }
        
        _authenticationPageController    = nil;
        _authenticationWebViewController = nil;
    }
}

// Authentication completed at the end URL
- (void)webAuthenticationDidCompleteWithURL:(NSURL *)endURL
{
    @synchronized(self)//Prevent running between navigation and cancellation
    {
        DebugLog();
        
        if ( nil != _authenticationPageController)
        {
            // Dismiss the authentication view and dispatch the completion block
            [[UIApplication adCurrentViewController] dismissViewControllerAnimated:YES completion:^{
                [self dispatchCompletionBlock:nil URL:endURL];
            }];
        }
        else
        {
            [_authenticationWebViewController stop];
            [self dispatchCompletionBlock:nil URL:endURL];
        }
        
        _authenticationPageController    = nil;
        _authenticationWebViewController = nil;
    }
}

// Authentication failed somewhere
- (void)webAuthenticationDidFailWithError:(NSError *)error
{
    @synchronized(self)//Prevent running between navigation and cancellation
    {
        // Dispatch the completion block
        ADAuthenticationError* adError = [ADAuthenticationError errorFromNSError:error errorDetails:error.localizedDescription];
        
        if ( nil != _authenticationPageController)
        {
            // Dismiss the authentication view and dispatch the completion block
            [[UIApplication adCurrentViewController] dismissViewControllerAnimated:YES completion:^{
                [self dispatchCompletionBlock:adError URL:nil];
            }];
        }
        else
        {
            [_authenticationWebViewController stop];
            [self dispatchCompletionBlock:adError URL:nil];
        }
        
        _authenticationPageController    = nil;
        _authenticationWebViewController = nil;
    }
}

@end
