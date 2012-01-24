//
//  BBFilesystemImageCache.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBImageCache.h"



#pragma mark -

@interface BBFilesystemImageCache : NSObject <BBImageCache>


#pragma mark Creation

- (id)initWithCacheName:(NSString*)cacheName andTimeoutInterval:(NSTimeInterval)timeout;


#pragma mark Public static methods

+ (BBFilesystemImageCache*)sharedCache;


#pragma mark Public methods

- (BOOL)storePngImageData:(NSData*)imageData forKey:(NSString*)key;

@end
