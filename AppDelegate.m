/*
 Copyright (c) 2011, salesforce.com, inc. All rights reserved.
 
 Redistribution and use of this software in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice, this list of
 conditions and the following disclaimer in the documentation and/or other materials provided
 with the distribution.
 * Neither the name of salesforce.com, inc. nor the names of its contributors may be used to
 endorse or promote products derived from this software without specific prior written
 permission of salesforce.com, inc.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
 FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
 WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#import "InitialViewController.h"
#import "SFAccountManager.h"
#import "SFOAuthInfo.h"
#import "SFLogger.h"
#import "DataSynchronizationManager.h"
#import "HomeViewController.h"
#import "TWTSideMenuViewController.h"
#import "LeftMenuViewController.h"
#import "OperationPaperclipFacade.h"
#import "SFDCManager.h"
#import "SFAuthErrorHandler.h"
#import "SFAuthErrorHandlerList.h"
#import "TaskScheduleManager.h"
#import <GD/GDURLRequestConnectionDelegate.h>
#import <GD/UIWebView+GDNET.h>

// Fill these in when creating a new Connected Application on Force.com
static NSString * const RemoteAccessConsumerKey = @"3MVG9rFJvQRVOvk60UWkhYViZTBbCiU0YZn2P4kY_H6rPKlU5_Uf2TAI6cos7JtZHUUogheN4hRgfuYGx_.Zn";
static NSString * const OAuthRedirectURI        = @"sfdc://success";

@interface AppDelegate () <UIAlertViewDelegate, GDURLRequestConnectionDelegate>

/**
 * Success block to call when authentication completes.
 */
@property (nonatomic, copy) SFOAuthFlowSuccessCallbackBlock initialLoginSuccessBlock;

/**
 * Failure block to calls if authentication fails.
 */
@property (nonatomic, copy) SFOAuthFlowFailureCallbackBlock initialLoginFailureBlock;


/**
 * Data Synchronization Manager Properties.
 */

@property (nonatomic) BOOL authenticatedWithGD;

@property (nonatomic) BOOL authenticatedWithSFDC;

@property (nonatomic) BOOL acceptUntrustedCertificate;

/**
 * Handles the notification from SFAuthenticationManager that a logout has been initiated.
 * @param notification The notification containing the details of the logout.
 */
- (void)logoutInitiated:(NSNotification *)notification;

/**
 * Handles the notification from SFAuthenticationManager that the login host has changed in
 * the Settings application for this app.
 * @param The notification whose userInfo dictionary contains:
 *        - kSFLoginHostChangedNotificationOriginalHostKey: The original host, prior to host change.
 *        - kSFLoginHostChangedNotificationUpdatedHostKey: The updated (new) login host.
 */
- (void)loginHostChanged:(NSNotification *)notification;

/**
 * Convenience method for setting up the main UIViewController and setting self.window's rootViewController
 * property accordingly.
 */
- (void)setupRootViewController:(NSNotification *) notification;

/**
 * (Re-)sets the view state when the app first loads (or post-logout).
 */
- (void)initializeAppViewState;



/*
 *   Menu properties
 *
 */
@property (nonatomic, strong) TWTSideMenuViewController *sideMenuViewController;
@property (nonatomic, strong) LeftMenuViewController *menuViewController;
@property (nonatomic, strong) HomeViewController *mainViewController;




@end

void PaperclipUncaughtExceptionHandler(NSException *exception)
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths firstObject];
    NSString *descriptionFile = [documentDirectory stringByAppendingPathComponent:@"PaperclipExceptionDescription"];
    NSString *symbolsFile = [documentDirectory stringByAppendingPathComponent:@"PaperclipExceptionSymbols"];
    [[exception description] writeToFile:descriptionFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    [[exception callStackSymbols] writeToFile:symbolsFile atomically:YES];
}

@implementation AppDelegate

@synthesize initialLoginSuccessBlock = _initialLoginSuccessBlock;
@synthesize initialLoginFailureBlock = _initialLoginFailureBlock;

