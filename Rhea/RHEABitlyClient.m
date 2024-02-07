//
//  RHEABitlyClient.m
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "RHEABitlyClient.h"
#import "NSString+Encryption.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>



@interface RHEABitlyClient () <NSURLSessionDataDelegate>

@end

@implementation RHEABitlyClient

+ (instancetype)taskDelegate
{
    static RHEABitlyClient *taskDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taskDelegate = [self new];
    });
    return taskDelegate;
}

+ (NSURL *)expectedShortURLFor:(NSURL *const)url
{
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:@"https://tijo.link"];
    
    unsigned char result[CC_SHA224_DIGEST_LENGTH];
    NSString *const input = [url.absoluteString stringByAppendingString:@" vUeUXfC*YX4dPibi2iwf.dmv!U-XxcRV2ZgB@ePKN.a3m*gBqiW_QJM!ehHRjEw4FmFhZgiZRGBTVL9!zq7owHx*HvU-QYW8KXL@"]; // TODO: Encrypt
    NSData *const data = [input dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA224(data.bytes, (CC_LONG)data.length, result);
    NSString *suffix = [[NSData dataWithBytes:result length:CC_SHA224_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    suffix = [suffix stringByReplacingOccurrencesOfString:@"/|\\+|=" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, suffix.length)];
    suffix = [suffix substringToIndex:MIN(6, suffix.length)];
    
    components.path = [@"/" stringByAppendingString:suffix];
    
    return components.URL;
}

static char *const kCompletionKey = "rheaCompletion";
static char *const kDataKey = "rheaData";

+ (void)shortenURL:(NSURL *const)url
        completion:(void (^)(NSURL *_Nullable shortenedURL, BOOL shortened))completion
{
    completion([self expectedShortURLFor:url], NO);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"HTUG2SN0GmdaoZDwK8tIyFDqkxPiG56W7SKUTp6tiUbis57lhjFplTVW7uoIP+M+TCsf7VEBU9TCSaNfX0NSvg==" decryptedStringWithKey:NSStringFromClass([self class])]] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:@{
        @"url_long": url.absoluteString
    } options:0 error:nil]];
    [request setHTTPMethod:@"POST"];
    
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *const config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:[NSString stringWithFormat:@"rhea-%@", [[NSUUID UUID] UUIDString]]];
        if (@available(macOS 11.0, *)) {
            config.sessionSendsLaunchEvents = NO;
        }
        session = [NSURLSession sessionWithConfiguration:config delegate:[self taskDelegate] delegateQueue:nil];
    });
    
    NSURLSessionTask *const task = [session dataTaskWithRequest:request];
    void (^taskCompletion)(NSData *, NSError*) = ^(NSData *data, NSError *error) {
        NSURL *result = nil;
        if (data.length > 0) {
            id resultObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([resultObject isKindOfClass:[NSDictionary class]] && [resultObject[@"url_short"] isKindOfClass:[NSString class]]) {
                result = [NSURL URLWithString:resultObject[@"url_short"]];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, YES);
        });
    };
    objc_setAssociatedObject(task, kCompletionKey, taskCompletion, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (@available(macOS 11.3, *)) {
        task.prefersIncrementalDelivery = NO;
    }
    [task resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)newData
{
    NSMutableData *const data = objc_getAssociatedObject(dataTask, kDataKey);
    if (data) {
        [data appendData:newData];
    } else {
        objc_setAssociatedObject(dataTask, kDataKey, [newData mutableCopy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    void (^completion)(NSData *, NSError *) = objc_getAssociatedObject(task, kCompletionKey);
    if (completion) {
        NSData *const data = objc_getAssociatedObject(task, kDataKey);
        completion(data, error);
    }
    
}

@end
