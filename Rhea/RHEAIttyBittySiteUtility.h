//
//  RHEAIttyBittySiteUtility.h
//  Rhea
//
//  Created by Tim Johnsen on 7/5/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RHEAIttyBittySiteUtility : NSObject

+ (NSURL *)generateIttyBittySiteURLWithTitle:(nullable NSString *const)title
                                        body:(NSString *const)body;

@end

NS_ASSUME_NONNULL_END
