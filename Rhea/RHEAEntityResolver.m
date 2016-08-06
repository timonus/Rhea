//
//  RHEAEntityResolver.m
//  Rhea
//
//  Created by Tim Johnsen on 8/5/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "RHEAEntityResolver.h"

@implementation RHEAEntityResolver

+ (id)resolveEntity:(id)entity
{
    id result = nil;
    if ([entity isKindOfClass:[NSString class]]) {
        result = [self resolvePath:entity];
    } else if ([entity isKindOfClass:[NSURL class]]) {
        result = [self resolveURL:entity];
    }
    return result;
}

+ (id)resolvePath:(NSString *const)path
{
    id result = nil;
    NSString *const extension = [[NSURL fileURLWithPath:path] pathExtension];
    if ([extension isEqualToString:@"webloc"]) {
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:path] options:0 format:nil error:nil];
        NSURL *const url = [NSURL URLWithString:plist[@"URL"]];
        result = [self resolveURL:url];
    } else {
        result = path;
    }
    return result;
}

+ (id)resolveURL:(NSURL *const)url
{
    id result = nil;
    if ([url.scheme isEqualToString:@"file"]) {
        result = [self resolvePath:url.path];
    } else {
        result = url;
    }
    return result;
}

@end
