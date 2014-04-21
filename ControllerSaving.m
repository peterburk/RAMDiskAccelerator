/*

File: ControllerSaving.m

Abstract: Code to implement "SaveAs" functionality to save images.

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

#import <Quartz/Quartz.h>
#import "Controller.h"
#import "ControllerBrowsing.h"
#import "ControllerSaving.h"


@implementation Controller(Saving)

//---------------------------------------------------------------------------------------------------------------------- 
- (NSString*)fileName
{
    return [[[self selectedImageURL] path] lastPathComponent];
}

//---------------------------------------------------------------------------------------------------------------------- 
- (NSURL*)selectedImageURL
{
    return selectedImageURL;
}

//---------------------------------------------------------------------------------------------------------------------- 
- (void)setSelectedImageURL: (NSURL*)url
{
    [self willChangeValueForKey: @"fileName"];
    [selectedImageURL release];
    selectedImageURL = [url retain];
    [self didChangeValueForKey: @"fileName"];
}

//---------------------------------------------------------------------------------------------------------------------- 
- (void) saveImageToPath: (NSString*)path
{
    NSString * newUTType = [saveOptions imageUTType];
    CGImageRef image;
    
    image = (CGImageRef)[imageView image];
    
    if (image)
    {
        NSURL *               url = [NSURL fileURLWithPath: path];
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL((CFURLRef)url, (CFStringRef)newUTType, 1, NULL);
        
        if (dest)
        {
            CGImageDestinationAddImage(dest, image, (CFDictionaryRef)[saveOptions imageProperties]);
            CGImageDestinationFinalize(dest);
            CFRelease(dest);
            
            [self addImageWithPath: path];
            [imageBrowser reloadData];
            [imageBrowser setSelectionIndexes: [NSIndexSet indexSetWithIndex: [images count]-1] byExtendingSelection:NO];
        }
    } else
    {
        NSLog(@"*** saveImageToPath - no image");
    }
}

// ---------------------------------------------------------------------------------------------------------------------
- (void)savePanelDidEnd: (NSSavePanel *)sheet
             returnCode: (NSInteger)returnCode
            contextInfo: (void *)contextInfo
{
    if (returnCode == NSOKButton)
    {
        [self saveImageToPath: [sheet filename]];
    }
}

// ---------------------------------------------------------------------------------------------------------------------
- (IBAction)saveAs: (id)sender
{
    NSSavePanel *   savePanel;
    NSString *      utType;
    NSDictionary *  metaData;
    NSString *      fileName;
    
    savePanel = [NSSavePanel savePanel];

    utType = (id)CGImageSourceGetTypeWithURL((CFURLRef)[self selectedImageURL], NULL);
    if (utType)
    {
        metaData = [(IKImageView*)imageView imageProperties];
        fileName = [self fileName];
        
        saveOptions = [[IKSaveOptions alloc] initWithImageProperties: metaData
                                                         imageUTType: utType];
        
        [saveOptions addSaveOptionsAccessoryViewToSavePanel: savePanel];
        
        
        [savePanel beginSheetForDirectory: NULL
                                     file: fileName 
                           modalForWindow: [imageView window]
                            modalDelegate: self
                           didEndSelector: @selector(savePanelDidEnd:returnCode:contextInfo:) 
                              contextInfo: NULL];
    }
}
@end
