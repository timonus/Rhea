//
//  AppDelegate.m
//  Rhea
//
//  Created by Tim Johnsen on 8/3/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "AppDelegate.h"

#import "RHEAMenuItem.h"
#import "RHEAEntityResolver.h"
#import "RHEABitlyClient.h"
#import "RHEAGoogleClient.h"
#import "TJDropbox.h"
#import "SAMKeychain.h"
#import "NSURL+Rhea.h"

#import <CommonCrypto/CommonDigest.h>

// Building a status bar app: https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps
// Hiding the dock icon: http://stackoverflow.com/questions/620841/how-to-hide-the-dock-icon
// Handling incoming URLs: http://fredandrandall.com/blog/2011/07/30/how-to-launch-your-macios-app-with-a-custom-url/
// Drag drop into status bar: http://stackoverflow.com/a/26810727/3943258
// Key presses: http://stackoverflow.com/questions/9268045/how-can-i-detect-that-the-shift-key-has-been-pressed
// Key event monitoring: https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps

static NSString *const kRHEADropboxAppKey = @"";
static NSString *const kRHEADropboxRedirectURLString = @""; // NOTE: This is a remote URL to a file that should redirect back to Rhea to complete auth (see https://goo.gl/VH4LXW). The "dropbox-auth.html" file in this repo can be used. 

static NSString *const kRHEABitlyClientIdentifier = @"";
static NSString *const kRHEABitlyClientSecret = @"";
static NSString *const kRHEABitlyRedirectURLString = @""; // NOTE: This is a remote URL to a file that should redirect back to Rhea to complete auth. The "bitly-auth.html" file in this repo can be used.

static NSString *const kRHEADropboxAccountKey = @"com.tijo.Rhea.Service.Dropbox";
static NSString *const kRHEACurrentDropboxAccountKey = @"currentDropboxAccount";

static NSString *const kRHEABitlyAccountKey = @"com.tijo.Rhea.Service.Bitly";

static NSString *const kRHEANotificationURLStringKey = @"url";

static NSString *const kRHEARecentActionTitleKey = @"title";
static NSString *const kRHEARecentActionURLKey = @"url";
static const NSUInteger kRHEARecentActionsMaxCountKey = 10;

@interface AppDelegate () <NSWindowDelegate, NSUserNotificationCenterDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusItem;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentActions;

@end

@implementation AppDelegate

#pragma mark - App Lifecycle

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Handle incoming URLs
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kInternetEventClass];
    
    // Set up our status bar icon and menu
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"StatusBarButtonImage"];
    
    [self.statusItem.button.window registerForDraggedTypes:@[NSFilenamesPboardType, NSURLPboardType, NSStringPboardType]];
    self.statusItem.button.window.delegate = self;
    
    NSMenu *const menu = [[NSMenu alloc] init];
    menu.delegate = self;
    self.statusItem.menu = menu;
    
    self.recentActions = [NSMutableArray new];
    
    // Notifications
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    [self updateCurrentDropboxAccountInformation];
    
    // Looks janky, but this touches the keychain entries we'll need to access prior to the menu being clicked.
    // If we attempt to access the keychain while the mouse click for the menu's being handled, the permission dialog that pops up won't receive any keyboard events. Which is bad.
    [self menuWillOpen:[NSMenu new]];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *const url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString *const dropboxToken = [TJDropbox accessTokenFromURL:url withRedirectURL:[NSURL URLWithString:@"rhea-dropbox-auth://dropboxauth"]];
    NSString *const bitlyCode = [RHEABitlyClient accessCodeFromURL:url redirectURL:[NSURL URLWithString:@"rhea-bitly-auth://bitlyauth"]];
    
    if (dropboxToken) {
        [TJDropbox getAccountInformationWithAccessToken:dropboxToken completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
            NSString *const email = parsedResponse[@"email"];
            NSString *message = nil;
            if (email) {
                message = @"Logged in to Dropbox!";
                [SAMKeychain setPassword:dropboxToken forService:kRHEADropboxAccountKey account:email];
            } else {
                message = @"Unable to log into Dropbox";
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *const alert = [[NSAlert alloc] init];
                alert.messageText = message;
                [alert runModal];
            });
        }];
    } else if (bitlyCode) {
        [RHEABitlyClient authenticateWithCode:bitlyCode
                             clientIdentifier:kRHEABitlyClientIdentifier
                                 clientSecret:kRHEABitlyClientSecret
                                  redirectURL:[NSURL URLWithString:kRHEABitlyRedirectURLString]
                                   completion:^(NSString * _Nullable accessToken) {
                                       NSString *message = nil;
                                       if (accessToken) {
                                           message = @"Logged in to Bitly!";
                                           [SAMKeychain setPassword:accessToken forService:kRHEABitlyAccountKey account:kRHEABitlyAccountKey];
                                       } else {
                                           message = @"Unable to log into Bitly";
                                       }
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           NSAlert *const alert = [[NSAlert alloc] init];
                                           alert.messageText = message;
                                           [alert runModal];
                                       });
                                   }];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