- (id)init
{
    self = [super init];
    if (self) {
        started = NO;
        authorized = NO;
        
        [self registerDefaultsFromSettingsBundle];
        
        [SFLogger setLogLevel:SFLogLevelDebug];
        
        // These SFAccountManager settings are the minimum required to identify the Connected App.
        [SFAccountManager setClientId:RemoteAccessConsumerKey];
        [SFAccountManager setRedirectUri:OAuthRedirectURI];
        [SFAccountManager setScopes:[NSSet setWithObjects:@"api", nil]];
        
        // Logout and login host change handlers.
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logoutInitiated:) name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginHostChanged:) name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSFDCError:) name:@"HandleSFDCError" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unauthorizedError:) name:@"UnauthorizedError" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(signOutFromSalesforce:) name:@"SignOutFromSFDC" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncNotification:) name:@"SyncNotification" object:nil];
        
        // Blocks to execute once authentication has completed.  You could define these at the different boundaries where
        // authentication is initiated, if you have specific logic for each case.
        __weak AppDelegate *weakSelf = self;
        self.initialLoginSuccessBlock = ^(SFOAuthInfo *info) {
            // register to handle SFDC errors
            weakSelf.authenticatedWithSFDC = YES;
            weakSelf.authenticatedWithGD = YES;
            [weakSelf scheduleDataSyncCheckTables:YES];
        };
        self.initialLoginFailureBlock = ^(SFOAuthInfo *info, NSError *error) {
            [[SFAuthenticationManager sharedManager] logout];
        };
        
        // reachability handler
        reachability = [Reachability reachabilityForInternetConnection];
        self.networkAvailable = [reachability isReachable];
        reachability.reachableBlock = ^(Reachability *reach)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.networkAvailable = YES;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkConnectionChanged" object:nil];
            });
        };
        reachability.unreachableBlock = ^(Reachability *reach)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                weakSelf.networkAvailable = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"NetworkConnectionChanged" object:nil];
            });
        };
        [reachability startNotifier];
        self.acceptUntrustedCertificate = NO;
    }
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFUserLogoutNotification object:[SFAuthenticationManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSFLoginHostChangedNotification object:[SFAuthenticationManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"HandleSFDCError" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UnauthorizedError" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SignOutFromSFDC" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SyncNotification" object:nil];
}

#pragma mark - App delegate lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[GDiOS sharedInstance] getWindow];
    self.gdLibrary = [GDiOS sharedInstance];
    self.gdLibrary.delegate = self;
    started = NO;
    authorized = NO;
    
    //This allows you to present a customize Good Activation and Password screen for the application. You can look
    //up the API at:
    //https://begood.good.com/view-doc.jspa?fileName=interface_g_di_o_s.html#a77bf1bd804c91f8c311b92662d7c9d54

    
    [self.gdLibrary configureUIWithLogo:@"WFIBCM_Mobile_GD.png" bundle:[NSBundle mainBundle] color:[UIColor darkGrayColor] ];
    
    
    NSSetUncaughtExceptionHandler(&PaperclipUncaughtExceptionHandler);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = [paths firstObject];
    NSString *descriptionFile = [documentDirectory stringByAppendingPathComponent:@"PaperclipExceptionDescription"];
    NSString *symbolsFile = [documentDirectory stringByAppendingPathComponent:@"PaperclipExceptionSymbols"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:descriptionFile] && [[NSFileManager defaultManager] fileExistsAtPath:symbolsFile]) {
        NSString *exceptionDescription = [NSString stringWithContentsOfFile:descriptionFile encoding:NSUTF8StringEncoding error:NULL];
        NSArray *symbolsArray = [NSArray arrayWithContentsOfFile:symbolsFile];
        if (exceptionDescription && symbolsArray) {
            @try {
                [[OperationPaperclipFacade sharedInstance] logDataEvent:@"Crash" payload:symbolsArray object:@"App" isSuccess:NO errorMsgs:exceptionDescription];
            }
            @catch (NSException *exception) {
                NSLog(@"%@", exception.description);
            }
        }
        [[NSFileManager defaultManager] removeItemAtPath:descriptionFile error:NULL];
        [[NSFileManager defaultManager] removeItemAtPath:symbolsFile error:NULL];
    }
    
    [SFAuthenticationManager sharedManager].useSnapshotView = NO;
    
    [self.gdLibrary authorize];
    
    return YES;
}

-(void)applicationDidBecomeActive:(UIApplication *)application
{
    [self scheduleDataSyncCheckTables:NO];
    
    // restore recent items
    if (recentItems != nil && recentItems.count > 0) {
        [self.menuViewController.recentItems removeAllObjects];
        [self.menuViewController.recentItems addObjectsFromArray:recentItems];
        [self.menuViewController.tableView reloadData];
        [recentItems removeAllObjects];
        recentItems = nil;
    }
}


