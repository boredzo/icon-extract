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

		ReleaseResource(resH);
	}

	return data;
}
- (OSStatus) extractExistingIconFamilyWithID:(ResID)ID {
	NSData *icnsData = [self dataForResourceWithType:kIconFamilyType ID:ID];
	OSStatus err = ResError();

	if (icnsData)
		[iconFamilyElementsData appendData:icnsData];
	else if (err == noErr) {
		//Get1Resource returns noErr even if it doesn't find the resource. (This is documented in the Resource Manager reference.)
		err = resNotFound;
	}

	return err;
}
- (OSStatus) extractIconOfType:(ResType)type ID:(ResID)ID {
	NSData *data = [self dataForResourceWithType:type ID:ID];
	OSStatus err = data ? noErr : ResError();
	if (data) {
		type = OSSwapHostToBigInt32(type);
		[iconFamilyElementsData	appendBytes:&type length:sizeof(ResType)];
		SInt32 size = (SInt32)OSSwapHostToBigInt32([data length] + sizeof(ResType) + sizeof(SInt32));
		[iconFamilyElementsData	appendBytes:&size length:sizeof(size)];
		[iconFamilyElementsData	appendData:data];
	} else if (err == noErr) {
		//Get1Resource returns noErr even if it doesn't find the resource. (This is documented in the Resource Manager reference.)
		err = resNotFound;
	}
	return err;
}
- (NSUInteger) extractAllIconsWithID:(ResID)ID error:(out NSError __autoreleasing **)outError {
	OSStatus err = noErr;
	NSUInteger numIconsExtracted = 0;
#define NO_ERROR ((err == noErr) || (err == resNotFound))
#define GOT_RESOURCE (err == noErr)

	err = [self extractExistingIconFamilyWithID:ID];
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kThumbnail32BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kThumbnail8BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kHuge32BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kHuge8BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kHuge8BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kHuge4BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kHuge1BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kLarge32BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kLarge8BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kLarge8BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kLarge4BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kLarge1BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kSmall32BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kSmall8BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kSmall8BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kSmall4BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kSmall1BitMask ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kMini8BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kMini4BitData ID:ID];
	}
	if (NO_ERROR) {
		numIconsExtracted += GOT_RESOURCE;
		err = [self extractIconOfType:kMini1BitMask ID:ID];
	}

	if (!NO_ERROR) {
		if (outError) {
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil];
		}
	}

	return numIconsExtracted;
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
	enum { iconFamilyHeaderSize = sizeof(IconFamilyResource) - sizeof(IconFamilyElement) };
	NSMutableData *iconFamilyData = [NSMutableData dataWithLength:iconFamilyHeaderSize];

	//XXX Here be WET code…
	PRHResourceEnumerator *bundlesEnum = [PRHResourceEnumerator newWithResourceType:'BNDL'];
	for (PRHResource *bundleResource in bundlesEnum) {
		const struct BundleResource *bundlePtr = [bundleResource.data bytes];
		const struct ResourceIDPair *mappings = bundlePtr->iconMappingList.mappings;
		for (UInt16 i = 0; i < bundlePtr->iconMappingList.mappingCount; ++i) {
			const ResID iconResourceID = mappings[i].resourceID;

			iconFamilyElementsData = [NSMutableData new];
			NSError *error = nil;
			NSUInteger numIconsExtracted = [self extractAllIconsWithID:iconResourceID error:&error];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResourceID]];

			if (numIconsExtracted > 0) {
				[iconFamilyData setLength:iconFamilyHeaderSize];
				struct IconFamilyResource *headerPtr = [iconFamilyData mutableBytes];
				headerPtr->resourceType = OSSwapHostToBigConstInt32(kIconFamilyType);
				[iconFamilyData appendData:iconFamilyElementsData];
				headerPtr->resourceSize = (SInt32)OSSwapHostToBigInt32([iconFamilyData length]);

				NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType('BNDL'), iconResourceID];
				NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
				bool successfullyWrote = [iconFamilyData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
				if (!successfullyWrote)
					NSLog(@"Error writing icons found by %@ to %@: error is %@", bundleResource, destinationURL, error);
			}
		}
	}

	PRHResourceEnumerator *modernIconsEnum = [PRHResourceEnumerator newWithResourceType:kIconFamilyType];
	PRHResource *iconResource;
	for (iconResource in modernIconsEnum) {
		if (![processedIconResourceIDs containsObject:[NSNumber numberWithShort:iconResource.ID]])
		{
			iconFamilyElementsData = [NSMutableData new];
			NSError *error = nil;
			NSUInteger numIconsExtracted = [self extractAllIconsWithID:iconResource.ID error:&error];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResource.ID]];

			if (numIconsExtracted > 0) {
				[iconFamilyData setLength:iconFamilyHeaderSize];
				struct IconFamilyResource *headerPtr = [iconFamilyData mutableBytes];
				headerPtr->resourceType = OSSwapHostToBigConstInt32(kIconFamilyType);
				[iconFamilyData appendData:iconFamilyElementsData];
				headerPtr->resourceSize = (SInt32)OSSwapHostToBigInt32([iconFamilyData length]);

				NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType(kIconFamilyType), iconResource.ID];
				NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
				bool successfullyWrote = [iconFamilyData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
				if (!successfullyWrote)
					NSLog(@"Error writing icons found by %@ to %@: error is %@", iconResource, destinationURL, error);
			}
		}
	}

	PRHResourceEnumerator *eightBitIconsEnum = [PRHResourceEnumerator newWithResourceType:kLarge8BitData];
	for (iconResource in eightBitIconsEnum) {
		if (![processedIconResourceIDs containsObject:[NSNumber numberWithShort:iconResource.ID]])
		{
			iconFamilyElementsData = [NSMutableData new];
			NSError *error = nil;
			NSUInteger numIconsExtracted = [self extractAllIconsWithID:iconResource.ID error:&error];
			[processedIconResourceIDs addObject:[NSNumber numberWithShort:iconResource.ID]];

			if (numIconsExtracted > 0) {
				[iconFamilyData setLength:iconFamilyHeaderSize];
				struct IconFamilyResource *headerPtr = [iconFamilyData mutableBytes];
				headerPtr->resourceType = OSSwapHostToBigConstInt32(kIconFamilyType);
				[iconFamilyData appendData:iconFamilyElementsData];
				headerPtr->resourceSize = (SInt32)OSSwapHostToBigInt32([iconFamilyData length]);

				NSString *destinationFilename = [NSString stringWithFormat:destinationFilenameFormat, (__bridge_transfer NSString *)UTCreateStringForOSType(kLarge8BitData), iconResource.ID];
				NSURL *destinationURL = [self.destinationDirectoryURL URLByAppendingPathComponent:destinationFilename isDirectory:NO];
				[iconFamilyData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
				bool successfullyWrote = [iconFamilyData writeToURL:destinationURL options:NSDataWritingAtomic error:&error];
				if (!successfullyWrote)
					NSLog(@"Error writing icons found by %@ to %@: error is %@", iconResource, destinationURL, error);
			}
		}
	}

	CloseResFile(refnum);
	err = ResError();
	return err;
}
- (void) main {
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
}

@end
