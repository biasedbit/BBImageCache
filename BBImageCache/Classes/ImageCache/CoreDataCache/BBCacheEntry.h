//
//  BBThumbnail.h
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#pragma mark -

@interface BBCacheEntry : NSManagedObject


#pragma mark Public properties

@property(nonatomic, retain) NSString* key;
@property(nonatomic, retain) UIImage*  image;
@property(nonatomic, retain) NSDate*   expiration;

@end
