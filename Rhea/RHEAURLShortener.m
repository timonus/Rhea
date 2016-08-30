//
//  RHEAURLShortener.m
//  Rhea
//
//  Created by Tim Johnsen on 8/4/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import "RHEAURLShortener.h"

static NSString *const kRHEAGoogleKey = @"";

@implementation RHEAURLShortener

+ (void)shortenURL:(NSURL *const)url completion:(void (^)(NSURL *shortenedURL))completion
{
    // https://is.gd/apishorteningreference.php
    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://v.gd/create.php"];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"url" value:url.absoluteString],
        [NSURLQueryItem queryItemWithName:@"format" value:@"json"]
    ];
    [[[NSURLSession sharedSession] dataTaskWithURL:components.URL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        id responseObject = nil;
        if (data.length > 0) {
            responseObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        NSString *resultURLString = nil;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            id responseShortURLObject = responseObject[@"shorturl"];
            if ([responseShortURLObject isKindOfClass:[NSString class]]) {
                resultURLString = responseShortURLObject;
            }
        }
        NSURL *resultURL = [NSURL URLWithString:resultURLString];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(resultURL);
        });
    }] resume];
}

+ (void)googleShortenURL:(NSURL *const)url completion:(void (^)(NSURL *shortenedURL))completion
{
    // https://developers.google.com/url-shortener/
    NSMutableURLRequest *const request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.googleapis.com/urlshortener/v1/url?key=%@", kRHEAGoogleKey]]];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{@"longUrl": url.absoluteString} options:0 error:nil]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        id responseObject = nil;
        if (data.length > 0) {
            responseObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
        NSString *resultURLString = nil;
        if ([responseObject isKindOfClass:[NSDictionary class]]) {
            id responseShortURLObject = responseObject[@"id"];
            if ([responseShortURLObject isKindOfClass:[NSString class]]) {
                resultURLString = responseShortURLObject;
            }
        }
        NSURL *resultURL = nil;
        if (resultURLString) {
            NSURLComponents *const resultURLComponents = [NSURLComponents componentsWithString:resultURLString];
            resultURLComponents.scheme = @"https";
            resultURL = resultURLComponents.URL;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(resultURL);
        });
    }] resume];
}

@end