#pragma mark - Menu Management

- (void)menuWillOpen:(NSMenu *)menu
{
    [menu removeAllItems];
    
    NSMenuItem *recentsItem = [[NSMenuItem alloc] initWithTitle:@"Recents" action:nil keyEquivalent:@""];
    NSMenu *recentsMenu = [[NSMenu alloc] init];
    recentsItem.submenu = recentsMenu;
    if (self.recentActions.count == 0) {
        NSMenuItem *noRecentsItem = [[NSMenuItem alloc] initWithTitle:@"No Recents" action:nil keyEquivalent:@""];
        noRecentsItem.enabled = NO;
        [recentsMenu addItem:noRecentsItem];
    } else {
        for (NSDictionary *recentAction in self.recentActions) {
            RHEAMenuItem *recentMenuItem = [[RHEAMenuItem alloc] initWithTitle:recentAction[kRHEARecentActionTitleKey] action:@selector(recentMenuItemClicked:) keyEquivalent:@""];
            recentMenuItem.context = recentAction;
            [recentsMenu addItem:recentMenuItem];
        }
    }
    NSString *const currentDropboxAccount = [self currentDropboxAccount];
    const BOOL signedInToBitly = ([SAMKeychain passwordForService:kRHEABitlyAccountKey account:kRHEABitlyAccountKey] != nil);
    if ([self currentDropboxAccount]) {
        [recentsMenu addItem:[NSMenuItem separatorItem]];
        [recentsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"View more on Dropbox" action:@selector(recentsMenuItemClicked:) keyEquivalent:@""]];
    }
    [menu addItem:recentsItem];
    id resolvedEntity = [self resolvePasteboard:[NSPasteboard generalPasteboard]];
    if ([resolvedEntity isKindOfClass:[NSString class]]) {
        if (currentDropboxAccount) {
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Upload copied file" action:@selector(uploadPasteboardMenuItemClicked:) keyEquivalent:@""]];
        }
    } else if ([resolvedEntity isKindOfClass:[NSURL class]]) {
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Shorten copied link" action:@selector(shortenPasteboardMenuItemClicked:) keyEquivalent:@""]];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    
    
    NSMenuItem *const accountsItem = [[NSMenuItem alloc] initWithTitle:@"Accounts" action:nil keyEquivalent:@""];
    NSMenu *const accountsMenu = [[NSMenu alloc] init];
    
    NSMenuItem *titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Dropbox Accounts" action:nil keyEquivalent:@""];
    titleMenuItem.enabled = NO;
    [accountsMenu addItem:titleMenuItem];
    NSArray *const dropboxAccounts = [SAMKeychain accountsForService:kRHEADropboxAccountKey];
    if (currentDropboxAccount) {
        for (NSDictionary *const account in dropboxAccounts) {
            NSString *const email = [account objectForKey:kSAMKeychainAccountKey];
            NSMenuItem *const menuItem = [[NSMenuItem alloc] initWithTitle:email action:@selector(accountMenuItemSelected:) keyEquivalent:@""];
            if ([email isEqualToString:currentDropboxAccount]) {
                menuItem.state = NSOnState;
            }
            [accountsMenu addItem:menuItem];
        }
    }
    [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Add Dropbox Account" action:@selector(authenticateDropboxMenuItemClicked:) keyEquivalent:@""]];
    if (currentDropboxAccount) {
        [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Sign out %@", currentDropboxAccount] action:@selector(signOutCurrentDropboxAccountMenuItemClicked:) keyEquivalent:@""]];
    }
    [accountsMenu addItem:[NSMenuItem separatorItem]];
    
    titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Bitly Account" action:nil keyEquivalent:@""];
    titleMenuItem.enabled = NO;
    [accountsMenu addItem:titleMenuItem];
    if (signedInToBitly) {
        [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Sign out" action:@selector(signOutBitlyAccountMenuItemClicked:) keyEquivalent:@""]];
    } else {
        [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Sign in to Bitly" action:@selector(authenticateBitlyMenuItemClicked:) keyEquivalent:@""]];
    }
    
    accountsItem.submenu = accountsMenu;
    [menu addItem:accountsItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]];
}

- (void)authenticateDropboxMenuItemClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[TJDropbox tokenAuthenticationURLWithClientIdentifier:kRHEADropboxAppKey redirectURL:[NSURL URLWithString:kRHEADropboxRedirectURLString]]];
}

- (void)authenticateBitlyMenuItemClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[RHEABitlyClient authenticationURLWithClientIdentifier:kRHEABitlyClientIdentifier redirectURL:[NSURL URLWithString:kRHEABitlyRedirectURLString]]];
}

