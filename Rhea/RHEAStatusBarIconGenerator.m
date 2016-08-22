//
//  RHEAStatusBarIconGenerator.m
//  Rhea
//
//  Created by Tim Johnsen on 8/21/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "RHEAStatusBarIconGenerator.h"
#import <AppKit/AppKit.h>

// http://stackoverflow.com/a/12270398/3943258

@implementation RHEAStatusBarIconGenerator

+ (NSImage *)imageWithUploadPercent:(CGFloat const)percent
{
    const CGFloat length = 22.0;
    const NSSize iconSize = NSMakeSize(length, length);
    NSBitmapImageRep *const imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:nil pixelsWide:iconSize.width pixelsHigh:iconSize.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSImage *const image = [[NSImage alloc] initWithSize:iconSize];
    [image addRepresentation:imageRep];
    
    [image lockFocus];
    
    // Draw
    
    const CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    static const CGFloat kInset = 4.0;
    
    CGContextSaveGState(context);
    NSBezierPath *const path = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(kInset, kInset, iconSize.width - 2.0 * kInset, iconSize.width - 2.0 * kInset)];
    CGContextSetFillColorWithColor(context, [[NSColor colorWithWhite:0.0 alpha:0.3] CGColor]);
    [path fill];
    [path addClip];
    [path appendBezierPath:[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(kInset + 5.0, kInset - 5.0, iconSize.width - 2.0 * kInset, iconSize.width - 2.0 * kInset)] bezierPathByReversingPath]];
    CGContextSetFillColorWithColor(context, [[NSColor blackColor] CGColor]);
    [path fill];
    CGContextRestoreGState(context);
    
    if (percent > 0.0) {
        CGContextSetStrokeColorWithColor(context, [[NSColor colorWithWhite:0.0 alpha:0.6] CGColor]);
        const CGFloat radius = length / 2.0 - (kInset - 2.0);
        const CGFloat endAngle = M_PI_2 - (2.0 * M_PI * percent);
        CGContextAddArc(context, length / 2.0, length / 2.0, radius, M_PI_2, endAngle, YES);
        CGContextStrokePath(context);
    }
    
    [image unlockFocus];
    
    return image;
}

@end
