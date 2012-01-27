//
//  BBCoreDataImageCache.m
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBCoreDataImageCache.h"

#import "BBAppDelegate.h"
#import "BBCacheEntry.h"



#pragma mark - Constants

NSTimeInterval const kBBCoreDataImageCacheDefaultDuration = 86400; // 1 day



#pragma mark -

@interface BBCoreDataImageCache ()


#pragma mark Private properties

@property(strong, nonatomic) NSManagedObjectContext* context;
@property(assign, nonatomic) NSTimeInterval          duration;


#pragma mark Private helpers

- (NSFetchRequest*)fetchRequestForThumbnail;

@end



#pragma mark -

@implementation BBCoreDataImageCache


#pragma mark Property synthesizers

@synthesize context  = _context;
@synthesize duration = _duration;


#pragma mark Creation

- (id)initWithContext:(NSManagedObjectContext*)context andItemDuration:(NSTimeInterval)duration
{
    self = [super init];
    if (self != nil) {
        self.context  = context;
        self.duration = duration;

        // If there were stale cache items purged, then flush the cache index to disk
        if ([self purgeStaleData] > 0) {
            [self synchronizeCache];
        }
    }

    return self;
}


#pragma mark Public static methods

+ (BBCoreDataImageCache*)sharedCache
{
    static BBCoreDataImageCache* instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BBAppDelegate* delegate = [[UIApplication sharedApplication] delegate];
        instance = [[BBCoreDataImageCache alloc]
                    initWithContext:delegate.managedObjectContext
                    andItemDuration:kBBCoreDataImageCacheDefaultDuration];
    });

    return instance;
}


#pragma mark BBImageCache

- (NSUInteger)itemsInCache
{
    NSFetchRequest* fetchRequest = [self fetchRequestForThumbnail];
    [fetchRequest setIncludesPropertyValues:NO]; // only fetch the managedObjectID

    NSError* error   = nil;
    NSUInteger count = [_context countForFetchRequest:fetchRequest error:&error];
    if (error != nil) {
        BBLogError(@"[CDC] Failed to count cache entries: %@", [error description]);
        return 0;
    }

    return count;
}

- (void)clearCache
{
    // Fetch all (without property values, just managed object id) and delete them
    NSFetchRequest* fetchRequest = [self fetchRequestForThumbnail];
    [fetchRequest setIncludesPropertyValues:NO]; // only fetch the managedObjectID

    NSError* error      = nil;
    NSArray* thumbnails = [_context executeFetchRequest:fetchRequest error:&error];

    if (error != nil) {
        BBLogError(@"[CDC] Failed to clear cache: %@", [error description]);
        return;
    }

    for (NSManagedObject* thumbnail in thumbnails) {
        [_context deleteObject:thumbnail];
    }

    if ([thumbnails count] > 0) {        
        NSError* saveError = nil;
        [_context save:&saveError];
        if (saveError != nil) {
            BBLogError(@"[CDC] Failed to save context after deleting all records: %@", [saveError description]);
        }
        
        BBLogTrace(@"[CDC] Deleted %u items from cache.", [thumbnails count]);
    } else {
        BBLogTrace(@"[CDC] No items in cache.");
    }
}

- (BOOL)synchronizeCache
{
    if ([_context hasChanges]) {
        NSError* saveError = nil;
        [_context save:&saveError];
        if (saveError != nil) {
            BBLogError(@"[CDC] Failed to save cache: %@", [saveError description]);
            return NO;
        }
    }

    return YES;
}

- (NSUInteger)purgeStaleData
{
    NSDate* now = [NSDate date];

    NSFetchRequest* fetchRequest = [self fetchRequestForThumbnail];
    [fetchRequest setIncludesPropertyValues:NO]; // only fetch the managedObjectID

    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"expiration < %@", now];
    [fetchRequest setPredicate:predicate];

    NSError* error             = nil;
    NSArray* expiredCacheItems = [_context executeFetchRequest:fetchRequest error:&error];
    if (error != nil) {
        BBLogError(@"[CDC] Failed to fetch stale items: %@", [error description]);
        return 0;
    }

    if ([expiredCacheItems count] > 0) {        
        for (NSManagedObject* staleItem in expiredCacheItems) {
            [_context deleteObject:staleItem];
        }

        NSError* saveError = nil;
        [_context save:&saveError];
        if (saveError != nil) {
            BBLogError(@"[CDC] Failed to save data after purging expired cache items: %@", [saveError description]);
            return 0;
        }

        return [expiredCacheItems count];
    }

    return 0;
}

- (BOOL)storeImage:(UIImage*)image forKey:(NSString*)key
{
    NSFetchRequest* fetchRequest = [self fetchRequestForThumbnail];
    NSPredicate* predicate       = [NSPredicate predicateWithFormat:@"key like %@", key];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setFetchLimit:1];

    NSError* error        = nil;
	NSArray* fetchResults = [_context executeFetchRequest:fetchRequest error:&error];
    if (error != nil) {
        BBLogError(@"[CDC] Failed to store thumbnail for key '%@': %@", key, [error description]);
        return NO;
    } else if ([fetchResults count] == 0) {
        // No record, insert
        BBCacheEntry* thumbnail = [NSEntityDescription insertNewObjectForEntityForName:@"BBCacheEntry"
                                                               inManagedObjectContext:_context];
        thumbnail.key        = key;
        thumbnail.image      = image;
        thumbnail.expiration = [NSDate dateWithTimeIntervalSinceNow:_duration];
        BBLogTrace(@"[CDC] Stored and added expiration date for key '%@'.", key);
        return YES;
    } else {
        BBCacheEntry* thumbnail = [fetchResults objectAtIndex:0];
        thumbnail.image         = image;
        thumbnail.expiration    = [NSDate dateWithTimeIntervalSinceNow:_duration];
        BBLogTrace(@"[CDC] Updated and extended expiration for key '%@'.", key);
        return YES;
    }
}

- (UIImage*)imageForKey:(NSString*)key
{
    NSFetchRequest* fetchRequest = [self fetchRequestForThumbnail];
    NSPredicate* predicate       = [NSPredicate predicateWithFormat:@"key like %@", key];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setFetchLimit:1];

    NSError* error        = nil;
	NSArray* fetchResults = [_context executeFetchRequest:fetchRequest error:&error];
    if (error != nil) {
        BBLogError(@"[CDC] Failed to load thumbnail for key '%@': %@", key, [error description]);
        return nil;
    } else if ([fetchResults count] == 0) {
        BBLogTrace(@"[CDC] No image for cache key '%@'.", key);
        return nil;
    } else {
        BBCacheEntry* thumbnail = [fetchResults objectAtIndex:0];
        thumbnail.expiration    = [NSDate dateWithTimeIntervalSinceNow:_duration];
        BBLogTrace(@"[CDC] Retrieved and extended expiration for key '%@'.", key);

        return thumbnail.image;
    }
}


#pragma mark Private helpers

- (NSFetchRequest*)fetchRequestForThumbnail
{
    NSFetchRequest* request     = [[NSFetchRequest alloc] init];
	NSEntityDescription* entity = [NSEntityDescription entityForName:@"BBCacheEntry" inManagedObjectContext:_context];
    [request setEntity:entity];

    return request;
}

@end
