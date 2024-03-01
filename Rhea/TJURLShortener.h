//
//  TJURLShortener.h
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

__attribute__((objc_direct_members))
@interface TJURLShortener : NSObject

+ (void)configureWithKey:(NSString *const)key host:(NSString *const)host userDefaults:(NSUserDefaults *const)userDefaults;

// Shortening
+ (NSURL *)expectedShortURLFor:(NSURL *const)url;

+ (void)shortenURL:(NSURL *const)url
        completion:(void (^)(NSURL *_Nullable shortenedURL, BOOL shortened))completion;

@end

NS_ASSUME_NONNULL_END
