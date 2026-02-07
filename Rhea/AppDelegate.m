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
#import "TJURLShortener.h"
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

static NSString *const kRHEADropboxAccountKey = @"com.tijo.Rhea.Service.Dropbox";
static NSString *const kRHEACurrentDropboxAccountKey = @"currentDropboxAccount";

static NSString *const kRHEANotificationURLStringKey = @"url";

static NSString *const kRHEARecentActionTitleKey = @"title";
static NSString *const kRHEARecentActionSymbolNameKey = @"symbol";
static NSString *const kRHEARecentActionURLKey = @"url";
static const NSUInteger kRHEARecentActionsMaxCountKey = 10;

@interface AppDelegate () <NSWindowDelegate, NSUserNotificationCenterDelegate, NSMenuDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusItem;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *recentActions;

@property (nonatomic, copy) NSString *codeVerifier;

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
    
    [self.statusItem.button.window registerForDraggedTypes:@[NSPasteboardTypeFileURL, NSPasteboardTypeURL, NSPasteboardTypeString]];
    self.statusItem.button.window.delegate = self;
    
    NSMenu *const menu = [NSMenu new];
    menu.delegate = self;
    self.statusItem.menu = menu;
    
    self.recentActions = [NSMutableArray new];
    
    // Notifications
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:TJDropboxCredentialDidRefreshAccessTokenNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        TJDropboxCredential *const credential = note.object;
        for (NSDictionary *const keychainAccount in [SAMKeychain accountsForService:kRHEADropboxAccountKey]) {
            NSString *const account = keychainAccount[kSAMKeychainAccountKey];
            TJDropboxCredential *const matchCredential = [[TJDropboxCredential alloc] initWithSerializedStringValue:[SAMKeychain passwordForService:kRHEADropboxAccountKey account:account]
                                                                                                   clientIdentifier:[[self class] _dropboxAppKey]];
            if ([matchCredential isEqual:credential]) {
                [SAMKeychain setPassword:credential.serializedStringValue forService:kRHEADropboxAccountKey account:account];
                break;
            }
        }
    }];
    [self updateCurrentDropboxAccountInformation];
    
    // Looks janky, but this touches the keychain entries we'll need to access prior to the menu being clicked.
    // If we attempt to access the keychain while the mouse click for the menu's being handled, the permission dialog that pops up won't receive any keyboard events. Which is bad.
    [self menuWillOpen:[NSMenu new]];
    
#ifndef NS_BLOCK_ASSERTIONS
    BOOL foundDropboxURL = NO;
    NSString *const dropboxURLString = [NSString stringWithFormat:@"db-%@", [[self class] _dropboxAppKey]];
    for (NSDictionary *schemeDictionary in [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"]) {
        if ([[schemeDictionary objectForKey:@"CFBundleURLSchemes"] containsObject:dropboxURLString]) {
            foundDropboxURL = YES;
            break;
        }
    }
    NSAssert(foundDropboxURL, @"You must add a URL scheme with the format \"db-yourDropboxAppKey\" in order for Rhea to authenticate with Dropbox correctly.");
#endif
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *const url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString *dropboxCode = nil;
    if ([url.absoluteString hasPrefix:@"db-"]) {
        for (NSURLQueryItem *const queryItem in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES].queryItems) {
            if ([queryItem.name isEqualToString:@"code"]) {
                dropboxCode = queryItem.value;
                break;
            }
        }
    }
    if (dropboxCode) {
        [TJDropbox credentialFromCode:dropboxCode
                  withClientIdentifier:[[self class] _dropboxAppKey]
                          codeVerifier:self.codeVerifier
                           redirectURL:[TJDropbox defaultTokenAuthenticationRedirectURLWithClientIdentifier:[[self class] _dropboxAppKey]]
                           completion:^(TJDropboxCredential * _Nullable credential, NSError * _Nullable error) {
            if (credential) {
                [TJDropbox getAccountInformationWithCredential:credential completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
                    NSString *const email = parsedResponse[@"email"];
                    NSString *message = nil;
                    if (email) {
                        message = @"Logged in to Dropbox!";
                        [SAMKeychain setPassword:credential.serializedStringValue forService:kRHEADropboxAccountKey account:email];
                    } else {
                        message = @"Unable to log into Dropbox";
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSAlert *const alert = [NSAlert new];
                        alert.messageText = message;
                        alert.informativeText = email;
                        [alert runModal];
                    });
                }];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *const alert = [NSAlert new];
                    alert.messageText = @"Unable to log into Dropbox";
                    [alert runModal];
                });
            }
        }];
        self.codeVerifier = nil;
    }
}

