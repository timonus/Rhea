//
//  RHEAMenuItem.h
//  Rhea
//
//  Created by Tim Johnsen on 8/27/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RHEAMenuItem : NSMenuItem

@property (nonatomic, strong) NSDictionary *context; // I know, ambiguous.

@end
