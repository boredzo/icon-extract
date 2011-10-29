//
//  PRHResourceEnumerator.m
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

#import "PRHResourceEnumerator.h"

@interface PRHResource ()

+ (id) newWithType:(ResType)newType ID:(ResID)newID;
- (id) initWithType:(ResType)newType ID:(ResID)newID;

@end

@implementation PRHResourceEnumerator
{
	ResType type;
	ResourceCount numResources;
	ResourceIndex nextIndex;
}

- (id) initWithResourceType:(ResType)newType {
	if ((self = [super init])) {
		type = newType;
		numResources = Count1Resources(type);
		nextIndex = 1;
	}
	return self;
}
+ (id) newWithResourceType:(ResType)newType {
	return [[self alloc] initWithResourceType:newType];
}

- (id) nextObject {
	PRHResource *resource = nil;

	Handle resH = Get1IndResource(type, nextIndex++);
	if (resH) {
		ResType thisType;
		ResID thisID;
		Str255 name_unused;
		GetResInfo(resH, &thisID, &thisType, name_unused);
		resource = [PRHResource newWithType:thisType ID:thisID];
	}

	return resource;
}

@end

@implementation PRHResource

@synthesize type;
@synthesize ID;
@synthesize name;

@synthesize resourceHandle;

+ (id) newWithType:(ResType)newType ID:(ResID)newID {
	return [[self alloc] initWithType:newType ID:newID];
}
- (id) initWithType:(ResType)newType ID:(ResID)newID {
	if ((self = [super init])) {
		type = newType;
		ID = newID;

		resourceHandle = Get1Resource(type, ID);

		ResType thisType_unused;
		ResID thisID_unused;
		Str255 name255;
		GetResInfo(resourceHandle, &thisID_unused, &thisType_unused, name255);
		name = (__bridge_transfer NSString *)CFStringCreateWithPascalString(kCFAllocatorDefault, name255, kCFStringEncodingMacRoman);
	}
	return self;
}

- (NSData *) data {
	NSData *data = nil;

	Handle resH = self.resourceHandle;
	if (resH) {
		LoadResource(resH);

		HLock(resH);
		data = [NSData dataWithBytes:*resH length:GetHandleSize(resH)];
		HUnlock(resH);
	}

	return data;
}

- (NSString *) description {
	return [NSString stringWithFormat:@"<%@ %p '%@' %hd>", [self class], self,
		(__bridge_transfer NSString *)UTCreateStringForOSType(self.type),
		self.ID
	];
}

@end
