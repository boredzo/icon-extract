//
//  PRHExtractIconFromFileOperation.h
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

@interface PRHExtractIconsFromFileOperation : NSOperation

@property(copy) NSURL *sourceURL;
@property(copy) NSURL *destinationDirectoryURL;

@end