-(void)applicationDidEnterBackground:(UIApplication *)application
{
    // stash recent items
    recentItems = [self.menuViewController.recentItems mutableCopy];
    [[TaskScheduleManager sharedInstance] pauseTimer];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"resigningActive" object:nil];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"terminating" object:nil];
}

#pragma mark - GD Delegate

#pragma mark - Memory management
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    // Free up as much memory as possible by purging cached data objects that can be recreated
    // (or reloaded from disk) later.
}

//When using an Application Policy, a check must be made to be sure that the Application Policy Settings have arrived before actually Launch the Application
//Due to Good’s Event Handler, this means the app must be launched in 2 places
//The handler for the Event GDAppEventAuthorized
//The handler for the Event GDAppEventPolicyUpdate

- (void)handleEvent:(GDAppEvent*)anEvent {
    switch (anEvent.type) {
        case GDAppEventAuthorized: {
            [self onAuthorized:anEvent];
            break; }
        case GDAppEventNotAuthorized: {
            [self onNotAuthorized:anEvent];
            break; }
        case GDAppEventPolicyUpdate: {
            
            NSDictionary* appPolicyDictionary = [self.gdLibrary getApplicationPolicy];
            
            //Added this code due to the good container's event handler sequence of firing events. This code will start the app if it is not already started and after the user is authorized.
            if(!started && authorized)
            {
                [self onStartUpSucceed];
                started = YES;
            }
            
            NSString* loginHostFromPolicy = [[appPolicyDictionary objectForKey:@"loginhost"]objectForKey:@"hostname"];
            if(loginHostFromPolicy && ![[NSNull null] isEqual:loginHostFromPolicy])
            {
                
                NSString* currentHost = [SFAccountManager loginHost];
                if (![loginHostFromPolicy isEqualToString:currentHost])
                {
                    [SFAccountManager setLoginHost:loginHostFromPolicy];
                    
                    //Logout of the SFAuthentication manager if only if we have already started.
                    if (started)
                    {
                        [[SFAuthenticationManager sharedManager] logout];
                    }
                    
                }
            }
            
            
            //Custom API URL Changed
            NSString* urlFromPolicy = [[appPolicyDictionary objectForKey:@"customapiurl"]objectForKey:@"url"];
            
            if(urlFromPolicy && ![[NSNull null] isEqual:urlFromPolicy]) {
                NSURL *url=[[NSURL alloc] initWithString: urlFromPolicy];
                [SFDCManager setCustomInstanceURLSetting:url];
            }
            
            break;}
            
        default: {
            // This app is not interested in any other type of event.
            break; }
    } }

/**
 * Handle the Good Libraries authorized event. * @see GDAppEvent
 * @param anEvent The startup event details.
 */
- (void)onAuthorized:(GDAppEvent*)anEvent {
    switch (anEvent.code) {
        case GDErrorNone: {
            if (!started) {
                [self onStartUpSucceed];
                started = YES;
            }
            authorized = YES;
            
            break; }
        default:
            NSAssert(false, @"Authorized startup with an error"); break;
    } }

/**
 * Handle the Good Libraries not authorized event. * @see GDAppEvent.
 * @param anEvent The startup event details.
 */
- (void)onNotAuthorized:(GDAppEvent*)anEvent {
    self.authenticatedWithGD = NO;
    switch (anEvent.code) {
        case GDErrorActivationFailed:
        case GDErrorProvisioningFailed:
        case GDErrorPushConnectionTimeout: {
            // application can either handle this and show it's own UI or just call back into // the GD library and the welcome screen will be shown
            [self.gdLibrary authorize];
            break;
        }
        case GDErrorSecurityError: case GDErrorAppDenied: case GDErrorBlocked: case GDErrorWiped:
        case GDErrorRemoteLockout:
        case GDErrorPasswordChangeRequired: {
            // a condition has occured denying authorization, an application may wish to log these events
            NSLog(@"onNotAuthorized %@", anEvent.message);
            break; }
        case GDErrorIdleLockout: {
            // idle lockout is benign & informational so don't show an alert
            break; }
        default:
            NSAssert(false, @"Unhandled not authorized event"); break;
    }
}

