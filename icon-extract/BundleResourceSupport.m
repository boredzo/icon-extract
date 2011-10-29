//
//  BundleResourceSupport.m
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

#import "BundleResourceSupport.h"

static OSStatus flipBundleMembers(
	OSType dataDomain,
	OSType dataType,
	SInt16 id,
	void *dataPtr,
	ByteCount dataSize,
	Boolean currentlyNative,
	void *refcon
);

extern void PRHInstallBundleResourceFlipper(void) {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		CoreEndianInstallFlipper(kCoreEndianResourceManagerDomain, 'BNDL', flipBundleMembers, NULL);
	});
};

static inline void swapAccordingToSize(void *ptr, size_t size) {
	switch(size) {
		case 1:
			break;
		case 2:;
			UInt16 *ptr16 = ptr;
			*ptr16 = OSSwapInt16(*ptr16);
			break;
		case 4:;
			UInt32 *ptr32 = ptr;
			*ptr32 = OSSwapInt32(*ptr32);
			break;
		case 8:;
			UInt64 *ptr64 = ptr;
			*ptr64 = OSSwapInt64(*ptr64);
			break;
	}
}
#define IF_WITHIN_RANGE(start, member, dataSize) \
	if (((((void *)&(member)) - (void *)start) + sizeof(member)) <= dataSize)
#define SWAP_IF_WITHIN_RANGE(start, member, dataSize) do{\
	if (((((void *)&(member)) - (void *)start) + sizeof(member)) <= dataSize) { \
		swapAccordingToSize(&(member), sizeof(member)); \
		swapped = true; \
	} else \
		swapped = false; \
	}while(0)

static bool swapMembersInMappingList(struct BundleResource *resPtr, struct BundleLocalIDToToResourceIDMappingList *mappingListPtr, ByteCount dataSize, bool currentlyNative) {
	void *dataPtr = resPtr;
	bool swapped = true;

	size_t expectedSizeFromIconMappingListStart = dataSize - ((void *)mappingListPtr - dataPtr);
	SWAP_IF_WITHIN_RANGE(mappingListPtr, mappingListPtr->resourceType, expectedSizeFromIconMappingListStart);
	UInt16 mappingCount = 0;
	IF_WITHIN_RANGE(mappingListPtr, mappingListPtr->mappingCount, expectedSizeFromIconMappingListStart) {
		mappingCount = currentlyNative ? mappingListPtr->mappingCount : OSSwapInt16(mappingListPtr->mappingCount);
	}
	SWAP_IF_WITHIN_RANGE(mappingListPtr, mappingListPtr->mappingCount, expectedSizeFromIconMappingListStart);

	struct ResourceIDPair *mappingsPtr = mappingListPtr->mappings;
	size_t expectedSizeFromIconMappingsStart = dataSize - ((void *)mappingsPtr - dataPtr);
	for (UInt16 i = 0; i < mappingCount; ++i) {
		SWAP_IF_WITHIN_RANGE(mappingsPtr, mappingsPtr[i].localID, expectedSizeFromIconMappingsStart);
		SWAP_IF_WITHIN_RANGE(mappingsPtr, mappingsPtr[i].resourceID, expectedSizeFromIconMappingsStart);
	}

	return swapped;
}

static OSStatus flipBundleMembers(
	OSType dataDomain,
	OSType dataType,
	SInt16 id,
	void *dataPtr,
	ByteCount dataSize,
	Boolean currentlyNative,
	void *refcon
) {
	bool swapped = true;
	struct BundleResource *resPtr = dataPtr;
	SWAP_IF_WITHIN_RANGE(resPtr, resPtr->applicationSignature, dataSize);
	SWAP_IF_WITHIN_RANGE(resPtr, resPtr->applicationSignatureResourceID, dataSize);
	SWAP_IF_WITHIN_RANGE(resPtr, resPtr->arrayCount, dataSize);

	if (swapped) {
		swapped = swapMembersInMappingList(resPtr, &(resPtr->iconMappingList), dataSize, currentlyNative);
		if (swapped)
			swapped = swapMembersInMappingList(resPtr, &(resPtr->frefMappingList), dataSize, currentlyNative);
	}

	return noErr;
}
