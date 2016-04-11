/*
 * ramDiskAccelerator
 * 2014-04-09 (code), 2014-04-11 (icon), 2014-04-21 (update frequency, comments, website)
 * Peter Burkimsher
 * peterburk@gmail.com
 *
 * Stores files on a RAM disk to make saving faster. Compares them periodically with files on disk, and copies them to
 * disk if the MD5 hash has changed. 
 *
 * Interface based on Apple's example code, eyePhoto-step7, ImageKitDemo. 
 * Original available at:
 * http://genekc07.stowers.org/Users/mec/Library/Developer/Shared/Documentation/DocSets/com.apple.adc.documentation.AppleLion.CoreReference.docset/Contents/Resources/Documents/#samplecode/ImageKitDemo/Introduction/Intro.html
 *
 */


/*

File: Controller.m

Abstract: WindowController for ImageKit Browser application. Calls code
          in the ControllerBrowser to allocate the datasource array for 
          browsing. The datasource array contains instances of MyImageObject, 
          which is the datasource object -- it represents one item in the 
          browser.

Version: 1.1

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright © 2007-2009 Apple Inc., All Rights Reserved

*/


#import "Controller.h"
#import "ControllerBrowsing.h"
#import "ControllerViewing.h"
#import "ControllerEditing.h"


/* the controller */
@implementation Controller

- (void) dealloc
{
    [images release];
	[filteredOutImages release];
	
    [super dealloc];
}


#pragma mark -
#pragma mark awakeFromNib

- (void) awakeFromNib
{
//    NSDockTile *dockTile = [NSApp dockTile];
    
    [self setupBrowsing];
    [self setupViewing];
    [self setupEditing];

    [imageBrowser setAllowsEmptySelection: NO];
    [imageBrowser setSelectionIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection:NO];
    
    // Create a RAM disk on startup
    [self createRamDisk];
    
    // Begin the file saving loop on startup
    [self timerUpdate];
}

/*
 * createRamDisk: Creates a RAM disk
 */
- (void)createRamDisk
{
    // Read the RAM Disk size as a string from the interface
    NSString* ramDiskSizeString = [ramDiskSizeTextField stringValue];
    
    // If the RAM Disk size isn't set, set it to 32 MB by default.
    if ([ramDiskSizeString isEqualToString:@""])
    {
        // Update the interface
        [ramDiskSizeTextField setStringValue:@"32"];
        // Read it back from the interface again
        ramDiskSizeString = [ramDiskSizeTextField stringValue];
    }
    
    // The RAM Disk size as an integer value
    NSInteger ramDiskSizeInteger = [ramDiskSizeString integerValue];
    
    // The block size
    NSInteger blockSize = 2000;
    
    // Multiply the RAM Disk size by the block size to get the size for hdiutil.
    ramDiskSizeInteger = ramDiskSizeInteger * blockSize;
    
    // Create the RAM Disk using the hdiutil command
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *createRamDiskScript = [NSString stringWithFormat:@"do shell script \"/usr/bin/hdiutil attach -nomount ram://%d\"", ramDiskSizeInteger];
    NSAppleScript *createRamDiskScriptAS = [[NSAppleScript alloc] initWithSource: createRamDiskScript];
    NSAppleEventDescriptor* returnValue = [createRamDiskScriptAS executeAndReturnError:nil];

    // Get the returned value as a string
    NSString* ramDiskDevice = [returnValue stringValue];
    
    NSString* ramDiskName = [ramDiskDevice lastPathComponent];
    
    // Format the RAM Disk using the newfs_hfs command
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *newFsScript = [NSString stringWithFormat:@"do shell script \"newfs_hfs %@\"", ramDiskDevice];
    NSAppleScript *newFsScriptAS = [[NSAppleScript alloc] initWithSource: newFsScript];
    NSAppleEventDescriptor* newFsReturnValue = [newFsScriptAS executeAndReturnError:nil];

    // Create a mount point for the RAM Disk using the mkdir command. There's probably a better way to do this in Cocoa. 
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *newFolderScript = [NSString stringWithFormat:@"do shell script \"mkdir \\\"/Volumes/RAMDisk%@\\\"\"", ramDiskName];
    NSAppleScript *newFolderScriptAS = [[NSAppleScript alloc] initWithSource: newFolderScript];
    NSAppleEventDescriptor* newFolderReturnValue = [newFolderScriptAS executeAndReturnError:nil];

    // Mount the RAM Disk using the diskutil command
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *mountScript = [NSString stringWithFormat:@"do shell script \"diskutil mount -mountpoint \\\"/Volumes/RAMDisk%@/\\\" %@\"", ramDiskName, ramDiskDevice];
    NSAppleScript *mountScriptAS = [[NSAppleScript alloc] initWithSource: mountScript];
    NSAppleEventDescriptor* mountScriptReturnValue = [mountScriptAS executeAndReturnError:nil];

    [ramDiskNameTextField setStringValue:ramDiskName];
    
}

