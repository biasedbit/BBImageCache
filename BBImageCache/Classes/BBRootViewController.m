//
//  BBRootViewController.m
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/24/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "BBRootViewController.h"

#import "BBAppDelegate.h"
#import "BBFilesystemImageCache.h"
#import "BBCoreDataImageCache.h"
#import "BBProfiler.h"



#pragma mark - Constants

NSUInteger const kBBRootViewControllerOperations = 100;



#pragma mark - 

@interface BBRootViewController ()


#pragma mark Private properties

@property(strong, nonatomic) UITextView* textView;


#pragma mark Private helpers

- (void)appendText:(NSString*)text;
- (void)runTests;
- (NSString*)humanReadableTime:(uint64_t)nanoseconds;
- (void)testCacheCorrectness:(id<BBImageCache>)cache;
- (NSString*)testCacheSpeed:(id<BBImageCache>)cache;
- (NSString*)testCacheSpeedWithImageBuilding:(id<BBImageCache>)cache;

@end



#pragma mark -

@implementation BBRootViewController


#pragma mark Property synthesizers

@synthesize textView = _textView;


#pragma mark UIViewController overrides

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Image cache speed test";

    UITextView* textView      = [[UITextView alloc] initWithFrame:self.view.bounds];
    textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    textView.font             = [UIFont systemFontOfSize:15];
    textView.editable         = NO;

    [self.view addSubview:textView];
    self.textView = textView;
}

- (void)viewDidAppear:(BOOL)animated
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^() {
        [self runTests];
    });
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark Private helpers

- (void)appendText:(NSString*)text
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        _textView.text = [NSString stringWithFormat:@"%@%@\n", _textView.text, text];

        NSRange lastChar = NSMakeRange([_textView.text length] - 1, 1);
        [_textView scrollRangeToVisible:lastChar];
    });

    BBLogInfo(@"%@", text);
}

- (void)runTests
{
    BBAppDelegate* appDelegate = [UIApplication sharedApplication].delegate;
    
    // A normal usage would be [BBFilesystemImageCache sharedCache], but for testing purposes we want a 2sec expiration
    BBFilesystemImageCache* fsCache = [[BBFilesystemImageCache alloc]
                                       initWithCacheName:@"testCache" andItemDuration:2];
    BBCoreDataImageCache* cdCache = [[BBCoreDataImageCache alloc]
                                     initWithContext:appDelegate.managedObjectContext andItemDuration:2];

    // Test how much time it takes to create X images from NSData
    UIImage* buddyJesus = [UIImage imageNamed:@"buddy_jesus.jpg"];
    NSData* imageData = UIImagePNGRepresentation(buddyJesus);
    uint64_t createNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            [UIImage imageWithData:imageData];
        }
    }];

    NSString* text = [NSString stringWithFormat:@"Time taken to create %u images from NSData: %@",
                      kBBRootViewControllerOperations, [self humanReadableTime:createNanoseconds]];
    [self appendText:text];

    [self appendText:@"Running correctness tests..."];
    [self testCacheCorrectness:cdCache];
    [self testCacheCorrectness:fsCache];

    [self appendText:@"Beginning cache speed test..."];
    sleep(1);

    // Disable tracing so we can focus on performance
#ifdef LOG_TRACE
    [self appendText:@"Comment out the definition of LOG_TRACE preprocessor macro on ImageCacheSpeedTest-Prefix.pch"];
#else
    [self appendText:@"Testing coredata cache...\n"];
    [self appendText:[self testCacheSpeed:cdCache]];
    [self appendText:[self testCacheSpeedWithImageBuilding:cdCache]];
    [self appendText:@"Finished testing coredata cache..."];

    sleep(1);

    [self appendText:@"Testing filesystem cache...\n"];
    [self appendText:[self testCacheSpeed:fsCache]];
    [self appendText:[self testCacheSpeedWithImageBuilding:fsCache]];
    [self appendText:@"Finished testing filesystem cache..."];

    [self appendText:@"Done!"];
#endif
}

- (NSString*)humanReadableTime:(uint64_t)nanoseconds
{
    if (nanoseconds < 10000) {
        return [NSString stringWithFormat:@"%lluns", nanoseconds];
//    } else if (nanoseconds < 10000000) {
    } else {
        return [NSString stringWithFormat:@"%.2fms", (nanoseconds / 1000000.0)];
//    } else {
//        return [NSString stringWithFormat:@"%.2fs", (nanoseconds / 1000000000.0)];
    }
}

