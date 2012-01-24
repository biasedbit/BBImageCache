//
//  BBProfiler.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/24/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#pragma mark -

@interface BBProfiler : NSObject


#pragma mark Public static methods

+ (uint64_t)profileBlock:(void (^)())block;

@end
