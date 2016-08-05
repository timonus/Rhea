//
//  RHEAGoogleClient.h
//  Rhea
//
//  Created by Tim Johnsen on 8/4/16.
//  Copyright © 2016 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RHEAGoogleClient : NSObject

+ (void)shortenURL:(NSURL *const)url completion:(void (^)(NSURL *shortenedURL))completion;

@end

NS_ASSUME_NONNULL_END
