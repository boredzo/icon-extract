//
//  main.m
//  icon-extract
//
//  Created by Peter Hosey on 2011-10-29.
//  Copyright (c) 2011 Peter Hosey. All rights reserved.
//

#import "PRHExtractIconsFromFileOperation.h"

int main (int argc, char **argv) {
	@autoreleasepool {
		NSOperationQueue *queue = [NSOperationQueue mainQueue];
		NSFileManager *mgr = [NSFileManager new];
		NSString *cwdPath = nil;

		NSEnumerator *argsEnum = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
		[argsEnum nextObject]; //Drop the executable name/path on the floor

		NSString *arg;
		for (arg in argsEnum) {
			if (![arg isAbsolutePath]) {
				if (!cwdPath)
					cwdPath = [mgr currentDirectoryPath];
				arg = [cwdPath stringByAppendingPathComponent:arg];
			}

			NSURL *sourceURL = [NSURL fileURLWithPath:arg];
			NSString *sourceFilename = [sourceURL lastPathComponent];
			NSString *sourceBaseFilename = [sourceFilename stringByDeletingPathExtension];
			NSURL *destinationURL = [[sourceURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@-icons.out", sourceBaseFilename] isDirectory:YES];
			NSError *error = nil;
			if (![mgr createDirectoryAtURL:destinationURL withIntermediateDirectories:NO attributes:nil error:&error]) {
				if (([error domain] == NSCocoaErrorDomain) && ([error code] == NSFileWriteFileExistsError))
					/*That's cool.*/;
				else {
					NSLog(@"Couldn't create output directory at %@: %@", destinationURL, error);
					continue;
				}
			}

			PRHExtractIconsFromFileOperation *op = [PRHExtractIconsFromFileOperation new];
			op.sourceURL = sourceURL;
			op.destinationDirectoryURL = destinationURL;
			[queue addOperation:op];
		}

		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
	}
	return EXIT_SUCCESS;
}