/*
 * timerUpdate: Backs up every updateFrequency seconds
 */
- (void)timerUpdate
{
    // The number of seconds between each save
    NSString* updateFrequencyString;
    NSInteger updateFrequencyInteger;
    
    // The number of files to be backed up
    NSInteger numberFiles = [images count];
    
    // If there is more than one file
    if (numberFiles > 0)
    {
        
        // For every file
        for (int currentFile = 0; currentFile < numberFiles; currentFile++)
        {
            // Get this file as an object
            id thisFile = [images objectAtIndex:currentFile];
            
            // Get the file path as a string
            NSString *thisFilePath = [thisFile imageRepresentation];
            
            // Call the backupFile method
            [self backupFile:thisFilePath];
            
            // Debug prompt
#ifdef DEBUG
            // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
            NSString *dialogScript = [NSString stringWithFormat:@"tell application \"Finder\" to display dialog \"%@\"", thisFilePath];
            NSAppleScript *dialogScriptAS = [[NSAppleScript alloc] initWithSource: dialogScript];
            NSAppleEventDescriptor* returnValue = [dialogScriptAS executeAndReturnError:nil];
            
            // Get the returned value as a string
            NSString* returnText = [returnValue stringValue];
#endif
        } // end for each file
        
    } // end if there are files
    
    
    // Find out how often we should save
    updateFrequencyString = [updateFrequencyTextField stringValue];
    
    // If the update frequency is blank
    if ([updateFrequencyString isEqualToString:@""])
    {
        // Set the update frequency to 5 seconds by default
        [updateFrequencyTextField setStringValue:@"5"];
        // Read the interface again
        updateFrequencyString = [updateFrequencyTextField stringValue];
    }
    
    // Convert the string to an integer
    updateFrequencyInteger = [updateFrequencyString integerValue];
    
    // Call the same method again after updateFrequency seconds
    [NSTimer scheduledTimerWithTimeInterval:updateFrequencyInteger target:self selector:@selector(timerUpdate) userInfo:nil repeats:NO];
}

/*
 * backupFile: Backs up the file from the RAM disk to the hard disk
 */
- (void)backupFile:(NSString*)thisFilePath
{
    // The file name
    NSString* thisFileName;
    
    // The RAM disk name (/dev/disk2)
    NSString* ramDiskName = [ramDiskNameTextField stringValue];
    
    // Split the filename from the path
    thisFileName = [thisFilePath lastPathComponent];
    
    // Calculate the MD5 hash of the file on the RAMDisk
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *ramDiskMd5Script = [NSString stringWithFormat:@"do shell script \"md5 -q \\\"/Volumes/RAMDisk%@/%@\\\"\"", ramDiskName, thisFileName];
    NSAppleScript *ramDiskMd5ScriptAS = [[NSAppleScript alloc] initWithSource: ramDiskMd5Script];
    NSAppleEventDescriptor* ramDiskMd5ReturnValue = [ramDiskMd5ScriptAS executeAndReturnError:nil];
    
    // Get the returned value as a string
    NSString* ramDiskMD5 = [ramDiskMd5ReturnValue stringValue];
    
    // Calculate the MD5 hash of the file on the hard disk
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *hardDiskMd5Script = [NSString stringWithFormat:@"do shell script \"md5 -q \\\"%@\\\"\"", thisFilePath];
    NSAppleScript *hardDiskMd5ScriptAS = [[NSAppleScript alloc] initWithSource: hardDiskMd5Script];
    NSAppleEventDescriptor* hardDiskMd5ReturnValue = [hardDiskMd5ScriptAS executeAndReturnError:nil];
    
    // Get the returned value as a string
    NSString* hardDiskMD5 = [hardDiskMd5ReturnValue stringValue];
    
    // If the hashes of the files are not the same
    if (![ramDiskMD5 isEqualToString:hardDiskMD5])
    {
        // Use the UNIX cp command to copy the file. There's probably a better way to do this in Cocoa. 
        // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
        NSString *copyScript = [NSString stringWithFormat:@"do shell script \"cp \\\"/Volumes/RAMDisk%@/%@\\\" \\\"%@\\\"\"", ramDiskName, thisFileName, thisFilePath];
        NSAppleScript *copyScriptAS = [[NSAppleScript alloc] initWithSource: copyScript];
        NSAppleEventDescriptor* returnValue = [copyScriptAS executeAndReturnError:nil];
        
        // Get the returned value as a string
        NSString* returnText = [returnValue stringValue];
        
    } // end if the file hashes are different
} // end backupFile

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}
- (IBAction)newRamDiskButtonClicked:(id)sender
{
    [self createRamDisk];
//    [self timerUpdate];
}
@end
