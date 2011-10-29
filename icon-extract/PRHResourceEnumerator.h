//
//  PRHResourceEnumerator.h
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

//Yields resources of a given type from the current resource file (like Get1IndResource).

@class PRHResource;

@interface PRHResourceEnumerator : NSEnumerator

- (id) initWithResourceType:(ResType)type;
+ (id) newWithResourceType:(ResType)type;

//nextObject yields PRHResource objects.

@end

@interface PRHResource : NSObject

@property(readonly) ResType type;
@property(readonly) ResID ID;
@property(readonly, strong) NSString *name;

@property(readonly) Handle resourceHandle;
@property(nonatomic, readonly) NSData *data;

@end
