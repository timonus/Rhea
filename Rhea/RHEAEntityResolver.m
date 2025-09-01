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
        NSURLComponents *const components = [[NSURLComponents alloc] initWithString:[(NSString *)entity stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        components.fragment = [components.fragment stringByRemovingPercentEncoding]; // Fix strings with text highlights like https://objectionable-c.com/posts/shrink-static-files/#:~:text=What’s%20fun%20about%20these%20scripts%20is (these get double-encoded somehow)
        NSURL *const url = components.URL;
        if (url.scheme.length > 0) { // -URLWithString: parses file paths successfully, check the scheme to ensure it's not just a path.
            result = [self resolveURL:url];
        } else {
            result = [self resolvePath:entity];
        }
    } else if ([entity isKindOfClass:[NSURL class]]) {
        result = [self resolveURL:entity];
    }
    return result;
}

+ (id)resolvePath:(NSString *const)path
{
    id result = nil;
    NSString *const extension = [[NSURL fileURLWithPath:path isDirectory:NO] pathExtension];
    if ([extension isEqualToString:@"webloc"]) {
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:path] options:0 format:nil error:nil];
        NSURL *const url = [NSURL URLWithString:plist[@"URL"]];
        result = [self resolveURL:url];
    } else {
        BOOL isDirectory = NO;
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory];
        if (fileExists && !isDirectory) {
            result = path;
        }
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
