#import "GBCloneWindowController.h"
#import "GBMainWindowController.h"
#import "NSFileManager+OAFileManagerHelpers.h"

@interface GBCloneWindowController ()
- (NSURL*) urlFromTextField;
- (void) update;
@end

#define GBCloneWindowLastURLKey @"GBCloneWindowController-lastURL"


@implementation GBCloneWindowController

@synthesize urlField;
@synthesize nextButton;
@synthesize finishBlock;
@synthesize sourceURL;
@synthesize targetDirectoryURL;
@synthesize targetURL;

- (void) dealloc
{
	self.urlField = nil;
	self.nextButton = nil;
	self.targetDirectoryURL = nil;
	self.targetURL = nil;
	[super dealloc];
}

+ (void) setLastURLString:(NSString*)urlString
{
	[[NSUserDefaults standardUserDefaults] setObject:[[urlString copy] autorelease] forKey:GBCloneWindowLastURLKey];
}

- (void) start
{
	[[GBMainWindowController instance] presentSheet:[self window]];
}

- (IBAction) cancel:(id)sender
{
	[[GBMainWindowController instance] dismissSheet];
	self.finishBlock = nil;
}

- (IBAction) ok:(id)sender
{
	self.sourceURL = [self urlFromTextField];
	
	if ([self.urlField stringValue])
	{
		[GBCloneWindowController setLastURLString:self.urlField.stringValue];
	}
	
	if (self.sourceURL)
	{
		[[GBMainWindowController instance] dismissSheet];
		
		NSString* suggestedName = [[self.sourceURL absoluteString] lastPathComponent];
		suggestedName = [[suggestedName componentsSeparatedByString:@":"] lastObject]; // handle the case of "oleg.local:test.git"
		if (!suggestedName) suggestedName = @"";
		NSInteger dotgitlocation = 0;
		if (suggestedName && 
			[suggestedName length] > 4 && 
			(dotgitlocation = [suggestedName rangeOfString:@".git"].location) == ([suggestedName length] - 4))
		{
			suggestedName = [suggestedName substringToIndex:dotgitlocation];
		}
		
		NSSavePanel* panel = [NSSavePanel savePanel];
		[panel setMessage:[self.sourceURL absoluteString]];
		[panel setNameFieldLabel:NSLocalizedString(@"Clone To:", @"Clone")];
		[panel setNameFieldStringValue:suggestedName];
		[panel setPrompt:NSLocalizedString(@"Clone", @"Clone")];
		[panel setDelegate:self];
		[[GBMainWindowController instance] sheetQueueAddBlock:^{
			[panel beginSheetModalForWindow:[[GBMainWindowController instance] window] completionHandler:^(NSInteger result){
				[[GBMainWindowController instance] sheetQueueEndBlock];
				if (result == NSFileHandlingPanelOKButton)
				{
					self.targetDirectoryURL = [panel directoryURL];
					self.targetURL = [panel URL]; // this URL is interpreted as a file URL and breaks later
					self.targetURL = [NSURL fileURLWithPath:[self.targetURL path] isDirectory:YES]; // make it directory url explicitly
					
					if (self.targetDirectoryURL && self.targetURL)
					{
						if (self.finishBlock) self.finishBlock();
						self.finishBlock = nil;
						
						// Clean up for next use.
						[self.urlField setStringValue:@""];
						self.sourceURL = nil;
						self.targetDirectoryURL = nil;
						self.targetURL = nil;
					}
				}
				else
				{
					[[GBMainWindowController instance] presentSheet:[self window]];
				}
			}];
		}];
	}
}

- (void) windowDidLoad
{
	[super windowDidLoad];
	[self update];
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSString* lastURLString = [[NSUserDefaults standardUserDefaults] objectForKey:GBCloneWindowLastURLKey];
	if (lastURLString)
	{
		[self.urlField setStringValue:lastURLString];
		[self.urlField selectText:nil];
	}
	[self update];
}





#pragma mark NSTextFieldDelegate


- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self update];
}






#pragma mark NSOpenSavePanelDelegate


- (BOOL)panel:(NSSavePanel*)aPanel validateURL:(NSURL*)url error:(NSError **)outError
{
	return ![[NSFileManager defaultManager] fileExistsAtPath:[url path]];
}


- (NSString*)panel:(NSSavePanel*)aPanel userEnteredFilename:(NSString*)filename confirmed:(BOOL)okFlag
{
	if (okFlag) // on 10.6 we are still not receiving okFlag == NO, so I don't want to have this feature untested.
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:[[aPanel URL] path]]) return nil;
	}
	return filename;
}

- (void)panel:(NSSavePanel*)aPanel didChangeToDirectoryURL:(NSURL *)aURL
{
	NSString* enteredName = [aPanel nameFieldStringValue];
	NSString* uniqueName = enteredName;
	
	if (aURL && enteredName && [enteredName length] > 0)
	{
		NSString* targetPath = [[aPanel directoryURL] path];
		NSUInteger counter = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath:[targetPath stringByAppendingPathComponent:uniqueName]])
		{
			counter++;
			uniqueName = [enteredName stringByAppendingFormat:@"%d", counter];
		}
		[aPanel setNameFieldStringValue:uniqueName];
	}
}






#pragma mark Private



- (NSURL*) urlFromTextField
{
	NSString* urlString = [self.urlField stringValue];
	if ([urlString isEqual:@""]) return nil;
	urlString = [urlString stringByReplacingOccurrencesOfString:@"git clone" withString:@""];
	urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([urlString rangeOfString:@"~/"].location == 0)
	{
		urlString = [urlString stringByReplacingOccurrencesOfString:@"~" withString:NSHomeDirectory()];
	}
	
	if ([urlString rangeOfString:@"://"].location == NSNotFound)
	{
		if ([[NSFileManager defaultManager] fileExistsAtPath:urlString])
		{
			return [NSURL fileURLWithPath:urlString];
		}
		//    urlString = [urlString stringByReplacingOccurrencesOfString:@":/" withString:@"/"]; // git@github.com:/oleganza/path => git@github.com/oleganza/
		//    urlString = [urlString stringByReplacingOccurrencesOfString:@":" withString:@"/~/"]; // git@github.com:oleganza/path => git@github.com/~/oleganza/path
		//    urlString = [urlString stringByReplacingOccurrencesOfString:@"//" withString:@"/"]; // needs a fix if it was domain:/root/path
		//    urlString = [NSString stringWithFormat:@"ssh://%@", urlString];
	}
	NSURL* url = [NSURL URLWithString:urlString];
	return url;
}


- (void) update
{
	[self.nextButton setEnabled:!![self urlFromTextField]];
}





@end
