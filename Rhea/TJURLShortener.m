//
//  TJURLShortener.m
//  Rhea
//
//  Created by Tim Johnsen on 4/8/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "TJURLShortener.h"
#import "NSString+Encryption.h"
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

static NSString *const kSlugLengthKey = @"_tjus.l";

__attribute__((objc_direct_members))
@interface TJURLShortener () <NSURLSessionDataDelegate>

@end

__attribute__((objc_direct_members))
@implementation TJURLShortener

NSString *_tjus_key;
NSString *_tjus_host;
NSUserDefaults *_tjus_userDefaults;

+ (void)configureWithKey:(NSString *const)key
                    host:(NSString *const)host
            userDefaults:(NSUserDefaults *const)userDefaults
{
    _tjus_key = key;
    _tjus_host = host;
    _tjus_userDefaults = userDefaults;
}

+ (instancetype)taskDelegate
{
    static TJURLShortener *taskDelegate = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taskDelegate = [self new];
    });
    return taskDelegate;
}

+ (NSURL *)expectedShortURLFor:(NSURL *const)url
{
    if (_tjus_key == nil) {
        return nil;
    }
    NSURLComponents *components = [[NSURLComponents alloc] initWithString:@"https://tijo.link"];
    
    unsigned char result[CC_SHA224_DIGEST_LENGTH];
    NSString *const input = [url.absoluteString stringByAppendingString:_tjus_key];
    NSData *const data = [input dataUsingEncoding:NSUTF8StringEncoding];
    CC_SHA224(data.bytes, (CC_LONG)data.length, result);
    NSString *suffix = [[NSData dataWithBytes:result length:CC_SHA224_DIGEST_LENGTH] base64EncodedStringWithOptions:0];
    suffix = [suffix stringByReplacingOccurrencesOfString:@"/|\\+|=" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, suffix.length)];
    const NSUInteger length = MIN(MAX([[_tjus_userDefaults objectForKey:kSlugLengthKey] unsignedIntegerValue] ?: 4, 4), 12);
    suffix = [suffix substringToIndex:MIN(length, suffix.length)];
    
    components.path = [@"/" stringByAppendingString:suffix];
    
    return components.URL;
}

static char *const kCompletionKey = "_tjus.c";
static char *const kDataKey = "_tjus.d";

+ (void)shortenURL:(NSURL *const)url
        completion:(void (^)(NSURL *_Nullable shortenedURL, BOOL shortened))completion
{
    if (_tjus_host == nil) {
        completion(nil, YES);
    }
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSURL *const expectedURL = [self expectedShortURLFor:url];
        completion(expectedURL, NO);
    });
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:_tjus_host]];
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
            if ([resultObject isKindOfClass:[NSDictionary class]]) {
                const id resultURL = resultObject[@"url_short"];
                if ([resultURL isKindOfClass:[NSString class]]) {
                    result = [NSURL URLWithString:resultURL];
                }
                const id resultSlugLength = resultObject[@"l"];
                if ([resultSlugLength isKindOfClass:[NSNumber class]]) {
                    [_tjus_userDefaults setObject:resultSlugLength forKey:kSlugLengthKey];
                }
            }
        }
        completion(result, YES);
    };
    objc_setAssociatedObject(task, kCompletionKey, taskCompletion, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (@available(iOS 14.5, macOS 11.3, *)) {
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
