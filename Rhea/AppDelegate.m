//
//  AppDelegate.m
//  Rhea
//
//  Created by Tim Johnsen on 8/3/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "AppDelegate.h"

// Building a status bar app: https://www.raywenderlich.com/98178/os-x-tutorial-menus-popovers-menu-bar-apps
// Hiding the dock icon: http://stackoverflow.com/questions/620841/how-to-hide-the-dock-icon

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (nonatomic, strong) NSStatusItem *statusItem;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.image = [NSImage imageNamed:@"StatusBarButtonImage"];
    self.statusItem.button.action = @selector(statusItemClicked:);
    
    NSMenu *const menu = [[NSMenu alloc] init];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Recents" action:@selector(recentsMenuItemClicked:) keyEquivalent:@""]];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItem:[[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]];
    self.statusItem.menu = menu;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
}

- (void)statusItemClicked:(id)sender
{
    
}

- (void)recentsMenuItemClicked:(id)sender
{
    // http://stackoverflow.com/questions/381021/launch-safari-from-a-mac-application
    // TODO: Open in new tab.
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.dropbox.com/recents"]];
}

@end
