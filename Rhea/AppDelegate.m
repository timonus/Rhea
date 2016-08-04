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

static NSString *const kRHEADropboxAppKey = @"";
static NSString *const kRHEADropboxRedirectURLString = @"";

static NSString *const kRHEADropboxTokenKey = @"dropboxToken";

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Handle incoming URLs
    [[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kInternetEventClass];
    
    // Set up our status bar icon and menu
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"StatusBarButtonImage"];
    self.statusItem.button.action = @selector(statusItemClicked:);
    
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

- (NSString *)dropboxToken
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:kRHEADropboxTokenKey];
}

@end
