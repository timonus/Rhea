//
//  NSString+Encryption.m
//  Checkie
//
//  Created by Tim Johnsen on 7/5/16.
//
//

#import "NSString+Encryption.h"
#import <CommonCrypto/CommonCryptor.h>

// http://stackoverflow.com/a/34861465
// http://pastie.org/426530

@interface NSData (AES256)

#if DEBUG

- (NSData *)AES256EncryptWithKey:(NSString *)key;

#endif

- (NSString *)AES256DecryptWithKey:(NSString *)key;

@end

@implementation NSData (AES256)

#if DEBUG

- (NSData *)AES256EncryptWithKey:(NSString *)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesEncrypted];
//        return [[NSString alloc] initWithBytesNoCopy:buffer length:numBytesEncrypted encoding:NSUTF8StringEncoding freeWhenDone:YES];
    }
    
    free(buffer); //free the buffer;
    return nil;
}

#endif

- (NSString *)AES256DecryptWithKey:(NSString *)key {
    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)
    
    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];
    
    NSUInteger dataLength = [self length];
    
    //See the doc: For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    
    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256,
                                          NULL /* initialization vector (optional) */,
                                          [self bytes], dataLength, /* input */
                                          buffer, bufferSize, /* output */
                                          &numBytesDecrypted);
    
    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
//        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
        return [[NSString alloc] initWithBytesNoCopy:buffer length:numBytesDecrypted encoding:NSUTF8StringEncoding freeWhenDone:YES];
    }
    
    free(buffer); //free the buffer;
    return nil;
}

@end

@implementation NSString (Encryption)

#if DEBUG

- (NSString *)encryptedStringWithKey:(NSString *const)key
{
    NSData *data = [[self dataUsingEncoding:NSUTF8StringEncoding] AES256EncryptWithKey:key];
    return [data base64EncodedStringWithOptions:kNilOptions];
}

#endif

- (NSString *)decryptedStringWithKey:(NSString *const)key
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:self options:kNilOptions];
    return [data AES256DecryptWithKey:key];
}

@end
