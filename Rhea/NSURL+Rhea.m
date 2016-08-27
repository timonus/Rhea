//
//  NSURL+Rhea.m
//  Rhea
//
//  Created by Tim Johnsen on 8/27/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "NSURL+Rhea.h"

@implementation NSURL (Rhea)

- (NSString *)trimmedUserFacingString
{
    NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:YES];
    components.scheme = nil;
    components.host = [components.host stringByReplacingOccurrencesOfString:@"www." withString:@""];
    components.queryItems = nil;
    return components.URL.absoluteString;
}

@end