- (void)accountMenuItemSelected:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[(NSMenuItem *)sender title] forKey:kRHEACurrentDropboxAccountKey];
    
    [self updateCurrentDropboxAccountInformation];
}

- (void)signOutCurrentDropboxAccountMenuItemClicked:(id)sender
{
    [SAMKeychain deletePasswordForService:kRHEADropboxAccountKey account:[self currentDropboxAccount]];
    
    [self updateCurrentDropboxAccountInformation];
}

- (void)signOutBitlyAccountMenuItemClicked:(id)sender
{
    [SAMKeychain deletePasswordForService:kRHEABitlyAccountKey account:kRHEABitlyAccountKey];
}

- (void)recentsMenuItemClicked:(id)sender
{
    // http://stackoverflow.com/questions/381021/launch-safari-from-a-mac-application
    // TODO: Open in new tab.
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.dropbox.com/recents"]];
}

- (void)recentMenuItemClicked:(id)sender
{
    NSDictionary *action = [(RHEAMenuItem *)sender context];
    [self copyLinkFromRecentAction:action];
}

- (void)uploadPasteboardMenuItemClicked:(id)sender
{
    id resolvedEntity = [self resolvePasteboard:[NSPasteboard generalPasteboard]];
    if ([resolvedEntity isKindOfClass:[NSString class]]) {
        [self uploadFileAtPath:resolvedEntity];
    }
}

- (void)shortenPasteboardMenuItemClicked:(id)sender
{
    id resolvedEntity = [self resolvePasteboard:[NSPasteboard generalPasteboard]];
    if ([resolvedEntity isKindOfClass:[NSURL class]]) {
        [self shortenURL:resolvedEntity];
    }
}

#pragma mark - Notifications

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    if (notification.activationType == NSUserNotificationActivationTypeContentsClicked || notification.activationType == NSUserNotificationActivationTypeActionButtonClicked) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:notification.userInfo[kRHEANotificationURLStringKey]]];
    }
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification
{
    return YES;
}

#pragma mark - Drag & Drop

- (id)resolveDraggingInfo:(id<NSDraggingInfo>)sender
{
    return [self resolvePasteboard:[sender draggingPasteboard]];
}