#pragma mark - Menu Management

- (void)menuWillOpen:(NSMenu *)menu
{
    [menu removeAllItems];
    
    NSMenuItem *recentsItem = [[NSMenuItem alloc] initWithTitle:@"Recents" action:nil keyEquivalent:@""];
    NSMenu *recentsMenu = [NSMenu new];
    recentsItem.submenu = recentsMenu;
    if (self.recentActions.count == 0) {
        NSMenuItem *noRecentsItem = [[NSMenuItem alloc] initWithTitle:@"No Recents" action:nil keyEquivalent:@""];
        noRecentsItem.enabled = NO;
        [recentsMenu addItem:noRecentsItem];
    } else {
        for (NSDictionary *recentAction in self.recentActions) {
            RHEAMenuItem *recentMenuItem = [[RHEAMenuItem alloc] initWithTitle:recentAction[kRHEARecentActionTitleKey] action:@selector(recentMenuItemClicked:) keyEquivalent:@""];
            recentMenuItem.context = recentAction;
            if (@available(macOS 26.0, *)) {
                NSString *imageName = recentAction[kRHEARecentActionSymbolNameKey];
                if (imageName) {
                    recentMenuItem.image = [NSImage imageWithSystemSymbolName:imageName accessibilityDescription:nil];
                }
            }
            [recentsMenu addItem:recentMenuItem];
        }
    }
    NSString *const currentDropboxAccount = [self currentDropboxAccount];
    if (currentDropboxAccount) {
        [recentsMenu addItem:[NSMenuItem separatorItem]];
        [recentsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"View more on Dropbox" action:@selector(recentsMenuItemClicked:) keyEquivalent:@""]];
    }
    [menu addItem:recentsItem];
    
    BOOL addedPasteItem = NO;
    
    if (@available(macOS 15.4, *)) {
        if ([[NSPasteboard generalPasteboard] accessBehavior] != NSPasteboardAccessBehaviorAlwaysAllow) {
            
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy link to clipboard" action:@selector(genericMenuItemClicked:) keyEquivalent:@""]];
            
            addedPasteItem = YES;
        }
    }
    
    if (!addedPasteItem) {
        id resolvedEntity = [self resolvePasteboard:[NSPasteboard generalPasteboard]];
        NSString *const string = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
        if ([resolvedEntity isKindOfClass:[NSString class]]) {
            if (currentDropboxAccount) {
                [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Upload copied file" action:@selector(uploadPasteboardMenuItemClicked:) keyEquivalent:@""]];
            }
        } else if ([resolvedEntity isKindOfClass:[NSURL class]]) {
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Shorten copied link" action:@selector(shortenPasteboardMenuItemClicked:) keyEquivalent:@""]];
        } else if ([string length] > 0) {
            [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Copy link to copied text" action:@selector(textMenuItemClicked:) keyEquivalent:@""]];
        }
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    
    NSMenuItem *const accountsItem = [[NSMenuItem alloc] initWithTitle:@"Accounts" action:nil keyEquivalent:@""];
    NSMenu *const accountsMenu = [NSMenu new];
    
    NSMenuItem *titleMenuItem = [[NSMenuItem alloc] initWithTitle:@"Dropbox Accounts" action:nil keyEquivalent:@""];
    titleMenuItem.enabled = NO;
    [accountsMenu addItem:titleMenuItem];
    NSArray *const dropboxAccounts = [SAMKeychain accountsForService:kRHEADropboxAccountKey];
    if (currentDropboxAccount) {
        for (NSDictionary *const account in dropboxAccounts) {
            NSString *const email = [account objectForKey:kSAMKeychainAccountKey];
            NSMenuItem *const menuItem = [[NSMenuItem alloc] initWithTitle:email action:@selector(accountMenuItemSelected:) keyEquivalent:@""];
            if ([email isEqualToString:currentDropboxAccount]) {
                menuItem.state = NSControlStateValueOn;
            }
            [accountsMenu addItem:menuItem];
        }
    }
    [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:@"Add Dropbox Account" action:@selector(authenticateDropboxMenuItemClicked:) keyEquivalent:@""]];
    if (currentDropboxAccount) {
        [accountsMenu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Sign out %@", currentDropboxAccount] action:@selector(signOutCurrentDropboxAccountMenuItemClicked:) keyEquivalent:@""]];
    }
    [accountsMenu addItem:[NSMenuItem separatorItem]];
    
    accountsItem.submenu = accountsMenu;
    [menu addItem:accountsItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]];
}

- (void)authenticateDropboxMenuItemClicked:(id)sender
{
    self.codeVerifier = [NSString stringWithFormat:@"%@-%@", [[NSUUID UUID] UUIDString], [[NSUUID UUID] UUIDString]];
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(setCodeVerifier:) object:nil];
    [self performSelector:@selector(setCodeVerifier:) withObject:nil afterDelay:60.0]; // You have 60 seconds to log in.
    [[NSWorkspace sharedWorkspace] openURL:[TJDropbox tokenAuthenticationURLWithClientIdentifier:[[self class] _dropboxAppKey] redirectURL:nil codeVerifier:self.codeVerifier generateRefreshToken:YES]];
}

