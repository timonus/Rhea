//
//  AppDelegate.m
//  Rhea
//
//  Created by Tim Johnsen on 8/3/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "AppDelegate.h"

#import "TJDropbox.h"

// Building a status bar app: https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps
// Hiding the dock icon: http://stackoverflow.com/questions/620841/how-to-hide-the-dock-icon
// Handling incoming URLs: http://fredandrandall.com/blog/2011/07/30/how-to-launch-your-macios-app-with-a-custom-url/
// Drag drop into status bar: http://stackoverflow.com/a/26810727/3943258

static NSString *const kRHEADropboxAppKey = @"";
static NSString *const kRHEADropboxRedirectURLString = @"";

static NSString *const kRHEADropboxTokenKey = @"dropboxToken";

@interface AppDelegate () <NSWindowDelegate>

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusItem;

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
    self.statusItem.button.action = @selector(statusItemClicked:);
    
    [self.statusItem.button.window registerForDraggedTypes:@[NSFilenamesPboardType]];
    self.statusItem.button.window.delegate = self;
    
    [self updateMenu];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSURL *const url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString *const dropboxToken = [TJDropbox accessTokenFromURL:url withRedirectURL:[NSURL URLWithString:@"rhea-dropbox-auth://dropboxauth"]];
    
    if (dropboxToken) {
        [[NSUserDefaults standardUserDefaults] setObject:dropboxToken forKey:kRHEADropboxTokenKey];
        [self updateMenu];
        
        NSAlert *const alert = [[NSAlert alloc] init];
        alert.messageText = @"Logged in to Dropbox!";
        [alert runModal];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

#pragma mark - Menu Management

- (void)statusItemClicked:(id)sender
{
    // no-op
}

- (void)updateMenu
{
    NSMenu *const menu = [[NSMenu alloc] init];
    if ([self dropboxToken]) {
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Recents" action:@selector(recentsMenuItemClicked:) keyEquivalent:@""]];
    } else {
        [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Log in to Dropbox" action:@selector(authenticateMenuItemClicked:) keyEquivalent:@""]];
    }
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]];
    self.statusItem.menu = menu;
}

- (void)authenticateMenuItemClicked:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[TJDropbox tokenAuthenticationURLWithClientIdentifier:kRHEADropboxAppKey redirectURL:[NSURL URLWithString:kRHEADropboxRedirectURLString]]];
}

- (void)recentsMenuItemClicked:(id)sender
{
    // http://stackoverflow.com/questions/381021/launch-safari-from-a-mac-application
    // TODO: Open in new tab.
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.dropbox.com/recents"]];
}

#pragma mark - Drag & Drop

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    // http://stackoverflow.com/a/423702/3943258
    
    NSArray *const paths = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    
    if (paths.count == 1) {
        NSString *const path = [paths firstObject];
        
        NSURL *const fileURL = [NSURL fileURLWithPath:path];
        NSString *const filename = [[fileURL URLByDeletingPathExtension] lastPathComponent];
        NSString *const extension = [fileURL pathExtension];
        NSString *const suffix = [self randomSuffix];
        NSString *const remoteFilename = [NSString stringWithFormat:@"%@-%@%@", filename, suffix, extension.length > 0 ? [NSString stringWithFormat:@".%@", extension] : @""];
        NSString *const remotePath = [NSString stringWithFormat:@"/%@", remoteFilename];
        
        // Begin uploading the file
        [TJDropbox uploadFileAtPath:path toPath:remotePath accessToken:[self dropboxToken] completion:^(NSDictionary * _Nullable parsedResponse, NSError * _Nullable error) {
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *const alert = [[NSAlert alloc] init];
                    alert.messageText = @"Couldn't upload file";
                    alert.informativeText = path;
                    [alert runModal];
                });
            }
        }];
        
        // Copy a short link
        [TJDropbox getShortSharedLinkForFileAtPath:remotePath accessToken:[self dropboxToken] completion:^(NSString * _Nullable urlString) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (urlString) {
                    [[NSPasteboard generalPasteboard] clearContents];
                    [[NSPasteboard generalPasteboard] writeObjects:@[urlString]];
                } else {
                    NSAlert *const alert = [[NSAlert alloc] init];
                    alert.messageText = @"Couldn't copy link";
                    alert.informativeText = path;
                    [alert runModal];
                }
            });
        }];
    } else {
        NSAlert *const alert = [[NSAlert alloc] init];
        alert.messageText = @"Multiple files aren't supported at this time.";
        [alert runModal];
    }
    
    return YES;
}

#pragma mark - Dropbox

- (NSString *)dropboxToken
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kRHEADropboxTokenKey];
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

@end
