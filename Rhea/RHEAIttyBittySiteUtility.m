//
//  RHEAIttyBittySiteUtility.m
//  Rhea
//
//  Created by Tim Johnsen on 7/5/18.
//  Copyright © 2018 tijo. All rights reserved.
//

#import "RHEAIttyBittySiteUtility.h"
#import "compression.h"

@implementation RHEAIttyBittySiteUtility

+ (NSString *)encodeFragmentForString:(NSString *)string
{
    // Useful references:
    // https://developer.apple.com/documentation/compression/1480986-compression_encode_buffer?language=objc
    // https://gist.github.com/daltheman/4716ec10d6d0f71aba56
    // https://nacho4d-nacho4d.blogspot.com/2017/04/compressing-and-decompressing-nsdata.html
    NSData *const sourceData = [string dataUsingEncoding:NSUTF8StringEncoding];
    const size_t sourceDataLength = sourceData.length;
    const size_t destinationBufferLength = sourceDataLength * 100;
    uint8_t *destinationBytes = (uint8_t *)malloc(sizeof(uint8_t) * destinationBufferLength);
    
    // IMPORTANT NOTE:
    // THIS DOESN'T WORK BECAUSE ITTY BITTY USES LEVEL 9 AND APPLE'S COMPRESSION_LZMA SUPPORTS LEVEL 6.
    // https://developer.apple.com/documentation/compression/data_compression?language=objc (compression is LZMA level 6)
    // Itty Bitty uses level 9 per the examples here https://github.com/alcor/itty-bitty/
    
    const size_t size = compression_encode_buffer(destinationBytes, destinationBufferLength, sourceData.bytes, sourceDataLength, nil, COMPRESSION_LZMA);
    NSData *const destinationData = [[NSData alloc] initWithBytesNoCopy:destinationBytes length:size freeWhenDone:NO];
    NSString *const destinationString = [destinationData base64EncodedStringWithOptions:0];
    free(destinationBytes);
    return destinationString;
}

+ (NSURL *)generateIttyBittySiteURLWithTitle:(nullable NSString *const)title
                                        body:(NSString *const)body
{
    NSString *const encodedBodyString = [self encodeFragmentForString:body];
    NSURL *url = nil;
    if (encodedBodyString.length > 0) {
        NSURLComponents *const components = [[NSURLComponents alloc] initWithString:@"https://itty.bitty.site/"];
        NSString *const safeTitle = title ?: @"";
        NSString *const fragment = [NSString stringWithFormat:@"%@/%@", safeTitle, encodedBodyString];
        components.fragment = fragment;
        url = components.URL;
    }
    return url;
}

@end
