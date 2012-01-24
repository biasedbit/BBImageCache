//
//  BBAppDelegate.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#pragma mark -

@interface BBAppDelegate : UIResponder <UIApplicationDelegate>


#pragma mark Public properties

@property(strong, nonatomic)           UIWindow*                     window;
@property(strong, nonatomic, readonly) NSManagedObjectContext*       managedObjectContext;
@property(strong, nonatomic, readonly) NSManagedObjectModel*         managedObjectModel;
@property(strong, nonatomic, readonly) NSPersistentStoreCoordinator* persistentStoreCoordinator;


#pragma mark Public properties

- (void)saveContext;
- (NSURL*)applicationDocumentsDirectory;

@end
