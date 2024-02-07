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

// Shortening
+ (void)shortenURL:(NSURL *const)url
        completion:(void (^)(NSURL *_Nullable shortenedURL, BOOL shortened))completion;

@end

NS_ASSUME_NONNULL_END