- (void)onStartUpSucceed {
    // Add the view controller's view to the window and display.
    [self initializeAppViewState];
    
    NSDictionary *gdAppConfig = [self.gdLibrary getApplicationConfig];
    NSString *gdUser = [gdAppConfig objectForKey:GDAppConfigKeyUserId];
    NSLog(@"GDUser: %@", gdUser);
    
    SFAuthErrorHandler *customHandler = [[SFAuthErrorHandler alloc] initWithName:@"CustomErrorHandler" evalBlock:^BOOL(NSError * error, SFOAuthInfo *info) {
        NSLog(@"%@", error.localizedDescription);
        if (error.code == 672) {
            return NO;
        }
        UIAlertView *alertView;
        if (error.code == 101) {
            alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error with app initialization.  Please restart the app." delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:nil];
            alertView.tag = 107;
        }
        else if (error.code == -1202) {
            if ([gdUser containsString:@"msgdev"] || [gdUser containsString:@"msgqa"])
            {
                UIViewController *vc = (UIViewController *)[SFAuthenticationManager sharedManager].authViewController;
                [[SFAuthenticationManager sharedManager] cancelAuthentication];
                [vc dismissViewControllerAnimated:YES completion:^{
                    self.acceptUntrustedCertificate = YES;
                    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
                }];
            }
            else
            {
                return NO;
            }
        }
        else if ([Reachability internetReachable]) {
            alertView = [[UIAlertView alloc] initWithTitle:@"SFDC Error" message:@"Unable to authenticate with Salesforce!  Please check your internet connection.  If problems persist, disable and then re-enable your internet connection before trying again." delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:@"Retry", nil];
            alertView.tag = 103;
        }
        else
        {
            alertView = [[UIAlertView alloc] initWithTitle:@"SFDC Error" message:@"No internet connection!" delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:@"Retry", @"Offline Mode", nil];
            alertView.tag = 104;
        }
        [alertView show];
        return YES;
    }];
    
    
    SFAuthErrorHandlerList *list = [[SFAuthenticationManager sharedManager] authErrorHandlerList];
    [list addAuthErrorHandler:customHandler atIndex:0];
    
    [[SFAuthenticationManager sharedManager] addDelegate:self];
    
    if ([Reachability internetReachable]) {
        [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
    }
    else
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"No Internet connection!" delegate:self cancelButtonTitle:@"Exit" otherButtonTitles:@"Offline Mode", nil];
        alertView.tag = 105;
        [alertView show];
    }
}

- (void)authManagerWillBeginAuthWithView:(SFAuthenticationManager *)manager {
    NSLog(@"AppDelegate: authManagerWillBeginAuthWithView called");
}

- (void)authManagerDidStartAuthWebViewLoad:(SFAuthenticationManager *)manager {
    NSLog(@"AppDelegate: authManagerDidStartAuthWebViewLoad called");
    UIViewController *vc = (UIViewController *)manager.authViewController;
    NSArray *views = vc.view.subviews;
    if (views.count > 0) {
        UIView *view = (UIView *)views.firstObject;
        if ([view isKindOfClass:[UIWebView class]]) {
            UIWebView *webView = (UIWebView *)view;
            [webView GDSetRequestConnectionDelegate:self];
        }
    }
}

- (void)authManagerDidFinishAuthWebViewLoad:(SFAuthenticationManager *)manager {
    NSLog(@"AppDelegate: authManagerDidFinishAuthWebViewLoad called");
}

- (void)authManager:(SFAuthenticationManager *)manager willDisplayAuthWebView:(UIWebView *)view {
    NSLog(@"AppDelegate: authManager called");
}

- (void)authManagerDidAuthenticate:(SFAuthenticationManager *)manager credentials:(SFOAuthCredentials *)credentials authInfo:(SFOAuthInfo *)info {
    NSLog(@"AppDelegate: authManagerDidAuthenticate called");
}

- (void) updateUsername:(NSNotification *) notification {
    NSDictionary *usernameInfo = [notification userInfo][kHeaderUsername];
    [self.menuViewController setMenuHeaderUsername:usernameInfo[kHeaderUsername]];
}

- (void) GDRequest:(NSURLRequest *)request willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
    NSLog(@"Sending authentication");
    NSDictionary *gdAppConfig = [self.gdLibrary getApplicationConfig];
    NSString *gdUser = [gdAppConfig objectForKey:GDAppConfigKeyUserId];
    if (([gdUser containsString:@"msgdev"] || [gdUser containsString:@"msgqa"]) && self.acceptUntrustedCertificate) {
        NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
        if ([protectionSpace authenticationMethod] == NSURLAuthenticationMethodServerTrust) {
            NSURLCredential *credential =
            [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            [challenge.sender useCredential:credential forAuthenticationChallenge:challenge];
        }
    }
}