- (void)accountMenuItemSelected:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:[(NSMenuItem *)sender title] forKey:kRHEACurrentDropboxAccountKey];
    
    [self updateCurrentDropboxAccountInformation];
}

- (void)signOutCurrentDropboxAccountMenuItemClicked:(id)sender
{
    [TJDropbox revokeCredential:[self dropboxCredential] withCallback:^(BOOL success, NSError * _Nullable error) {
        // no-op
    }];
    [SAMKeychain deletePasswordForService:kRHEADropboxAccountKey account:[self currentDropboxAccount]];
    [self updateCurrentDropboxAccountInformation];
}

- (void)recentsMenuItemClicked:(id)sender
{
    // http://stackoverflow.com/questions/381021/launch-safari-from-a-mac-application
    // TODO: Open in new tab.
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.dropbox.com/home/Apps/Rhea"]];
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

- (void)textMenuItemClicked:(id)sender
{
    NSString *const string = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    [self shortenText:string];
}

- (void)genericMenuItemClicked:(id)sender
{
    id resolvedEntity = [self resolvePasteboard:[NSPasteboard generalPasteboard]];
    NSString *const string = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
    if ([resolvedEntity isKindOfClass:[NSString class]]) {
        if ([self currentDropboxAccount]) {
            [self uploadFileAtPath:resolvedEntity];
        } else {
            NSAlert *const alert = [NSAlert new];
            alert.messageText = @"Dropbox sign in required";
            alert.informativeText = @"You must be logged in to Dropbox to upload files";
            [alert runModal];
        }
    } else if ([resolvedEntity isKindOfClass:[NSURL class]]) {
        [self shortenURL:resolvedEntity];
    } else if ([string length] > 0) {
        [self shortenText:string];
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

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification
{
    const NSTimeInterval kDismissDelay = 5.0;
    if (notification.identifier) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(undeliverNotification:) object:notification.identifier];
        [self performSelector:@selector(undeliverNotification:) withObject:notification.identifier afterDelay:kDismissDelay];
    } else {
        [[NSUserNotificationCenter defaultUserNotificationCenter] performSelector:@selector(removeDeliveredNotification:) withObject:notification afterDelay:kDismissDelay];
    }
}

- (void)undeliverNotification:(NSString *)identifier
{
    for (NSUserNotification *notification in [[NSUserNotificationCenter defaultUserNotificationCenter] deliveredNotifications]) {
        if ([notification.identifier isEqualToString:identifier]) {
            [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:notification];
        }
    }
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
    
    NSMutableArray *paths = [NSMutableArray array];
    for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
        NSString *urlString = [item stringForType:NSPasteboardTypeFileURL];
        if (urlString) {
            NSURL *url = [NSURL URLWithString:urlString];
            if (url.path) {
                [paths addObject:url.path];
            }
        }
    }
    id url = [pasteboard propertyListForType:NSPasteboardTypeURL];
    NSString *const string = [pasteboard stringForType:NSPasteboardTypeString];
    
    if (paths.count > 0) {
        if (paths.count == 1) {
            resolvedEntity = [RHEAEntityResolver resolveEntity:[paths firstObject]];
        }
    } else if (url) {
        resolvedEntity = [RHEAEntityResolver resolveEntity:url];
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
        if (([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0) {
            operation = NSDragOperationCopy;
        } else {
            operation = NSDragOperationLink;
        }
    } else if ([resolvedEntity isKindOfClass:[NSString class]]) {
        NSString *const extension = [resolvedEntity pathExtension];
        // https://superuser.com/a/298731 text files can be uploaded using TJURLShortener
        if (([NSEvent modifierFlags] & NSEventModifierFlagOption) && _isFileExtensionForTextFile(extension)) {
            operation = NSDragOperationLink;
        } else {
            operation = NSDragOperationCopy;
        }
    }
    
    return operation;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
    return [self draggingEntered:sender];
}

static BOOL _isFileExtensionForTextFile(NSString *const extension) {
    if (extension != nil) {
        NSString *str = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, kUTTypeText);
        return str != nil;
    }
    return NO;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    id resolvedEntity = [self resolveDraggingInfo:sender];
    
    BOOL didHandle = NO;
    
    // 1. See if this is a remote URL we'd like to copy (alt/option key)
    if ([resolvedEntity isKindOfClass:[NSURL class]] && ([NSEvent modifierFlags] & NSEventModifierFlagOption)) {
        [self saveFileAtURL:resolvedEntity];
        didHandle = YES;
    }
    
    // 2. Upload local file or shorten link
    if (!didHandle) {
        if ([resolvedEntity isKindOfClass:[NSString class]]) {
            NSString *const extension = [resolvedEntity pathExtension];
            // https://superuser.com/a/298731 text files can be uploaded using TJURLShortener
            if (([NSEvent modifierFlags] & NSEventModifierFlagOption) && _isFileExtensionForTextFile(extension)) {
                NSString *const text = [[NSString alloc] initWithContentsOfFile:resolvedEntity encoding:NSUTF8StringEncoding error:nil];
                [self shortenText:text];
            } else {
                [self uploadFileAtPath:resolvedEntity];
            }
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
    TJDropboxCredential *const currentCredential = [self dropboxCredential];
    NSString *const currentEmail = [self currentDropboxAccount];
    if (currentCredential && currentEmail) {
        [TJDropbox getAccountInformationWithCredential:currentCredential completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
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
                    [SAMKeychain setPassword:currentCredential.serializedStringValue forService:kRHEADropboxAccountKey account:email];
                }
            }
        }];
    }
    
}

