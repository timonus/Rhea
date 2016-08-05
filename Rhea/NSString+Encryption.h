//
//  NSString+Encryption.h
//  Checkie
//
//  Created by Tim Johnsen on 7/5/16.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Encryption)

#if DEBUG

- (NSString *)encryptedStringWithKey:(NSString *const)key;

#endif

- (NSString *)decryptedStringWithKey:(NSString *const)key;

@end

NS_ASSUME_NONNULL_END
