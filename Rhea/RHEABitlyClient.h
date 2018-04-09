//
//  RHEABitlyClient.h
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RHEABitlyClient : NSObject

// Authentication
+ (NSURL *)authenticationURLWithClientIdentifier:(NSString *const)clientIdentifier redirectURL:(NSURL *const)redirectURL;
+ (NSString *)accessCodeFromURL:(NSURL *const)url redirectURL:(NSURL *const)redirectURL;
+ (void)authenticateWithCode:(NSString *const)code
            clientIdentifier:(NSString *const)clientIdentifier
                clientSecret:(NSString *const)clientSecret
                 redirectURL:(NSURL *const)redirectURL
                  completion:(void (^)(NSString *_Nullable accessToken))completion;

// Shortening
+ (void)shortenURL:(NSURL *const)url accessToken:(NSString *const)accessToken completion:(void (^)(NSURL *_Nullable shortenedURL))completion;

@end

NS_ASSUME_NONNULL_END