#pragma mark - TWTSideMenuViewControllerDelegate

- (UIStatusBarStyle)sideMenuViewController:(TWTSideMenuViewController *)sideMenuViewController statusBarStyleForViewController:(UIViewController *)viewController
{
    if (viewController == self.menuViewController) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

#pragma mark - Private methods

- (void)initializeAppViewState
{
    self.window.rootViewController = [[InitialViewController alloc] initWithNibName:@"InitialViewController" bundle:nil];
}


- (void)setupRootViewController:(NSNotification *) notification
{
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateUsername:) name:kHeaderUsername object:nil];
    
    @try {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"bgSyncEnd" object:nil];
    }
    @catch (NSException *exception) {
        NSLog(@"This is not being observed!");
    }
    
    self.menuViewController = [[LeftMenuViewController alloc] initWithNibName:nil bundle:nil];
    self.mainViewController = [[HomeViewController alloc] initWithNibName:nil bundle:nil];
    
    self.sideMenuViewController = [[TWTSideMenuViewController alloc] initWithMenuViewController:self.menuViewController mainViewController:[[UINavigationController alloc] initWithRootViewController:self.mainViewController]];
    self.sideMenuViewController.shadowColor = [UIColor blackColor];
    self.sideMenuViewController.edgeOffset = (UIOffset) { .horizontal = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 18.0f : 0.0f };
    self.sideMenuViewController.zoomScale = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 0.5634f : 0.55f;
    self.window.rootViewController = self.sideMenuViewController;
    if (![DataSynchronizationManager sharedInstance].isInitialSync) {
        [[DataSynchronizationManager sharedInstance] scheduleSyncNotificationFromNow:kNotificationInterval];
    }
    UIColor *background = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"menu-bg.png"]];
    self.window.backgroundColor = background;
    if (notification != nil) {
        NSDictionary *userInfo = notification.userInfo;
        if (userInfo) {
            NSNumber *statusNumber = [userInfo objectForKey:@"status"];
            NSInteger status = statusNumber.integerValue;
            if (status == DataSynchronizationManagerResultSuccess) {
                UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Success" message:@"Initialization complete!  Press OK to use the app." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [alertView show];
                [[OperationPaperclipFacade sharedInstance] logDataEvent:@"initialSyncComplete" payload:@[] object:@"sync" isSuccess:YES errorMsgs:@""];
            }
        }
    }
    if ([[OperationPaperclipFacade sharedInstance] needToUpdateApp])
    {
        UIAlertView *updateAlertView = [[UIAlertView alloc] initWithTitle:@"Update Available" message:@"There is an update available for IBCM Mobile.  Please go to the Good App Store to download the latest version." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [updateAlertView show];
    }
}

- (void)logoutInitiated:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Logout notification received.  Resetting app."];
    [self initializeAppViewState];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
    [self cancelDataSync];
    
    self.authenticatedWithSFDC = NO;
}

- (void)loginHostChanged:(NSNotification *)notification
{
    [self log:SFLogLevelDebug msg:@"Login host changed notification received.  Resetting app."];
    self.acceptUntrustedCertificate = YES;
    [self initializeAppViewState];
    [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
    [self cancelDataSync];
    
    self.authenticatedWithSFDC = NO;
}

#pragma mark - Data Synchronization

- (void) scheduleDataSyncCheckTables:(BOOL)checkTables
{
//    DataSynchronizationManager *syncManager = [DataSynchronizationManager sharedInstance];
    if (!self.authenticatedWithGD || !self.authenticatedWithSFDC) {
        NSLog(@"-@@@@@@ scheduleDataSync USER IS NOT AUTHENTICATED SKIPPING DATA SYNC SCHEDULE!");
        return;
    }
    
    DataSynchronizationManager *syncManager = [DataSynchronizationManager sharedInstance];
    if (checkTables) {
        NSInteger status = [syncManager checkIfTablesNeedTobeRebuilt];
        if (status == 0)
        {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupRootViewController:) name:@"bgSyncEnd" object:nil];
            [syncManager aSyncWithSFDC:YES];
        }
        else if (status != 401)
        {
//            [syncManager scheduleSyncWithSFDC];
            [self setupRootViewController:nil];
        }
    }
    else
    {
        if (syncManager.isInitialSync && self.window.rootViewController == nil) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupRootViewController:) name:@"bgSyncEnd" object:nil];
            [self initializeAppViewState];
        }
        else
        {
            [[TaskScheduleManager sharedInstance] resumeTimer];
            //If there is no screen, create home screen
            if (self.window.rootViewController == nil) {
                [self setupRootViewController:nil];
            }
        }
    }
}

