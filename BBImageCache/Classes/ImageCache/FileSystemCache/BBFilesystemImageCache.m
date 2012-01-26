//
//  BBFilesystemImageCache.m
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBFilesystemImageCache.h"



#pragma mark - Constants

NSString*      const kBBFilesystemImageCacheDefaultCacheName = @"ImageCache";
NSTimeInterval const kBBFilesystemImageCacheDefaultTimeout   = 86400;



#pragma mark -

@interface BBFilesystemImageCache ()


#pragma mark Private properties

@property(copy,   nonatomic) NSString*            cacheName;
@property(assign, nonatomic) NSTimeInterval       timeout;
@property(assign, nonatomic) dispatch_queue_t     queue;
@property(copy,   nonatomic) NSString*            cacheIndexFilename;
@property(copy,   nonatomic) NSString*            cacheDirectory;
@property(strong, nonatomic) NSMutableDictionary* cacheEntries;


#pragma mark Private methods

- (BOOL)createCacheDirectory;
- (void)loadCacheEntries;
- (NSString*)cachePathForKey:(NSString*)key;
- (void)writeData:(NSData*)data toPath:(NSString*)path;
- (void)deleteFileForKey:(NSString*)key;
- (void)deleteFileAtPath:(NSString*)path;

@end



#pragma mark -

@implementation BBFilesystemImageCache


#pragma mark Property synthesizers

@synthesize cacheName          = _cacheName;
@synthesize timeout            = _timeout;
@synthesize queue              = _queue;
@synthesize cacheIndexFilename = _cacheIndexFilename;
@synthesize cacheDirectory     = _cacheDirectory;
@synthesize cacheEntries       = _cacheEntries;


#pragma mark Creation

- (id)initWithCacheName:(NSString*)cacheName andTimeoutInterval:(NSTimeInterval)timeout
{
    self = [super init];
    if (self != nil) {
        self.cacheName          = cacheName;
        self.cacheIndexFilename = [NSString stringWithFormat:@"BBFilesystemImageCache-%@.plist", cacheName];
        self.timeout            = timeout;

        // Create a queue where cache hits will be ran on to ensures thread safety
        NSString* queueName = [NSString stringWithFormat:@"com.biasedbit.BBFilesystemImageCache-%@", cacheName];
        self.queue          = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_SERIAL);

        // Define the cache directory path
		NSString* cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                                     objectAtIndex:0];
		self.cacheDirectory = [cachesDirectory stringByAppendingPathComponent:_cacheName];
        BBLogTrace(@"[FSC] Cache directory is %@", _cacheDirectory);

        // Make sure the cache directory exists
        [self createCacheDirectory];
        // Load the cache index from disk
        [self loadCacheEntries];

        // If there were stale cache items purged, then flush the cache index to disk
        if ([self purgeStaleData] > 0) {
            [self synchronizeCache];
        }
    }

    return self;
}


#pragma mark Destruction

- (void)dealloc
{
    dispatch_release(_queue);
}


#pragma mark Public static methods

+ (BBFilesystemImageCache*)sharedCache
{
    static BBFilesystemImageCache* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BBFilesystemImageCache alloc]
                    initWithCacheName:kBBFilesystemImageCacheDefaultCacheName
                    andTimeoutInterval:kBBFilesystemImageCacheDefaultTimeout];
    });
    
    return instance;
}


#pragma mark BBImageCache

- (NSUInteger)itemsInCache
{
    return [_cacheEntries count];
}

- (void)clearCache
{
    __block NSDictionary* entries;

    dispatch_sync(_queue, ^() {
        // Clear the current cache, but keep a reference to the old dictionary to delete the files in background, with
        // low priority
        entries = _cacheEntries;
        self.cacheEntries = [NSMutableDictionary dictionary];
    });

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^() {
        // Delete all the files
        for (NSString* key in _cacheEntries) {
            NSString* cachePathForKey = [self cachePathForKey:key];
            [self deleteFileAtPath:cachePathForKey];
        }
    });
}

- (BOOL)synchronizeCache
{
    NSString* cacheIndexPath = [self cachePathForKey:_cacheIndexFilename];
    __block BOOL wrote;

    dispatch_sync(_queue, ^() {
        wrote = [_cacheEntries writeToFile:cacheIndexPath atomically:YES];
    });

    return wrote;
}