- (id)resolvePasteboard:(NSPasteboard *)pasteboard
{
    // http://stackoverflow.com/a/423702/3943258
    
    id resolvedEntity = nil;
    
    NSArray *const paths = [pasteboard propertyListForType:NSFilenamesPboardType];
    NSArray *const urls = [pasteboard propertyListForType:NSURLPboardType];
    NSString *const string = [pasteboard stringForType:NSStringPboardType];
    
    if (paths.count > 0) {
        if (paths.count == 1) {
            resolvedEntity = [RHEAEntityResolver resolveEntity:[paths firstObject]];
        }
    } else if (urls.count > 0) {
        const id object = [urls firstObject];
        NSURL *url = nil;
        if ([object isKindOfClass:[NSURL class]]) {
            url = object;
        } else if ([object isKindOfClass:[NSString class]]) {
            url = [NSURL URLWithString:object];
        }
        if (url) {
            resolvedEntity = [RHEAEntityResolver resolveEntity:url];
        }
    } else if (string) {
        resolvedEntity = [RHEAEntityResolver resolveEntity:string];
    }
    
    return resolvedEntity;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    id resolvedEntity = [self resolveDraggingInfo:sender];
    
    NSDragOperation operation = NSDragOperationNone;
    
    if ([resolvedEntity isKindOfClass:[NSURL class]]) {
        if (([NSEvent modifierFlags] & NSAlternateKeyMask) != 0) {
            operation = NSDragOperationCopy;
        } else {
            operation = NSDragOperationLink;
        }
    } else if ([resolvedEntity isKindOfClass:[NSString class]]) {
        operation = NSDragOperationCopy;
    }
    
    return operation;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    id resolvedEntity = [self resolveDraggingInfo:sender];
    
    BOOL didHandle = NO;
    
    // 1. See if this is a remote URL we'd like to copy (alt/option key)
    if ([resolvedEntity isKindOfClass:[NSURL class]] && ([NSEvent modifierFlags] & NSAlternateKeyMask)) {
        [self saveFileAtURL:resolvedEntity];
        didHandle = YES;
    }
    
    // 2. Upload local file or shorten link
    if (!didHandle) {
        if ([resolvedEntity isKindOfClass:[NSString class]]) {
            [self uploadFileAtPath:resolvedEntity];
            didHandle = YES;
        } else if ([resolvedEntity isKindOfClass:[NSURL class]]) {
            [self shortenURL:resolvedEntity];
            didHandle = YES;
        }
    }
    
    return didHandle;
}

#pragma mark - Dropbox

- (NSString *)currentDropboxAccount
{
    NSString *account = nil;
    for (NSDictionary *const keychainAccount in [SAMKeychain accountsForService:kRHEADropboxAccountKey]) {
        if ([[keychainAccount objectForKey:kSAMKeychainAccountKey] isEqualToString:[[NSUserDefaults standardUserDefaults] stringForKey:kRHEACurrentDropboxAccountKey]]) {
            account = [keychainAccount objectForKey:kSAMKeychainAccountKey];
            break;
        }
    }
    // Fall back to first available account if there's no match in NSUserDefaults.
    if (!account) {
        account = [[[SAMKeychain accountsForService:kRHEADropboxAccountKey] firstObject] objectForKey:kSAMKeychainAccountKey];
    }
    return account;
}

- (void)updateCurrentDropboxAccountInformation
{
    NSString *const currentToken = [self dropboxToken];
    NSString *const currentEmail = [self currentDropboxAccount];
    if (currentToken && currentEmail) {
        [TJDropbox getAccountInformationWithAccessToken:currentToken completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
            // Check that the account credentials are still valid. If not we need to boot the user out.
            if (error) {
                [self handleDropboxError:error message:nil];
            } else {
                // Check if the email needs to be updated.
                NSString *const email = parsedResponse[@"email"];
                if (email && ![email isEqualToString:currentEmail]) {
                    
                    // Make sure we keep the same "current" account even though its name is about to change.
                    if ([[self currentDropboxAccount] isEqualToString:currentEmail]) {
                        [[NSUserDefaults standardUserDefaults] setObject:email forKey:kRHEACurrentDropboxAccountKey];
                    }
                    
                    // Update the keychain entry
                    [SAMKeychain deletePasswordForService:kRHEADropboxAccountKey account:currentEmail];
                    [SAMKeychain setPassword:currentToken forService:kRHEADropboxAccountKey account:email];
                }
            }
        }];
    }
    
}

- (NSString *)dropboxToken
{
    return [SAMKeychain passwordForService:kRHEADropboxAccountKey account:[self currentDropboxAccount]];
}

