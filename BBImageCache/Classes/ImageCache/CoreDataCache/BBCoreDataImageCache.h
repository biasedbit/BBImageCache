//
//  BBCoreDataImageCache.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBImageCache.h"



#pragma mark -

@interface BBCoreDataImageCache : NSObject <BBImageCache>


#pragma mark Creation

- (id)initWithContext:(NSManagedObjectContext*)context andTimeoutInterval:(NSTimeInterval)timeout;


#pragma mark Public static methods

+ (BBCoreDataImageCache*)sharedCache;

@end
