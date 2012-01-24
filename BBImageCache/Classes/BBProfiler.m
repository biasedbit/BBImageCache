//
//  BBProfiler.m
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/24/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBProfiler.h"

#import <mach/mach_time.h>



#pragma mark -

@implementation BBProfiler


#pragma mark Public static methods

+ (uint64_t)profileBlock:(void (^)())block
{
    uint64_t startTime       = 0;
    uint64_t endTime         = 0;
    uint64_t elapsedTime     = 0;
    uint64_t elapsedTimeNano = 0;

    mach_timebase_info_data_t timeBaseInfo;
    mach_timebase_info(&timeBaseInfo);

    startTime = mach_absolute_time();

    block();

    endTime         = mach_absolute_time();
    elapsedTime     = endTime - startTime;
    elapsedTimeNano = elapsedTime * timeBaseInfo.numer / timeBaseInfo.denom;

    return elapsedTimeNano;
}

@end
