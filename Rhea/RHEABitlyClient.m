//
//  RHEABitlyClient.m
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "RHEABitlyClient.h"

@implementation RHEABitlyClient

+ (NSURL *)authenticationURLWithClientIdentifier:(NSString *)clientIdentifier redirectURL:(NSURL *)redirectURL
{
    NSURLComponents *const components = [[NSURLComponents alloc] initWithString:@"https://bitly.com/oauth/authorize"];
    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"client_id" value:clientIdentifier],
                              [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirectURL.absoluteString]];
    return components.URL;
}

+ (NSString *)accessCodeFromURL:(NSURL *const)url redirectURL:(NSURL *const)redirectURL
{
    NSString *code = nil;
    if ([url.absoluteString hasPrefix:redirectURL.absoluteString]) {
        NSURLComponents *const components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
        for (NSURLQueryItem *queryItem in components.queryItems) {
            if ([queryItem.name isEqualToString:@"code"]) {
                code = queryItem.value;
                break;
            }
        }
    }
    return code;
}

+ (void)authenticateWithCode:(NSString *const)code
            clientIdentifier:(NSString *const)clientIdentifier
                clientSecret:(NSString *const)clientSecret
                 redirectURL:(NSURL *const)redirectURL
                  completion:(void (^)(NSString *accessToken))completion
{
    NSMutableURLRequest *const request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api-ssl.bitly.com/oauth/access_token"]];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSURLComponents *const bodyComponents = [NSURLComponents new];
    bodyComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"client_id" value:clientIdentifier],
                                  [NSURLQueryItem queryItemWithName:@"client_secret" value:clientSecret],
                                  [NSURLQueryItem queryItemWithName:@"code" value:code],
                                  [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirectURL.absoluteString],
                                  [NSURLQueryItem queryItemWithName:@"grant_type" value:@"authorization_code"]];
    NSString *const bodyString = [bodyComponents.URL.absoluteString substringFromIndex:1];
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    [[[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSString *accessToken = nil;
        if (data.length > 0) {
            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSURLComponents *components = [NSURLComponents new];
            components.query = string;
            for (NSURLQueryItem *queryItem in components.queryItems) {
                if ([queryItem.name isEqualToString:@"access_token"]) {
                    accessToken = queryItem.value;
                    break;
                }
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(accessToken);
        });
    }] resume];
}

+ (void)shortenURL:(NSURL *const)url accessToken:(NSString *const)accessToken completion:(void (^)(NSURL *_Nullable shortenedURL))completion
{
    NSURLComponents *const components = [[NSURLComponents alloc] initWithString:@"https://api-ssl.bitly.com/v3/shorten"];
    components.queryItems = @[
                              [NSURLQueryItem queryItemWithName:@"access_token" value:accessToken],
                              [NSURLQueryItem queryItemWithName:@"longUrl" value:url.absoluteString]
                              ];
    [[[NSURLSession sharedSession] dataTaskWithURL:components.URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSString *urlString = nil;
        if (data.length > 0) {
            id resultObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([resultObject isKindOfClass:[NSDictionary class]] && [resultObject[@"data"] isKindOfClass:[NSDictionary class]]) {
                urlString = [resultObject[@"data"][@"url"] stringByReplacingOccurrencesOfString:@"http://" withString:@"https://"];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSURL URLWithString:urlString]);
        });
    }] resume];
}

@end