- (NSUInteger)purgeStaleData
{
    __block NSUInteger itemsPurged = 0;
    NSDate* now = [NSDate date];

    BBLogTrace(@"[FSC] Purging all stale items (%u entries)...", [_cacheEntries count]);

    dispatch_sync(_queue, ^() {
        [_cacheEntries enumerateKeysAndObjectsUsingBlock:^(NSString* key, NSDate* date, BOOL* stop) {
            // If date is < to staleThreshold, then purge this item
            if ([[now earlierDate:date] isEqualToDate:date]) {
                itemsPurged++;
                BBLogTrace(@"- purged file for key '%@'", key);

                // Asynchronously delete file with low priority
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^() {
                    [self deleteFileForKey:key];
                });
            }
        }];
    });

    return itemsPurged;
}

- (BOOL)storeImage:(UIImage*)image forKey:(NSString*)key
{
    NSData* imageData = UIImagePNGRepresentation(image);
    return [self storePngImageData:imageData forKey:key];
}

- (UIImage*)imageForKey:(NSString*)key
{
    NSString* cachePathForKey = [self cachePathForKey:key];
    __block UIImage* image = nil;

    dispatch_sync(_queue, ^() {
        image = [UIImage imageWithContentsOfFile:cachePathForKey];

        // If we have no image, then bail out immediately
        if (image == nil) {
            BBLogTrace(@"[FSC] No image for cache key '%@'.", key);
            return;
        }

        NSDate* newExpirationDate = [NSDate dateWithTimeIntervalSinceNow:_timeout];
        [_cacheEntries setObject:newExpirationDate forKey:key];
        BBLogTrace(@"[FSC] Retrieved and extended expiration for key '%@'.", key);
    });

    return image;
}

- (BOOL)performBlockAndSynchronize:(void (^)())block
{
    NSString* cacheIndexPath = [self cachePathForKey:_cacheIndexFilename];
    __block BOOL wrote;

    dispatch_sync(_queue, ^() {
        block();
        wrote = [_cacheEntries writeToFile:cacheIndexPath atomically:YES];
    });

    return wrote;
}


#pragma mark Public methods

- (BOOL)storePngImageData:(NSData*)imageData forKey:(NSString*)key
{
    NSString* cachePathForKey = [self cachePathForKey:key];
    BOOL wrote                = [imageData writeToFile:cachePathForKey atomically:YES];

    if (!wrote) {
        BBLogTrace(@"[FSC] Failed to create file for cache key '%@ at %@.", key, cachePathForKey);
        return NO;
    }

    NSDate* expirationDate = [NSDate dateWithTimeIntervalSinceNow:_timeout];
    dispatch_sync(_queue, ^() {
        [_cacheEntries setObject:expirationDate forKey:key];
        BBLogTrace(@"[FSC] Stored and added expiration date for key '%@'.", key);
    });

    return YES;
}


#pragma mark Private properties

- (BOOL)createCacheDirectory
{
    [[NSFileManager defaultManager]
     createDirectoryAtPath:_cacheDirectory withIntermediateDirectories:YES attributes:nil error:NULL];

    return YES;
}

- (void)loadCacheEntries
{
    dispatch_sync(_queue, ^() {
        NSString* cachePathForEntries = [self cachePathForKey:_cacheIndexFilename];

        self.cacheEntries = [NSMutableDictionary dictionaryWithContentsOfFile:cachePathForEntries];
        if (_cacheEntries == nil) {
            BBLogTrace(@"[FSC] Could not read cache index; creating an empty one.");
            self.cacheEntries = [[NSMutableDictionary alloc] init];
        } else {
            BBLogTrace(@"[FSC] Read %u cache entries from %@.", [_cacheEntries count], cachePathForEntries);
        }
    });
}

- (NSString*)cachePathForKey:(NSString*)key
{
    return [_cacheDirectory stringByAppendingPathComponent:key];
}

- (void)writeData:(NSData*)data toPath:(NSString*)path
{
    [data writeToFile:path atomically:YES];
}

- (void)deleteFileForKey:(NSString*)key
{
    NSString* cachePathForKey = [self cachePathForKey:key];
    [self deleteFileAtPath:cachePathForKey];
}

- (void)deleteFileAtPath:(NSString*)path
{
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
}

@end
