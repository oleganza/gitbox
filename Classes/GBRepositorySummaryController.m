#import "GBRepository.h"
#import "GBRemote.h"
#import "GBRepositorySummaryController.h"
#import "GBTaskWithProgress.h"
#import "GitRepository.h"
#import "GitConfig.h"
#import "NSFileManager+OAFileManagerHelpers.h"

@interface GBRepositorySummaryController ()
@property(nonatomic, retain) NSArray* remotes;
@property(nonatomic, retain) NSArray* labels;
@property(nonatomic, retain) NSArray* fields;
@property(nonatomic, assign) BOOL calculatingSize;

- (NSString*) parentFolder;
- (NSString*) repoTitle;
- (NSString*) repoPath;
- (void) calculateSize;
@end

@implementation GBRepositorySummaryController

@synthesize remotes;
@synthesize labels;
@synthesize fields;
@synthesize calculatingSize;

@synthesize pathLabel;
@synthesize originLabel;
@synthesize remoteLabel1;
@synthesize remoteField1;
@synthesize remoteLabel2;
@synthesize remoteField2;
@synthesize remoteLabel3;
@synthesize remoteField3;
@synthesize remainingView;
@synthesize sizeField;
@synthesize numberOfCommitsField;
@synthesize numberOfContributorsField;

- (void) dealloc
{
	self.remotes = nil;
	self.labels = nil;
	self.fields = nil;
	
	self.pathLabel = nil;
	self.originLabel = nil;  
	[super dealloc];
}

- (id) initWithRepository:(GBRepository*)repo
{
	if ((self = [super initWithRepository:repo]))
	{
	}
	return self;
}

- (NSString*) title
{
	return NSLocalizedString(@"Summary", @"");
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	[self.pathLabel setStringValue:self.repoPath];
	
	self.labels = [NSArray arrayWithObjects:self.remoteLabel1, self.remoteLabel2, self.remoteLabel3, nil];
	self.fields = [NSArray arrayWithObjects:self.remoteField1, self.remoteField2, self.remoteField3, nil];

	// initialize tags so they are invalid
	for (NSTextField* field in fields)
	{
		field.tag = -1;
	}
	
	self.remotes = self.repository.remotes;
	
	NSUInteger linesCount = MIN(remotes.count, self.fields.count);
	
	if (linesCount == 0)
	{
		self.remoteLabel1.stringValue = NSLocalizedString(@"Remote address:", @"");
		self.remoteField1.stringValue = @"";
		self.remoteField1.tag = 0;
		linesCount = 1;
	}
	else if (linesCount == 1)
	{
		self.remoteLabel1.stringValue = NSLocalizedString(@"Remote address:", @"");
		NSString* str = [[remotes objectAtIndex:0] URLString];
		self.remoteField1.stringValue = str ? str : @"";
		self.remoteField1.tag = 0;
	}
	else
	{
		for (NSUInteger i = 0; i < linesCount; i++)
		{
			NSTextField* field = [self.fields objectAtIndex:i];
			NSTextField* label = [self.labels objectAtIndex:i];
			GBRemote* remote   = [self.remotes objectAtIndex:i];
			
			label.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Remote address (%@):", @""), remote.alias];
			NSString* str = [remote URLString];
			field.stringValue = str ? str : @"";
			field.tag = i;
		}
	}
	
	CGFloat remainingViewOffset = 0.0;
	
	for (NSUInteger i = linesCount; i < fields.count; i++)
	{
		NSTextField* f = [self.labels objectAtIndex:i];
		[f setHidden:YES];
		f = [self.fields objectAtIndex:i];
		[f setHidden:YES];
		remainingViewOffset += 32;
	}
	
	NSRect rect = self.remainingView.frame;
	rect.size.height += remainingViewOffset;
	self.remainingView.frame = rect;
	
	[self.repository.libgitRepository.config enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
		NSLog(@"Config: %@ => %@", key, obj);
	}];
	
	[self calculateSize];
	
	// TODO: add label and strings for:
	// - path + disclosure button like in Xcode locations preference
	// - every remote URL (if none, pre)
	
	// TODO: support multiple URLs
	// TODO: add more labels for useless stats like:
	// - number of commits, tags, 
	// - creation date, 
	// - size on disk, 
	// - committers etc.
}