- (TJDropboxCredential *)dropboxCredential
{
    NSString *const stringValue = [SAMKeychain passwordForService:kRHEADropboxAccountKey account:[self currentDropboxAccount]];
    return [[TJDropboxCredential alloc] initWithSerializedStringValue:stringValue
                                                     clientIdentifier:[[self class] _dropboxAppKey]];
}

NSData *SHA224HashOfFileAtURL(NSURL *fileURL, NSError **error) {
    const size_t bufferSize = 10 * 1024 * 1024; // 10MB buffer

    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:fileURL error:error];
    if (!fileHandle) {
        return nil;
    }

    CC_SHA256_CTX hashContext;
    CC_SHA224_Init(&hashContext);

    while (true) {
        @autoreleasepool {
            NSData *data = [fileHandle readDataOfLength:bufferSize];
            if (data.length == 0) {
                break; // EOF
            }
            CC_SHA224_Update(&hashContext, data.bytes, (CC_LONG)data.length);
        }
    }

    [fileHandle closeFile];

    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &hashContext);
    
    return [NSData dataWithBytes:digest length:CC_SHA224_DIGEST_LENGTH];
}

- (void)uploadFileAtPath:(NSString *const)path
{
    NSURL *const fileURL = [NSURL fileURLWithPath:path isDirectory:NO];
    NSString *const filename = [[fileURL URLByDeletingPathExtension] lastPathComponent];
    NSString *const extension = [fileURL pathExtension];
    
    NSData *const hashData = SHA224HashOfFileAtURL(fileURL, nil);
    
    if (hashData == nil) {
        // TODO: Error
        return;
    }
    
    // Append first 4 non-special characters of the base 64 SHA224 hash of the file contents to it.
    // Better than random because repeated uploads won't be stored multiple times.
    NSString *suffix = [hashData base64EncodedStringWithOptions:0];
    NSString *const fullSuffix = [suffix stringByReplacingOccurrencesOfString:@"/|\\+|=" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, suffix.length)];
    suffix = [fullSuffix substringToIndex:MIN(4, suffix.length)];
    
    __block NSString *fetchedURLString = nil;
    void (^notificationBlock)(NSString *title) = ^(NSString *title) {
        NSUserNotification *const notification = [NSUserNotification new];
        notification.title = title;
        notification.subtitle = filename;
        notification.informativeText = [[NSURL URLWithString:fetchedURLString] trimmedUserFacingString];
        notification.identifier = suffix;
        if ([extension caseInsensitiveCompare:@"png"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"jpg"] == NSOrderedSame || [extension caseInsensitiveCompare:@"gif"] == NSOrderedSame || [extension caseInsensitiveCompare:@"heic"] == NSOrderedSame) {
            notification.contentImage = [[NSImage alloc] initWithContentsOfFile:path];
        }
        notification.hasActionButton = YES;
        notification.actionButtonTitle = @"View";
        if (fetchedURLString) {
            notification.userInfo = @{kRHEANotificationURLStringKey: fetchedURLString};
        }
        [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
    };
    
    NSString *const remoteFilename = [NSString stringWithFormat:@"%@-%@%@", filename, suffix, extension.length > 0 ? [NSString stringWithFormat:@".%@", extension] : @""];
    NSString *const remotePath = [NSString stringWithFormat:@"/%@", remoteFilename];
    NSString *const shortURLHashSeed = [remoteFilename stringByAppendingFormat:@" %@", fullSuffix];
    
    // Begin uploading the file
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil][NSFileSize] unsignedLongLongValue];
    
    
    NSString *symbolName;
    TJDropboxSharedLinkType linkType;
    NSString *uti = nil;
    [fileURL getResourceValue:&uti
                       forKey:NSURLTypeIdentifierKey
                        error:nil];
    
    // https://chatgpt.com/share/6983a4a8-89a8-8008-b740-ab8cfbeb465c
    if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeImage)) {
        // Image
        symbolName = @"photo";
        linkType = TJDropboxSharedLinkTypeDirect;
    } else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeMovie)) {
        // Video
        symbolName = @"video";
        linkType = TJDropboxSharedLinkTypeDirect;
    } else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeAudio)) {
        linkType = TJDropboxSharedLinkTypeDirect;
        // Audio
        symbolName = @"headphones";
    } else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeText)) {
        // Text
        symbolName = @"text.document";
        linkType = TJDropboxSharedLinkTypeDefault;
    } else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeArchive)) {
        // Compressed / archive
        symbolName = @"zipper.page";
        linkType = TJDropboxSharedLinkTypeDefault;
    } else {
        // Fallback
        symbolName = @"document";
        linkType = TJDropboxSharedLinkTypeDefault;
    }
    
    void (^completionBlock)(NSDictionary *, NSError *) = ^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
        if (error) {
            [self handleDropboxError:error message:@"Couldn't upload file"];
        } else {
            notificationBlock(@"File uploaded");
            
            // Copy a short link
            [TJDropbox getSharedLinkForFileAtPath:remotePath linkType:linkType uploadOrSaveInProgress:NO credential:[self dropboxCredential] completion:^(NSString * _Nullable urlString) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (urlString) {
                        [TJURLShortener shortenURL:[NSURL URLWithString:urlString]
                                          hashSeed:shortURLHashSeed
                                        completion:^(NSURL * _Nullable shortenedURL, BOOL shortened) {
                            if (!shortened) {
                                return;
                            }
                            if (shortenedURL) {
                                NSString *const urlString = shortenedURL.absoluteString;
                                [self copyStringToPasteboard:urlString];
                                notificationBlock(@"Link shortened");
                                [self addRecentActionWithTitle:filename url:shortenedURL emoji:@"📄" symbolName:symbolName];
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    NSAlert *const alert = [NSAlert new];
                                    alert.messageText = @"Couldn't shorten link";
                                    alert.informativeText = path;
                                    [alert runModal];
                                });
                            }
                        }];
                    } else {
                        NSAlert *const alert = [NSAlert new];
                        alert.messageText = @"Couldn't generate Dropbox link";
                        alert.informativeText = path;
                        [alert runModal];
                    }
                });
            }];
        }
    };
    if (fileSize > 150 * 1024 * 1024) { // The docs state that no request should be larger than 150MB https://tijo.link/mQ2tVC
        [TJDropbox uploadLargeFileAtPath:path toPath:remotePath overwriteExisting:NO muteDesktopNotifications:YES credential:[self dropboxCredential] progressBlock:^(CGFloat progress) {
            // TODO: Show progress.
        } completion:completionBlock];
    } else {
        [TJDropbox uploadFileAtPath:path toPath:remotePath overwriteExisting:NO muteDesktopNotifications:YES credential:[self dropboxCredential] progressBlock:^(CGFloat progress) {
            // TODO: Show progress.
        } completion:completionBlock];
    }
    
    // Little white lie while still uploading.
    NSURL *const expectedShortURL = [TJURLShortener expectedShortURLForURL:nil hashSeed:shortURLHashSeed];
    fetchedURLString = expectedShortURL.absoluteString;
    [self copyStringToPasteboard:fetchedURLString];
    notificationBlock(@"Copied file link");
    [self addRecentActionWithTitle:filename url:expectedShortURL emoji:@"📄" symbolName:symbolName];
}