- (void)uploadFileAtPath:(NSString *const)path
{
    NSURL *const fileURL = [NSURL fileURLWithPath:path];
    NSString *const filename = [[fileURL URLByDeletingPathExtension] lastPathComponent];
    NSString *const extension = [fileURL pathExtension];
    
    // Append first 4 non-special characters of the base 64 MD5 hash of the file contents to it.
    // Better than random because repeated uploads won't be stored multiple times.
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    NSData *const data = [NSData dataWithContentsOfFile:path];
    CC_MD5(data.bytes, (CC_LONG)data.length, result);
    NSString *suffix = [[NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    suffix = [suffix stringByReplacingOccurrencesOfString:@"/|\\+|=" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, suffix.length)];
    suffix = [suffix substringToIndex:MIN(4, suffix.length)];
    
    NSString *const remoteFilename = [NSString stringWithFormat:@"%@-%@%@", filename, suffix, extension.length > 0 ? [NSString stringWithFormat:@".%@", extension] : @""];
    NSString *const remotePath = [NSString stringWithFormat:@"/%@", remoteFilename];
    
    // Begin uploading the file
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    
    if (fileSize > 150 * 1024 * 1024) { // The docs state that no request should be larger than 150MB https://goo.gl/MkYMSc
        [TJDropbox uploadLargeFileAtPath:path toPath:remotePath overwriteExisting:NO accessToken:[self dropboxToken] progressBlock:^(CGFloat progress) {
            // TODO: Show progress.
        } completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
            if (error) {
                [self handleDropboxError:error message:@"Couldn't upload file"];
            } else {
                NSUserNotification *const notification = [[NSUserNotification alloc] init];
                notification.title = @"Upload complete";
                notification.subtitle = filename;
                if ([extension caseInsensitiveCompare:@"png"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"gif"] == NSOrderedSame) {
                    notification.contentImage = [[NSImage alloc] initWithContentsOfFile:path];
                }
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
                });
            }
        }];
    } else {
        [TJDropbox uploadFileAtPath:path toPath:remotePath overwriteExisting:NO accessToken:[self dropboxToken] progressBlock:^(CGFloat progress) {
            // TODO: Show progress.
        } completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
            [self handleDropboxError:error message:@"Couldn't upload file"];
        }];
    }
    
    // Copy a short link
    [TJDropbox getSharedLinkForFileAtPath:remotePath linkType:TJDropboxSharedLinkTypeShort uploadOrSaveInProgress:YES accessToken:[self dropboxToken] completion:^(NSString * _Nullable urlString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (urlString) {
                [self copyStringToPasteboard:urlString];
                
                NSUserNotification *const notification = [[NSUserNotification alloc] init];
                notification.title = @"Copied file link";
                notification.subtitle = filename;
                notification.informativeText = urlString;
                if ([extension caseInsensitiveCompare:@"png"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"gif"] == NSOrderedSame) {
                    notification.contentImage = [[NSImage alloc] initWithContentsOfFile:path];
                }
                notification.hasActionButton = YES;
                notification.actionButtonTitle = @"View";
                notification.userInfo = @{kRHEANotificationURLStringKey: urlString};
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
                });
                
                [self addRecentActionWithTitle:filename url:[NSURL URLWithString:urlString]];
            } else {
                NSAlert *const alert = [[NSAlert alloc] init];
                alert.messageText = @"Couldn't copy link";
                alert.informativeText = path;
                [alert runModal];
            }
        });
    }];
}

- (void)saveFileAtURL:(NSURL *const)url
{
    NSString *const filename = [[url URLByDeletingPathExtension] lastPathComponent];
    NSString *const extension = [url pathExtension];
    NSString *const suffix = [self randomSuffix];
    NSString *const remoteFilename = [NSString stringWithFormat:@"%@-%@%@", filename, suffix, extension.length > 0 ? [NSString stringWithFormat:@".%@", extension] : @""];
    NSString *const remotePath = [NSString stringWithFormat:@"/%@", remoteFilename];
    
    // Copy the file
    [TJDropbox saveContentsOfURL:url toPath:remotePath accessToken:[self dropboxToken] completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
        if (error) {
            [self handleDropboxError:error message:@"Couldn't copy file to Dropbox"];
        }
    }];
    
    // Copy a short link
    [TJDropbox getSharedLinkForFileAtPath:remotePath linkType:TJDropboxSharedLinkTypeShort uploadOrSaveInProgress:YES accessToken:[self dropboxToken] completion:^(NSString * _Nullable urlString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (urlString) {
                [self copyStringToPasteboard:urlString];
                
                NSUserNotification *const notification = [[NSUserNotification alloc] init];
                notification.title = @"Copied file link";
                notification.subtitle = filename;
                notification.informativeText = urlString;
                
                notification.hasActionButton = YES;
                notification.actionButtonTitle = @"View";
                notification.userInfo = @{kRHEANotificationURLStringKey: urlString};
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
                });
                
                [self addRecentActionWithTitle:filename url:[NSURL URLWithString:urlString]];
            } else {
                NSAlert *const alert = [[NSAlert alloc] init];
                alert.messageText = @"Couldn't copy link";
                alert.informativeText = url.absoluteString;
                [alert runModal];
            }
        });
    }];
}

