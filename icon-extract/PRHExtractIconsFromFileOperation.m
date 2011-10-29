//
//  PRHExtractIconFromFileOperation.m
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

#import "PRHExtractIconsFromFileOperation.h"

#import "PRHResourceEnumerator.h"
#import "BundleResourceSupport.h"

@implementation PRHExtractIconsFromFileOperation
{
	FSRef sourceRef;
	NSMutableData *iconFamilyElementsData; //The “elements” member of the IconFamilyResource structure.
	NSString *destinationFilenameFormat;
}

@synthesize sourceURL;
@synthesize destinationDirectoryURL;

- (NSData *) dataForResourceWithType:(ResType)type ID:(ResID)ID {
	NSData *data = nil;
	
	Handle resH = Get1Resource(type, ID);
	if (resH) {
		LoadResource(resH);
		
		HLock(resH);
		data = [NSData dataWithBytes:*resH length:GetHandleSize(resH)];
		HUnlock(resH);
	}
	
	return data;
}
- (OSStatus) extractExistingIconFamilyWithID:(ResID)ID {
	NSData *icnsData = [self dataForResourceWithType:kIconFamilyType ID:ID];
	iconFamilyElementsData = [icnsData mutableCopy];
	return ResError();
}
- (OSStatus) extractIconOfType:(ResType)type ID:(ResID)ID {
	NSData *data = [self dataForResourceWithType:type ID:ID];
	OSStatus err = data ? noErr : ResError();
	if (data) {
		[iconFamilyElementsData	appendBytes:&type length:sizeof(ResType)];
		SInt32 size = (SInt32)OSSwapHostToBigInt32([data length]);
		[iconFamilyElementsData	appendBytes:&size length:sizeof(size)];
		[iconFamilyElementsData	appendData:data];
	}
	return err;
}
- (OSStatus) extractAllIconsWithID:(ResID)ID {
	OSStatus err = noErr;

	err = [self extractExistingIconFamilyWithID:ID];

	if (err == noErr)
		err = [self extractIconOfType:kThumbnail32BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kThumbnail8BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kHuge32BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kHuge8BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kHuge8BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kHuge4BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kHuge1BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kLarge32BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kLarge8BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kLarge8BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kLarge4BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kLarge1BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kSmall32BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kSmall8BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kSmall8BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kSmall4BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kSmall1BitMask ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kMini8BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kMini4BitData ID:ID];
	if (err == noErr)
		err = [self extractIconOfType:kMini1BitMask ID:ID];

	return err;
}
- (OSStatus) extractIconsFromForkName:(struct HFSUniStr255 *)forkName {
	ResFileRefNum refnum;
	OSStatus err;
	err = FSOpenResourceFile(&sourceRef, forkName->length, forkName->unicode, fsRdPerm, &refnum);
	if (err != noErr) {
		if (err != eofErr)
			NSLog(@"FSOpenResourceFile returned %li/%s", (long)err, GetMacOSStatusCommentString(err));
		return err;
	}

	NSMutableSet *processedIconResourceIDs = [NSMutableSet new];

	PRHResourceEnumerator *bundlesEnum = [PRHResourceEnumerator newWithResourceType:'BNDL'];
	for (PRHResource *bundleResource in bundlesEnum) {
		const struct BundleResource *bundlePtr = [bundleResource.data bytes];
		const struct ResourceIDPair *mappings = bundlePtr->iconMappingList.mappings;
		for (UInt16 i = 0; i < bundlePtr->iconMappingList.mappingCount; ++i) {
			const ResID iconResourceID = mappings[i].resourceID;

			iconFamilyElementsData = [NSMutableData new];
			[self extractAllIconsWithID:iconResourceID];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResourceID]];

			NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType('BNDL'), iconResourceID];
			NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
			NSError *error = nil;
			[iconFamilyElementsData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
			NSLog(@"Wrote icons found by %@ to %@: error is %@", bundleResource, destinationURL, error);
		}
	}

	PRHResourceEnumerator *modernIconsEnum = [PRHResourceEnumerator newWithResourceType:kIconFamilyType];
	PRHResource *iconResource;
	for (iconResource in modernIconsEnum) {
		if (![processedIconResourceIDs containsObject:[NSNumber numberWithShort:iconResource.ID]])
		{
			iconFamilyElementsData = [NSMutableData new];
			[self extractAllIconsWithID:iconResource.ID];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResource.ID]];

			NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType(kIconFamilyType), iconResource.ID];
			NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
			NSError *error = nil;
			[iconFamilyElementsData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
			NSLog(@"Wrote icons found by %@ to %@: error is %@", iconResource, destinationURL, error);
		}
	}

	PRHResourceEnumerator *eightBitIconsEnum = [PRHResourceEnumerator newWithResourceType:kLarge8BitData];
	for (iconResource in eightBitIconsEnum) {
		if (![processedIconResourceIDs containsObject:[NSNumber numberWithShort:iconResource.ID]])
		{
			iconFamilyElementsData = [NSMutableData new];
			[self extractAllIconsWithID:iconResource.ID];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResource.ID]];

			NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType(kLarge8BitData), iconResource.ID];
			NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
			NSError *error = nil;
			[iconFamilyElementsData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
			NSLog(@"Wrote icons found by %@ to %@: error is %@", iconResource, destinationURL, error);
		}
	}

	CloseResFile(refnum);
	err = ResError();
	return err;
}
- (void) main {
	NSLog(@"%s starting", __func__);
	bool success = CFURLGetFSRef((__bridge CFURLRef)self.sourceURL, &sourceRef);
	if (!success) return;

	NSString *sourceFilename = [self.sourceURL lastPathComponent];
	NSString *sourceBaseFilename = [sourceFilename stringByDeletingPathExtension];
	destinationFilenameFormat = [sourceBaseFilename stringByAppendingString:@"-%@-%hd.icns"];

	OSStatus err;
	struct HFSUniStr255 forkName;

	err = FSGetResourceForkName(&forkName);
	[self extractIconsFromForkName:&forkName];
	err = FSGetDataForkName(&forkName);
	[self extractIconsFromForkName:&forkName];

	destinationFilenameFormat = nil;
	NSLog(@"%s finished", __func__);
}

@end
