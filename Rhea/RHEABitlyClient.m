//
//  RHEABitlyClient.m
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "RHEABitlyClient.h"
#import "NSString+Encryption.h"

@implementation RHEABitlyClient

//+ (NSURL *)authenticationURLWithClientIdentifier:(NSString *)clientIdentifier redirectURL:(NSURL *)redirectURL
//{
//    NSURLComponents *const components = [[NSURLComponents alloc] initWithString:@"https://bitly.com/oauth/authorize"];
//    components.queryItems = @[[NSURLQueryItem queryItemWithName:@"client_id" value:clientIdentifier],
//                              [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirectURL.absoluteString]];
//    return components.URL;
//}
//
//+ (NSString *)accessCodeFromURL:(NSURL *const)url redirectURL:(NSURL *const)redirectURL
//{
//    NSString *code = nil;
//    if ([url.absoluteString hasPrefix:redirectURL.absoluteString]) {
//        NSURLComponents *const components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:YES];
//        for (NSURLQueryItem *queryItem in components.queryItems) {
//            if ([queryItem.name isEqualToString:@"code"]) {
//                code = queryItem.value;
//                break;
//            }
//        }
//    }
//    return code;
//}
//
//+ (void)authenticateWithCode:(NSString *const)code
//            clientIdentifier:(NSString *const)clientIdentifier
//                clientSecret:(NSString *const)clientSecret
//                 redirectURL:(NSURL *const)redirectURL
//                  completion:(void (^)(NSString *accessToken, NSString *groupIdentifier))completion
//{
//    NSMutableURLRequest *const request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api-ssl.bitly.com/oauth/access_token"]];
//    request.HTTPMethod = @"POST";
//    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
//    NSURLComponents *const bodyComponents = [NSURLComponents new];
//    bodyComponents.queryItems = @[[NSURLQueryItem queryItemWithName:@"client_id" value:clientIdentifier],
//                                  [NSURLQueryItem queryItemWithName:@"client_secret" value:clientSecret],
//                                  [NSURLQueryItem queryItemWithName:@"code" value:code],
//                                  [NSURLQueryItem queryItemWithName:@"redirect_uri" value:redirectURL.absoluteString],
//                                  [NSURLQueryItem queryItemWithName:@"grant_type" value:@"authorization_code"]];
//    NSString *const bodyString = [bodyComponents.URL.absoluteString substringFromIndex:1];
//    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
//    [[[NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//        NSString *accessToken = nil;
//        if (data.length > 0) {
//            NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//            NSURLComponents *components = [NSURLComponents new];
//            components.query = string;
//            for (NSURLQueryItem *queryItem in components.queryItems) {
//                if ([queryItem.name isEqualToString:@"access_token"]) {
//                    accessToken = queryItem.value;
//                    break;
//                }
//            }
//        }
//        if (accessToken) {
//            
//            // TODO: Make Rhea Bitly group-aware.
//            // Right now we implicitly always select the first group.
//            
//            NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://api-ssl.bitly.com/v4/groups"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
//            [request setValue:[NSString stringWithFormat:@"Bearer %@", accessToken] forHTTPHeaderField:@"Authorization"];
//            [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//                NSString *groupIdentifier = nil;
//                if (data.length > 0) {
//                    id resultObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
//                    if ([resultObject isKindOfClass:[NSDictionary class]] && [resultObject[@"groups"] isKindOfClass:[NSArray class]] && [resultObject[@"groups"] count] > 0) {
//                        groupIdentifier = [[resultObject[@"groups"] firstObject] objectForKey:@"guid"];
//                    }
//                }
//                dispatch_async(dispatch_get_main_queue(), ^{
//                    completion(accessToken, groupIdentifier);
//                });
//            }] resume];
//        } else {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                completion(nil, nil);
//            });
//        }
//    }] resume];
//}

+ (void)shortenURL:(NSURL *const)url
//   groupIdentifier:(NSString *const)groupIdentifier
//       accessToken:(NSString *const)accessToken
        completion:(void (^)(NSURL *_Nullable shortenedURL))completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"HTUG2SN0GmdaoZDwK8tIyFDqkxPiG56W7SKUTp6tiUbis57lhjFplTVW7uoIP+M+TCsf7VEBU9TCSaNfX0NSvg==" decryptedStringWithKey:NSStringFromClass([self class])]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{
        @"url_long": url.absoluteString
    } options:0 error:nil]];
    [request setHTTPMethod:@"POST"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSURL *result = nil;
        if (data.length > 0) {
            id resultObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([resultObject isKindOfClass:[NSDictionary class]] && [resultObject[@"url_short"] isKindOfClass:[NSString class]]) {
                result = [NSURL URLWithString:resultObject[@"url_short"]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result);
        });
    }] resume];
}

@end