- (void)testCacheCorrectness:(id<BBImageCache>)cache
{
    // Make sure we're on a clean slate...
    [cache clearCache];
    NSAssert([cache itemsInCache] == 0, @"should be 2");
    
    UIImage* buddyJesus = [UIImage imageNamed:@"buddy_jesus.jpg"];
    
    // Make sure nothing is there
    UIImage* retrieved = [cache imageForKey:@"buddyJesus"];
    NSAssert(retrieved == nil, @"should be nil");
    
    // Make sure we can store
    BOOL stored = [cache storeImage:buddyJesus forKey:@"buddyJesus"];
    NSAssert(stored, @"should be true");
    BOOL stored2 = [cache storeImage:buddyJesus forKey:@"buddyJesus2"];
    NSAssert(stored2, @"should be true");
    BOOL stored3 = [cache storeImage:buddyJesus forKey:@"buddyJesus"];
    NSAssert(stored3, @"should be true");
    NSAssert([cache itemsInCache] == 2, @"should be 2");
    
    // Make sure that there is something there after storing
    retrieved = [cache imageForKey:@"buddyJesus"];
    NSAssert(retrieved != nil, @"shouldn't be nil");
    NSAssert(retrieved.size.width == buddyJesus.size.width, @"width should be the same");
    NSAssert(retrieved.size.height == buddyJesus.size.height, @"height should be the same");
    
    retrieved = [cache imageForKey:@"buddyJesus2"];
    NSAssert(retrieved != nil, @"shouldn't be nil");
    NSAssert(retrieved.size.width == buddyJesus.size.width, @"width should be the same");
    NSAssert(retrieved.size.height == buddyJesus.size.height, @"height should be the same");
    
    // Make sure we can persist the index to disk
    BOOL synchronized = [cache synchronizeCache];
    NSAssert(synchronized, @"should have synchronized");
    
    // Sleep for 5 seconds
    sleep(3);
    
    // Ensure we can still fetch data and extend expiration
    retrieved = [cache imageForKey:@"buddyJesus2"];
    NSAssert(retrieved != nil, @"shouldn't be nil");
    NSAssert(retrieved.size.width == buddyJesus.size.width, @"width should be the same");
    NSAssert(retrieved.size.height == buddyJesus.size.height, @"height should be the same");
    
    // Since we only fetched one 
    NSUInteger purged = [cache purgeStaleData];
    NSAssert(purged == 1, @"should be one");
    
    // Clear the cache again
    [cache clearCache];
    [cache synchronizeCache];
    NSAssert([cache itemsInCache] == 0, @"should be 2");
}

- (NSString*)testCacheSpeed:(id<BBImageCache>)cache
{
    UIImage* buddyJesus = [UIImage imageNamed:@"buddy_jesus.jpg"];

    uint64_t storeNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            [cache storeImage:buddyJesus forKey:[NSString stringWithFormat:@"key %u", i]];
        }
    }];

    uint64_t synchronizeNanoseconds = [BBProfiler profileBlock:^() {
        [cache synchronizeCache];
    }];

    uint64_t loadNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            [cache imageForKey:[NSString stringWithFormat:@"key %u", i]];
        }
    }];

    uint64_t clearNanoseconds = [BBProfiler profileBlock:^() {
        [cache clearCache];
        [cache synchronizeCache];
    }];

    uint64_t storeAndSynchronizeNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            [cache storeImage:buddyJesus forKey:[NSString stringWithFormat:@"key %u", i]];
            [cache synchronizeCache];
        }
    }];

    return [NSString stringWithFormat:
            @"Execution times:\n"
            "Store:\t\t%@\n"
            "Sync:\t\t%@\n"
            "Load:\t\t%@\n"
            "Clear&Sync:\t%@\n"
            "Store&Sync:\t%@\n"
            "Item count:\t%u\n",
            [self humanReadableTime:storeNanoseconds],
            [self humanReadableTime:synchronizeNanoseconds],
            [self humanReadableTime:loadNanoseconds],
            [self humanReadableTime:clearNanoseconds],
            [self humanReadableTime:storeAndSynchronizeNanoseconds],
            [cache itemsInCache]];
}

- (NSString*)testCacheSpeedWithImageBuilding:(id<BBImageCache>)cache
{
    // This method ensures that a different image is created from block of data, thus avoiding any potential
    // transformation in CoreData's caches

    UIImage* buddyJesus = [UIImage imageNamed:@"buddy_jesus.jpg"];
    NSData* imageData = UIImagePNGRepresentation(buddyJesus);
    
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:kBBRootViewControllerOperations];
    for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
        UIImage* imageFromData = [UIImage imageWithData:imageData];
        [array addObject:imageFromData];
    }

    uint64_t storeNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            // Cost of retrieving image at index from an array is negligible
            UIImage* image = [array objectAtIndex:i];
            [cache storeImage:image forKey:[NSString stringWithFormat:@"key %u", i]];
        }
    }];

    uint64_t synchronizeNanoseconds = [BBProfiler profileBlock:^() {
        [cache synchronizeCache];
    }];

    uint64_t loadNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            [cache imageForKey:[NSString stringWithFormat:@"key %u", i]];
        }
    }];

    uint64_t clearNanoseconds = [BBProfiler profileBlock:^() {
        [cache clearCache];
        [cache synchronizeCache];
    }];

    uint64_t storeAndSynchronizeNanoseconds = [BBProfiler profileBlock:^() {
        for (NSUInteger i = 0; i < kBBRootViewControllerOperations; i++) {
            UIImage* image = [array objectAtIndex:i];
            [cache storeImage:image forKey:[NSString stringWithFormat:@"key %u", i]];
            [cache synchronizeCache];
        }
    }];

    return [NSString stringWithFormat:
            @"Execution times (w/ image building):\n"
            "Store:\t\t%@\n"
            "Sync:\t\t%@\n"
            "Load:\t\t%@\n"
            "Clear&Sync:\t%@\n"
            "Store&Sync:\t%@\n"
            "Item count:\t%u\n",
            [self humanReadableTime:storeNanoseconds],
            [self humanReadableTime:synchronizeNanoseconds],
            [self humanReadableTime:loadNanoseconds],
            [self humanReadableTime:clearNanoseconds],
            [self humanReadableTime:storeAndSynchronizeNanoseconds],
            [cache itemsInCache]];
}

@end
