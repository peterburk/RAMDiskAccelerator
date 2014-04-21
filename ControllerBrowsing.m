/*

File: ControllerBrowsing.m

Abstract: Implementation of the data source object (MyImageObject) which
          represents one item in the browser. Contains code to implement the
          following protocols:
           
          - IKImageBrowserDataSource informal protocol, which declares the 
          methods that an instance of IKImageBrowserView uses to access 
          the contents of its data source object. 

          - IKImageBrowserItem informal protocol, which declares the 
          methods that an instance of IKImageBrowserView uses to access 
          the contents of its data source for a given item.

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
#import "ImageBrowserBAckgroundLayer.h"


/* a simple C function that open an NSOpenPanel and return an array of selected filepath */
static NSArray *openFiles()
{ 
    NSOpenPanel *panel;

    panel = [NSOpenPanel openPanel];        
    [panel setFloatingPanel:YES];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:YES];
	int i = [panel runModalForTypes:nil];
	if(i == NSOKButton){
		return [panel filenames];
    }
    
    return nil;
}    


/* Our datasource object : represents one item in the browser */
@interface MyImageObject : NSObject{
    NSString *path; 
}
@end

@implementation MyImageObject

- (void) dealloc
{
    [path release];
    [super dealloc];
}

- (void) setPath:(NSString *) aPath
{
    if(path != aPath){
        [path release];
        path = [aPath retain];
    }
}

#pragma mark -
#pragma mark item data source protocol

- (NSString *)  imageRepresentationType
{
	return IKImageBrowserPathRepresentationType;
}

- (id)  imageRepresentation
{
	return path;
}

- (NSString *) imageUID
{
    return path;
}

- (id) imageTitle
{
	return [path lastPathComponent];
}

@end



/* the controller */
@implementation Controller(Browsing)


#pragma mark -
#pragma mark import images from file system

/* 
 code that parse a repository and add all entries to our datasource array,
*/

- (void) addImageWithPath:(NSString *) path
{   
    [self willChangeValueForKey: @"totalNumberOfItems"];
    MyImageObject *item;
    
    NSString *filename = [path lastPathComponent];

    NSString* ramDiskName = [ramDiskNameTextField stringValue];
    
    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *copyScript = [NSString stringWithFormat:@"do shell script \"cp \\\"%@\\\" \\\"/Volumes/RAMDisk%@/%@\\\"\"", path, ramDiskName, filename];
    NSAppleScript *copyScriptAS = [[NSAppleScript alloc] initWithSource: copyScript];
    NSAppleEventDescriptor* returnValue = [copyScriptAS executeAndReturnError:nil];
    
    // Get the returned value as a string
    NSString* returnText = [returnValue stringValue];

    // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
    NSString *openScript = [NSString stringWithFormat:@"do shell script \"open \\\"/Volumes/RAMDisk%@/%@\\\"\"", ramDiskName, filename];
    NSAppleScript *openScriptAS = [[NSAppleScript alloc] initWithSource: openScript];
    NSAppleEventDescriptor* openReturnValue = [openScriptAS executeAndReturnError:nil];
    
	/* skip '.*' */
	if([filename length] > 0)
    {
		char *ch = (char*) [filename UTF8String];
		
		if(ch)
        {
			if(ch[0] == '.')
            {
				return;
            }
        }
	}
	    
    
	item = [[MyImageObject alloc] init];
	[item setPath:path];
	[images addObject:item];
	[item release];
    [self didChangeValueForKey: @"totalNumberOfItems"];
}

- (void) addImagesFromDirectory:(NSString *) path
{
    int i, n;
    BOOL dir;
	
    [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir];
    
    if(dir){
        NSArray *content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];

        n = [content count];
        
        for(i=0; i<n; i++)
			[self addImageWithPath:[path stringByAppendingPathComponent:[content objectAtIndex:i]]];
    }
    else
    {
        [self addImageWithPath:path];
	}
    
	[imageBrowser reloadData];
}



#pragma mark -
#pragma mark setupBrowsing


