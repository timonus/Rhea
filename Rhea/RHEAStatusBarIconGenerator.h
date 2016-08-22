//
//  RHEAStatusBarIconGenerator.h
//  Rhea
//
//  Created by Tim Johnsen on 8/21/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RHEAStatusBarIconGenerator : NSObject

+ (NSImage *)imageWithUploadPercent:(CGFloat const)percent;

@end