/// Handles expired Dropbox credentials specially.
/// If you supply a nil message string no error will be presented to the user.
- (void)handleDropboxError:(NSError *const)error message:(NSString *const)defaultMessage
{
    if (error) {
        NSString *message = nil;
        if ([error tj_isInvalidAccessTokenError]) {
            NSString *const email = [self currentDropboxAccount];
            [SAMKeychain deletePasswordForService:kRHEADropboxAccountKey account:email];
            message = [NSString stringWithFormat:@"Your Dropbox account %@ has been disconnected.", email];
        } else {
            message = defaultMessage;
        }
        
        if (message) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSAlert *const alert = [[NSAlert alloc] init];
                alert.messageText = message;
                [alert runModal];
            });
        }
    }
}

#pragma mark - Link Shortening

- (void)shortenURL:(NSURL *const)url
{
    void (^completion)(NSURL *shortenedURL) = ^(NSURL *shortenedURL) {
        if (shortenedURL) {
            [self copyStringToPasteboard:shortenedURL.absoluteString];
            
            NSUserNotification *const notification = [[NSUserNotification alloc] init];
            notification.title = @"Link shortened";
            notification.subtitle = url.absoluteString;
            notification.informativeText = shortenedURL.absoluteString;
            notification.hasActionButton = YES;
            notification.actionButtonTitle = @"View";
            notification.userInfo = @{kRHEANotificationURLStringKey: shortenedURL.absoluteString};
            [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
            });
            
            [self addRecentActionWithTitle:[NSString stringWithFormat:@"🔗 %@", [url trimmedUserFacingString]] url:shortenedURL];
        } else {
            NSAlert *const alert = [[NSAlert alloc] init];
            alert.messageText = @"Couldn't shorten link";
            alert.informativeText = url.absoluteString;
            [alert runModal];
        }
    };
    if ([SAMKeychain passwordForService:kRHEABitlyAccountKey account:kRHEABitlyAccountKey] != nil) {
        [RHEABitlyClient shortenURL:url accessToken:[SAMKeychain passwordForService:kRHEABitlyAccountKey account:kRHEABitlyAccountKey] completion:completion];
    } else {
        [RHEAGoogleClient shortenURL:url completion:completion];
    }
}

#pragma mark - Recents

- (void)addRecentActionWithTitle:(NSString *const)title url:(NSURL *)url
{
    NSDictionary *action = @{
        kRHEARecentActionTitleKey: title,
        kRHEARecentActionURLKey: url
    };
    
    if (self.recentActions.count == 0) {
        [self.recentActions addObject:action];
    } else {
        [self.recentActions insertObject:action atIndex:0];
    }
    
    // Trim to max count
    while (self.recentActions.count > kRHEARecentActionsMaxCountKey) {
        [self.recentActions removeLastObject];
    }
}

- (void)copyLinkFromRecentAction:(NSDictionary *)action
{
    NSString *const urlString = [(NSURL *)action[kRHEARecentActionURLKey] absoluteString];
    [self copyStringToPasteboard:urlString];
    
    NSUserNotification *const notification = [[NSUserNotification alloc] init];
    notification.title = @"Copied link";
    notification.subtitle = action[kRHEARecentActionTitleKey];
    notification.informativeText = urlString;
    notification.hasActionButton = YES;
    notification.actionButtonTitle = @"View";
    notification.userInfo = @{kRHEANotificationURLStringKey: urlString};
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
    });
}

#pragma mark - Utilities

- (NSString *)randomSuffix
{
    static NSString *const kCharacterSet = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    NSMutableString *randomSuffix = [NSMutableString new];
    for (NSUInteger i = 0; i < 4; i++) {
        [randomSuffix appendFormat:@"%c", [kCharacterSet characterAtIndex:arc4random_uniform((u_int32_t)kCharacterSet.length)]];
    }
    return randomSuffix;
}

- (void)copyStringToPasteboard:(NSString *const)string
{
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[string]];
}

@end