- (void) setupBrowsing
{
	//allocate our datasource array: will contain instances of MyImageObject
    images = [[NSMutableArray alloc] init];
    
	//-- add two directory to the datasource at launch 
//	[self addImagesFromDirectory:@"/Library/Desktop Pictures/Nature/"];
//	[self addImagesFromDirectory:@"/Library/Desktop Pictures/"];
    
	//-- initial coordinate set in IB is wrong. reset it to [0;0]
	[imageBrowser setFrameOrigin:NSZeroPoint];
	
	//-- change the appearance of the view
	[imageBrowser setCellsStyleMask:IKCellsStyleTitled | IKCellsStyleOutlined];
	
	//-- add a backgrund layer
//	ImageBrowserBackgroundLayer *backgroundLayer = [[[ImageBrowserBackgroundLayer alloc] init] autorelease];
//	[imageBrowser setBackgroundLayer:backgroundLayer];
//	backgroundLayer.owner = imageBrowser;
	
	//-- change default font 
	// create a centered paragraph style
	NSMutableParagraphStyle *paraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[paraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraphStyle setAlignment:NSCenterTextAlignment];
	
	NSMutableDictionary *attributes = [[[NSMutableDictionary alloc] init] autorelease];	
	[attributes setObject:[NSFont systemFontOfSize:12] forKey:NSFontAttributeName]; 
	[attributes setObject:paraphStyle forKey:NSParagraphStyleAttributeName];	
	[attributes setObject:[NSColor blackColor] forKey:NSForegroundColorAttributeName];
	[imageBrowser setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];
	
	attributes = [[[NSMutableDictionary alloc] init] autorelease];	
	[attributes setObject:[NSFont boldSystemFontOfSize:12] forKey:NSFontAttributeName]; 
	[attributes setObject:paraphStyle forKey:NSParagraphStyleAttributeName];	
	[attributes setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
	
	[imageBrowser setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
	
	//change selection color
	[imageBrowser setValue:[NSColor colorWithCalibratedRed:0 green:0.2 blue:0.5 alpha:1.0] forKey:IKImageBrowserSelectionColorKey];
}


#pragma mark -
#pragma mark actions

/* "add" button was clicked */
- (IBAction) addImageButtonClicked:(id) sender
{   
    NSArray *path = openFiles();
    
    if(!path){ 
        NSLog(@"No path selected, return..."); 
        return; 
    }
        
	int i, n;
	
	n = [path count];
	for(i=0; i<n; i++)
		[self addImagesFromDirectory:[path objectAtIndex:i]];
}

- (IBAction) zoomSliderDidChange:(id)sender
{
    [imageBrowser setZoomValue:[sender floatValue]];
}

#pragma mark -
#pragma mark  drag'n drop

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	return [self draggingUpdated:sender];
}


- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	if ([sender draggingSource] == imageBrowser) 
		return NSDragOperationMove;
	
    return NSDragOperationCopy;
}


- (BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
    [self willChangeValueForKey: @"totalNumberOfItems"];
    NSData *data = nil;
    NSString *errorDescription;
    
	// if we are dragging from the browser itself, ignore it
	if ([sender draggingSource] == imageBrowser) 
		return NO;
	
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    
    if ([[pasteboard types] containsObject:NSFilenamesPboardType]) 
        data = [pasteboard dataForType:NSFilenamesPboardType];
	
    if(data){
        NSArray *filenames = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:kCFPropertyListImmutable format:nil errorDescription:&errorDescription];		
		
        int i, n;
        n = [filenames count];
        for(i=0; i<n; i++){
			MyImageObject *item = [[MyImageObject alloc] init];

            NSString* path = [filenames objectAtIndex:i];

            [item setPath:path];
            
            NSString *filename = [path lastPathComponent];
            
            NSString* ramDiskName = [ramDiskNameTextField stringValue];
            
            // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
            NSString *copyScript = [NSString stringWithFormat:@"do shell script \"cp \\\"%@\\\" \\\"/Volumes/RAMDisk%@/%@\\\"\"", path, ramDiskName, filename];
            NSAppleScript *copyScriptAS = [[NSAppleScript alloc] initWithSource: copyScript];
            NSAppleEventDescriptor* returnValue = [copyScriptAS executeAndReturnError:nil];
            
            // Get the returned value as a string
            NSString* returnText = [returnValue stringValue];
            
            // A shell script wrapped in AppleScript wrapped in Cocoa. Nasty, but cleaner than NSTask.
            NSString *openScript = [NSString stringWithFormat:@"do shell script \"open \\\"/Volumes/RAMDisk%@/%@\\\"\"", ramDiskName, filename];
            NSAppleScript *openScriptAS = [[NSAppleScript alloc] initWithSource: openScript];
            NSAppleEventDescriptor* openReturnValue = [openScriptAS executeAndReturnError:nil];
            
			[images insertObject:item atIndex:[imageBrowser indexAtLocationOfDroppedItem]];
			[item release];
        }
		
		[imageBrowser reloadData];
    }
	
    [self didChangeValueForKey: @"totalNumberOfItems"];
	return YES;
}

