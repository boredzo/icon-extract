//
//  BundleResourceSupport.h
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

#pragma options align=packed
struct ResourceIDPair {
	ResID localID;
	ResID resourceID;
};

struct BundleLocalIDToToResourceIDMappingList {
	ResType resourceType; //In the file reference mapping, always 'FREF'
	UInt16 mappingCount;
	struct ResourceIDPair mappings[1];
};
struct BundleResource {
	ResType applicationSignature;
	ResID applicationSignatureResourceID;
	UInt16 arrayCount;
	struct BundleLocalIDToToResourceIDMappingList iconMappingList;
	struct BundleLocalIDToToResourceIDMappingList frefMappingList;
};
#pragma options align=reset
