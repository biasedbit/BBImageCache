//
//  BBImageCache.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/23/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

@protocol BBImageCache <NSObject>


#pragma mark Protocol mandatory methods

- (NSUInteger)itemsInCache;
- (void)clearCache;
- (BOOL)synchronizeCache;
- (NSUInteger)purgeStaleData;
- (BOOL)storeImage:(UIImage*)image forKey:(NSString*)key;
- (UIImage*)imageForKey:(NSString*)key;
- (BOOL)performBlockAndSynchronize:(void (^)())block;

@end