- (void) save
{
	// TODO: save the remote addresses
	// self.remotes
	
	
}


#pragma mark Private


- (void) calculateSize
{
	if (calculatingSize)
	{
		// Try again after 2 and 4 seconds.
		double delayInSeconds = 2.0;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			if (calculatingSize)
			{
				double delayInSeconds = 2.0;
				dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
				dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
					if (calculatingSize) return;
					[self calculatingSize];
				});
				return;
			}
			[self calculatingSize];
		});
		return;
	}
	
	calculatingSize = YES;
	
	self.sizeField.stringValue = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Size on disk:", @""), @""];
	
	[NSFileManager calculateSizeAtURL:self.repository.url completionHandler:^(long long bytes){
		double bytesf = (double)bytes;
		double kbytes = bytesf / 1024.0;
		double mbytes = kbytes / 1024.0;
		double gbytes = mbytes / 1024.0;
		
		NSString* sizeString = [NSString stringWithFormat:@"%qi %@", bytes, NSLocalizedString(@"bytes", @"")];
		
		if (gbytes >= 1.0)
		{
			sizeString = [NSString stringWithFormat:@"%0.1f %@", gbytes, NSLocalizedString(@"Gb", @"")];
		}
		else if (mbytes >= 1.0)
		{
			sizeString = [NSString stringWithFormat:@"%0.1f %@", mbytes, NSLocalizedString(@"Mb", @"")];
		}
		else if (kbytes >= 1.0)
		{
			sizeString = [NSString stringWithFormat:@"%0.1f %@", kbytes, NSLocalizedString(@"Kb", @"")];
		}
		
		self.sizeField.stringValue = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Size on disk:", @""), sizeString];
		
		calculatingSize = NO;
	}];
}



- (NSString*) parentFolder
{
	NSArray* pathComps = [[self.repository.url path] pathComponents];
	
	if ([pathComps count] < 2) return @"";
	
	return [pathComps objectAtIndex:[pathComps count] - 2];
}

- (NSString*) repoTitle
{
	NSString* s = [self.repository.url path];
	s = [s lastPathComponent];
	return s ? s : @"";
}

- (NSString*) repoPath
{
	NSString* s = [self.repository.url path];
	NSString* homePath = NSHomeDirectory();
	if (homePath)
	{
		NSRange r = [s rangeOfString:homePath];
		if (r.location == 0)
		{
			s = [s stringByReplacingOccurrencesOfString:homePath withString:@"~" options:0 range:r];
		}
	}
	return s ? s : @"";
}

- (NSString*) repoURLString
{
	NSString* url = [[self.repository firstRemote] URLString];
	return url ? url : @"";
}

- (IBAction) optimizeRepository:(NSButton*)button
{
	NSString* originalTitle = button.title;
	[button setEnabled:NO];
	NSString* aTitle = NSLocalizedString(@"Optimizing...", @"");
	button.title = aTitle;
	
	GBTaskWithProgress* gitgcTask = [GBTaskWithProgress taskWithRepository:self.repository];
	gitgcTask.arguments = [NSArray arrayWithObjects:@"gc", @"--progress", nil];
	gitgcTask.progressUpdateBlock = ^{
		button.title = [NSString stringWithFormat:@"%@ %d%%", aTitle, (int)roundf(gitgcTask.progress)];
	};
	[gitgcTask launchWithBlock:^{
		[button setEnabled:YES];
		button.title = originalTitle;
		[self calculateSize];
	}];
}

- (IBAction)openInFinder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:self.repository.url];
}

@end