#pragma mark -
#pragma mark IKImageBrowserDataSource

/* implement image-browser's datasource protocol 
   Our datasource representation is a simple mutable array
*/

- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView *) view
{
    return [images count];
}

- (id) imageBrowser:(IKImageBrowserView *) view itemAtIndex:(NSUInteger) index
{
    return [images objectAtIndex:index];
}


#pragma mark -
#pragma mark optional datasource methods : reordering / removing

- (void) imageBrowser:(IKImageBrowserView *) aBrowser removeItemsAtIndexes: (NSIndexSet *) indexes
{
    [self willChangeValueForKey: @"totalNumberOfItems"];
	[images removeObjectsAtIndexes:indexes];
	[imageBrowser reloadData];
    [self didChangeValueForKey: @"totalNumberOfItems"];
}

- (BOOL) imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(unsigned int)destinationIndex
{
	NSArray *tempArray = [images objectsAtIndexes:indexes];
	[images removeObjectsAtIndexes:indexes];
	
	destinationIndex -= [indexes countOfIndexesInRange:NSMakeRange(0, destinationIndex)];
	[images insertObjects:tempArray atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(destinationIndex, [tempArray count])]];
	[imageBrowser reloadData];
	
	return YES;
}

#pragma mark -
#pragma mark misc
- (void)setNumberOfDisplayedItems: (int)value{}
- (void)setTotalNumberOfItems: (int)value{}
- (void)setHasFilteredItems: (BOOL)value{}

- (int) numberOfDisplayedItems
{
    return [images count];
}
            
- (int) totalNumberOfItems
{
    return [filteredOutImages count] + [images count];
}

- (BOOL)hasFilteredItems
{
    return ([filteredOutImages count] > 0);
}

#pragma mark -
#pragma mark search

/* 
  this code filters the "images" array depending on the current search field value. All items that are filtered-out are kept in the 
  "filteredOutImages" array (and corresponding indexes are kept in "filteredOutIndexes" in order to restore these indexes when the search field is cleared
 */

- (BOOL) keyword:(NSString *) aKeyword matchSearch:(NSString *) search
{
    NSRange r = [aKeyword rangeOfString:search options:NSCaseInsensitiveSearch];
    return (r.length>0 && r.location>=0);
}

- (IBAction) searchFieldChanged:(id) sender
{
    [self willChangeValueForKey: @"numberOfDisplayedItems"];
    [self willChangeValueForKey: @"hasFilteredItems"];
	if(filteredOutImages == nil){
		//first time we use the search field
		filteredOutImages = [[NSMutableArray alloc] init];
		filteredOutIndexes = [[NSMutableIndexSet alloc] init];
	}
	else{
		//restore the original datasource, and restore the initial ordering if possible

		NSUInteger lastIndex = [filteredOutIndexes lastIndex];
		if(lastIndex >= [images count] + [filteredOutImages count]){
			//can't restore previous indexes, just insert filtered items at the beginning 
			[images insertObjects:filteredOutImages atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [filteredOutImages count])]];
		}
		else
			[images insertObjects:filteredOutImages atIndexes:filteredOutIndexes];

		[filteredOutImages removeAllObjects];
		[filteredOutIndexes removeAllIndexes];
	}
	
	//add filtered images to the filteredOut array
	NSString *searchString = [sender stringValue];

    if(searchString != nil && [searchString length] > 0){
		int i, n;
		
		n = [images count];
		
		for(i=0; i<n; i++){
			MyImageObject *anItem = [images objectAtIndex:i];
			
			if([self keyword:[anItem imageTitle] matchSearch:searchString] == NO){
				[filteredOutImages addObject:anItem];
				[filteredOutIndexes addIndex:i];
			}
		}
	} 
	
	//remove filtered-out images from the datasource array
	[images removeObjectsInArray:filteredOutImages];
	
	//reflect changes in the browser
	[imageBrowser reloadData];
    if ([images count] > 0)
        [imageBrowser setSelectionIndexes: [NSIndexSet indexSetWithIndex: 0] byExtendingSelection:NO];

    [self didChangeValueForKey: @"numberOfDisplayedItems"];
    [self didChangeValueForKey: @"hasFilteredItems"];
}


@end
