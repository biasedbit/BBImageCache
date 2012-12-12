//
//  MTGCDFileIOCache.h
//  BBImageCache
//
//  Created by Sung-Taek Kim on 12/10/12.
//
//

#import <Foundation/Foundation.h>
#import "BBImageCache.h"

@interface MTGCDFileIOCache : NSObject <BBImageCache>
- (id)initWithCacheName:(NSString*)cacheName andItemDuration:(NSTimeInterval)duration;

#pragma mark Public static methods
+ (MTGCDFileIOCache*)sharedCache;

#pragma mark Public methods
- (BOOL)storePngImageData:(NSData*)imageData forKey:(NSString*)key;

@end