- (void)cancelDataSync
{
    [[DataSynchronizationManager sharedInstance] cancelSyncWithSFDC];
}

- (void)registerDefaultsFromSettingsBundle
{
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    
    if(!settingsBundle)
    {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences)
    {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        NSString *def=[prefSpecification objectForKey:@"DefaultValue"];
        
        if(key && def)
        {
            
            [defaultsToRegister setObject:def forKey:key];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

- (void) showSFDCError:(NSNotification *)notification {
    id<UIAlertViewDelegate> delegate = self;
    if ([notification.object respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        delegate = notification.object;
    }
    NSError *error = [notification.userInfo objectForKey:@"error"];
    NSNumber *errorCode = [notification.userInfo objectForKey:@"errorCode"];
    NSNumber *reload = [notification.userInfo objectForKey:@"reload"];
    BOOL retry = YES;
    UIAlertView *alert = nil;
    if (reload) {
        retry = [reload boolValue];
    }
    if (errorCode) {
        NSUInteger status = [errorCode integerValue];
        NSString *message = @"";
        switch (status) {
            case DataSynchronizationManagerResultAlreadyRunning:
                message = @"There is a sync already in progress.  Please wait until it finishes.";
                break;
            case DataSynchronizationManagerResultNoConnection:
                message = @"Unable to connect!  Please check your connection.";
                break;
            case DataSynchronizationManagerResultNoMetadata:
                message = @"Your app was not initialized.  Please try syncing again in a few minutes.";
                break;
            case DataSynchronizationManagerResultReportsError:
                retry = NO;
                //Do not need to break here, will also use message from error
            default:
                message = error != nil ? [error localizedDescription] : @"An unknown error occurred!";
                break;
        }
        if (retry) {
            alert = [[UIAlertView alloc] initWithTitle:@"Sync Error" message:[NSString stringWithFormat:@"%@\nCode: %d\nTry to load again?", message, status] delegate:delegate cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            if ([error.domain isEqualToString:@"loadConfigurationData"] || error.code == 3840) {
                //Error in config JSON, try to initialize app again
                alert.tag = 102;
            }
            else
            {
                alert.tag = 101;
            }
        }
        else
        {
            alert = [[UIAlertView alloc] initWithTitle:@"Sync Error" message:[NSString stringWithFormat:@"%@\nCode: %d", message, status] delegate:delegate cancelButtonTitle:@"OK" otherButtonTitles:nil];
        }
    }
    else if (error) {
        // check for INVALID_SESSION_ID
        NSRange range = [error.localizedDescription rangeOfString:@"INVALID_SESSION_ID"];
        
        if (range.length > 0) {
            // log out
            [self unauthorizedError:notification];
            return;
        } else {
            NSString *message = error.localizedDescription;
//            if (error.code == 1) {
//                message = @"You have lost Internet access!";
//            }
            if (retry) {
                alert = [[UIAlertView alloc] initWithTitle:@"SFDC Error" message:[NSString stringWithFormat:@"Error: %@\nCode: %d\nTry to load again?", message, error.code] delegate:delegate cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
            }
            else
            {
                alert = [[UIAlertView alloc] initWithTitle:@"Sync Error" message:[NSString stringWithFormat:@"%@\nCode: %d", message, error.code] delegate:delegate cancelButtonTitle:@"OK" otherButtonTitles:nil];
            }
            
        }
    }
    if (alert) {
        [alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
    }
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 101) { //General SFDC Error
        if (buttonIndex == alertView.cancelButtonIndex) {
            if (self.window.rootViewController == nil) {
                [self setupRootViewController:nil];
            }
        }
        else
            [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:[DataSynchronizationManager sharedInstance].isInitialSync];
    }
    else if (alertView.tag == 102) { //Error when loading config data
        if (buttonIndex == alertView.cancelButtonIndex)
        {
            //If there is no screen, create home screen
            if (self.window.rootViewController == nil) {
                [self setupRootViewController:nil];
            }
            else
                exit(0);
        }
        else
        {
            if ([[DataSynchronizationManager sharedInstance] checkIfTablesNeedTobeRebuilt] == 0) {
                [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:YES];
            }
        }
    }
    else if (alertView.tag == 103) { //Cannot authenticate, error
        [[SFAuthenticationManager sharedManager] cancelAuthentication];
        if (buttonIndex == alertView.cancelButtonIndex) {
            exit(0);
        }
        else
        {
            [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
        }
    }
    else if (alertView.tag == 104) { //Cannot authenticate, no connection
        [[SFAuthenticationManager sharedManager] cancelAuthentication];
        if (buttonIndex == alertView.cancelButtonIndex) {
            exit(0);
        }
        else if (buttonIndex == alertView.firstOtherButtonIndex)
        {
            [[SFAuthenticationManager sharedManager] loginWithCompletion:self.initialLoginSuccessBlock failure:self.initialLoginFailureBlock];
        }
        else
        {
            self.authenticatedWithSFDC = NO;
            [self setupRootViewController:nil];
        }
    }
    else if (alertView.tag == 105) { //No connection
        if (buttonIndex == alertView.cancelButtonIndex) {
            exit(0);
        }
        else
        {
            self.authenticatedWithSFDC = NO;
            [self setupRootViewController:nil];
        }
    }
    else if (alertView.tag == 106) { //24-hour notification alert
        if (buttonIndex == alertView.cancelButtonIndex) {
            [[DataSynchronizationManager sharedInstance] scheduleSyncNotificationAfterPopup];
        }
        else
        {
            [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:NO];
        }
    }
    else if (alertView.tag == 107) { //WebKit Error 101
        exit(0);
    }
}

- (void) unauthorizedError:(NSNotification *)notification
{
    id<UIAlertViewDelegate> delegate = self;
    if ([notification.object respondsToSelector:@selector(alertView:clickedButtonAtIndex:)]) {
        delegate = notification.object;
    }
    self.authenticatedWithSFDC = NO;
    __weak AppDelegate *weakSelf = self;
    if ([UIAlertController class]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Error" message:@"Your authentication token with SFDC has expired!  Click OK to login again." preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *alertAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *info) {
                weakSelf.authenticatedWithSFDC = YES;
                if ([delegate isEqual:weakSelf]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:NO];
                    });
                }
                else
                {
                    [delegate alertView:nil clickedButtonAtIndex:1];
                }
            } failure:^(SFOAuthInfo *info, NSError *error) {
                [[SFAuthenticationManager sharedManager] logout];
            }];
        }];
        [alertController addAction:alertAction];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
    else if ([UIAlertView class])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Your authentication token with SFDC has expired!  Click OK to login again." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        alertView.tag = 900;
        [alertView showWithSelectBlock:^BOOL(NSInteger index, NSString *title) {
            return YES;
        } cancel:^BOOL{
            [[SFAuthenticationManager sharedManager] loginWithCompletion:^(SFOAuthInfo *info) {
                weakSelf.authenticatedWithSFDC = YES;
                if ([delegate isEqual:weakSelf]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:NO];
                    });
                }
                else
                {
                    [delegate alertView:nil clickedButtonAtIndex:1];
                }
            } failure:^(SFOAuthInfo *info, NSError *error) {
                [[SFAuthenticationManager sharedManager] logout];
            }];
            return YES;
        }];
    }
}

- (void) signOutFromSalesforce:(NSNotification *)notification
{
    [[SFAuthenticationManager sharedManager] logout];
    self.authenticatedWithSFDC = NO;
}

- (void) syncNotification:(NSNotification *)notification
{
    if ([UIAlertController class])
    {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Alert!" message:@"More than 24 hours since your last complete data sync.  Sync Now?" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [[DataSynchronizationManager sharedInstance] scheduleSyncNotificationAfterPopup];
        }];
        UIAlertAction *syncAction = [UIAlertAction actionWithTitle:@"Sync Now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[DataSynchronizationManager sharedInstance] aSyncWithSFDC:NO];
        }];
        [alertController addAction:cancelAction];
        [alertController addAction:syncAction];
        [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
    else if ([UIAlertView class])
    {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Alert!" message:@"More than 24 hours since your last complete data sync.  Sync Now?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Sync Now", nil];
        alertView.tag = 106;
        [alertView show];
    }
}

@end