- (void)saveFileAtURL:(NSURL *const)url
{
    NSString *const filename = [[url URLByDeletingPathExtension] lastPathComponent];
    NSString *const extension = [url pathExtension];
    
    // Append first 4 non-special characters of the base 64 SHA224 hash of the file contents to it.
    // Better than random because repeated uploads won't be stored multiple times.
    unsigned char result[CC_SHA224_DIGEST_LENGTH];
    NSData *const data = [url.absoluteString dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA224(data.bytes, (CC_LONG)data.length, result);
    NSString *suffix = [[NSData dataWithBytes:result length:CC_SHA224_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    suffix = [suffix stringByReplacingOccurrencesOfString:@"/|\\+|=" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, suffix.length)];
    suffix = [suffix substringToIndex:MIN(4, suffix.length)];
    
    NSString *const remoteFilename = [NSString stringWithFormat:@"%@-%@%@", filename, suffix, extension.length > 0 ? [NSString stringWithFormat:@".%@", extension] : @""];
    NSString *const remotePath = [NSString stringWithFormat:@"/%@", remoteFilename];
    
    // Copy the file
    [TJDropbox saveContentsOfURL:url toPath:remotePath credential:[self dropboxCredential] completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
        if (error) {
            [self handleDropboxError:error message:@"Couldn't copy file to Dropbox"];
        }
    }];
    
    // Copy a short link
    [TJDropbox getSharedLinkForFileAtPath:remotePath linkType:TJDropboxSharedLinkTypeDefault uploadOrSaveInProgress:YES credential:[self dropboxCredential] completion:^(NSString * _Nullable urlString) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (urlString) {
                [self copyStringToPasteboard:urlString];
                
                NSUserNotification *const notification = [NSUserNotification new];
                notification.title = @"Copied file link";
                notification.subtitle = filename;
                notification.informativeText = [[NSURL URLWithString:urlString] trimmedUserFacingString];
                
                notification.hasActionButton = YES;
                notification.actionButtonTitle = @"View";
                notification.userInfo = @{kRHEANotificationURLStringKey: urlString};
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                
                [self addRecentActionWithTitle:filename url:[NSURL URLWithString:urlString] emoji:@"📄" symbolName:@"document.on.document"]; // TODO: Maybe use file extension to vary this icon
            } else {
                NSAlert *const alert = [NSAlert new];
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
                NSAlert *const alert = [NSAlert new];
                alert.messageText = message;
                [alert runModal];
            });
        }
    }
}

