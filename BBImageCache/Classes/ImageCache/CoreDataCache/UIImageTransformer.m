//
//  UIImageTransformer.m
//  ImageCacheSpeedTest
//
//  Created by Bruno de Carvalho on 1/20/12.
//  Copyright (c) 2012 BiasedBit. All rights reserved.
//

#import "UIImageTransformer.h"



#pragma mark -

@implementation UIImageTransformer


#pragma mark NSValueTransformer

+ (Class)transformedValueClass
{
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation
{
    return YES;
}

- (id)transformedValue:(id)value
{
    return (value == nil) ? nil : UIImagePNGRepresentation(value);
}

- (id)reverseTransformedValue:(id)value
{
    return (value == nil) ? nil : [UIImage imageWithData:value];
}

@end