#pragma mark - Link Shortening

- (void)shortenURL:(NSURL *const)url
{
    void (^completion)(NSURL *shortenedURL, BOOL shortened) = ^(NSURL *shortenedURL, BOOL shortened) {
        if (shortenedURL) {
            [self copyStringToPasteboard:shortenedURL.absoluteString];
            
            NSUserNotification *const notification = [NSUserNotification new];
            notification.identifier = url.absoluteString;
            if (shortened) {
                notification.title = @"Link shortened";
            } else {
                notification.title = @"Copied link";
            }
            notification.subtitle = url.absoluteString;
            notification.informativeText = [shortenedURL trimmedUserFacingString];
            notification.hasActionButton = YES;
            notification.actionButtonTitle = @"View";
            notification.userInfo = @{kRHEANotificationURLStringKey: shortenedURL.absoluteString};
            [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
            
            [self addRecentActionWithTitle:[url trimmedUserFacingString] url:shortenedURL emoji:@"🔗" symbolName:@"link"];
        } else {
            NSAlert *const alert = [NSAlert new];
            alert.messageText = @"Couldn't shorten link";
            alert.informativeText = url.absoluteString;
            [alert runModal];
        }
    };
    [TJURLShortener shortenURL:url
                    completion:^(NSURL * _Nullable shortenedURL, BOOL shortened) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(shortenedURL, shortened);
        });
    }];
}
    
- (void)shortenText:(NSString *const)text
{
    [TJURLShortener shortenText:text completion:^(NSURL * _Nullable longURL, NSURL * _Nullable shortenedURL, BOOL shortened) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *url = shortenedURL ?: longURL;
            if (url) {
                [self copyStringToPasteboard:url.absoluteString];
                
                NSUserNotification *const notification = [NSUserNotification new];
                notification.identifier = longURL.absoluteString;
                if (shortened && shortenedURL != nil) {
                    notification.title = @"Link saved";
                } else {
                    notification.title = @"Copied link";
                }
                notification.subtitle = text;
                notification.informativeText = [url trimmedUserFacingString];
                notification.hasActionButton = YES;
                notification.actionButtonTitle = @"View";
                notification.userInfo = @{kRHEANotificationURLStringKey: url.absoluteString};
                [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
                
                [self addRecentActionWithTitle:text url:url emoji:@"📝" symbolName:@"text.word.spacing"];
            } else {
                NSAlert *const alert = [NSAlert new];
                alert.messageText = @"Couldn't create text link";
                alert.informativeText = text;
                [alert runModal];
            }
        });
    }];
}

#pragma mark - Recents

- (void)addRecentActionWithTitle:(NSString *)title
                             url:(NSURL *)url
                           emoji:(NSString *)emoji
                      symbolName:(NSString *)symbolName
{
    // Don't add duplicates
    for (NSDictionary *const recentAction in self.recentActions) {
        if ([recentAction[kRHEARecentActionURLKey] isEqual:url]) {
            return;
        }
    }
    
    if (@available(macOS 26.0, *)) {
    } else {
        title = [emoji stringByAppendingFormat:@" %@", title];
    }
    
    NSMutableDictionary *action = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   title, kRHEARecentActionTitleKey,
                                   url, kRHEARecentActionURLKey,
                                   nil];
    
    if (symbolName) {
        action[kRHEARecentActionSymbolNameKey] = symbolName;
    }
    
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
    NSURL *const url = action[kRHEARecentActionURLKey];
    NSString *const urlString = [url absoluteString];
    [self copyStringToPasteboard:urlString];
    
    NSUserNotification *const notification = [NSUserNotification new];
    notification.title = @"Copied link";
    notification.subtitle = action[kRHEARecentActionTitleKey];
    notification.informativeText = [url trimmedUserFacingString];
    notification.hasActionButton = YES;
    notification.actionButtonTitle = @"View";
    notification.userInfo = @{kRHEANotificationURLStringKey: urlString};
    [[NSUserNotificationCenter defaultUserNotificationCenter] scheduleNotification:notification];
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

#pragma mark - Keys

+ (NSString *)_dropboxAppKey
{
    NSAssert(NO, @"%s must be filled in", __PRETTY_FUNCTION__);
    return @"";
}

@end
