#import "GBCommit.h"
#import "GBRepository.h"
#import "GBChange.h"
#import "GBStyle.h"
#import "GBCommitViewController.h"
#import "GBUserpicController.h"
#import "GBRepositoryController.h"
#import "GBMainWindowController.h"

#import "NSArray+OAArrayHelpers.h"
#import "NSSplitView+OASplitViewHelpers.h"
#import "NSString+OAStringHelpers.h"
#import "NSView+OAViewHelpers.h"
#import "NSObject+OAPerformBlockAfterDelay.h"
#import "NSAttributedString+OAAttributedStringHelpers.h"

#import <QuartzCore/QuartzCore.h>

@interface GBCommitViewController ()
@property(nonatomic,strong) GBUserpicController* userpicController;
- (void) updateViews;
- (void) updateCommitHeader;
- (void) updateTemplate:(NSTextStorage*)storage withCommit:(GBCommit*)aCommit;
- (void) updateMessageStorage:(NSMutableAttributedString*)storage;
- (void) updateHeaderSize;
- (void) tableViewDidResize:(id)notification;
- (NSString*) mailtoLinkForEmail:(NSString*)email commit:(GBCommit*)aCommit;
- (void) highlightURLsInAttributedString:(NSMutableAttributedString*)textStorage;
@end

@implementation GBCommitViewController

@synthesize headerRTFTemplate;
@synthesize headerTextView;
@synthesize messageTextView;
@synthesize horizontalLine;
@synthesize authorImage;
@synthesize userpicController;

- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:nil 
												  object:self.tableView];
	
}



#pragma mark GBBaseViewController



- (void) setCommit:(GBCommit*)aCommit
{
	[super setCommit:aCommit];
	[self updateViews];
}


- (void) setChanges:(NSArray *)aChanges
{
	[super setChanges:aChanges];
	[self updateViews];
}





#pragma mark NSViewController




- (void) loadView
{
	[super loadView];
	
	[self.authorImage setImage:nil];
	
	if (!self.userpicController)
	{
		self.userpicController = [GBUserpicController new];
	}
	
	[self updateViews];
	
	[self.tableView registerForDraggedTypes:[NSArray arrayWithObjects:NSStringPboardType, NSFilenamesPboardType, nil]];
	[self.tableView setDraggingSourceOperationMask:NSDragOperationNone forLocal:YES];
	[self.tableView setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
	[self.tableView setVerticalMotionCanBeginDrag:YES];
	
	NSDictionary* linkAttrs = [NSDictionary dictionaryWithObjectsAndKeys:                                              
							   [GBStyle linkColor], NSForegroundColorAttributeName, 
							   [NSNumber numberWithInt:NSUnderlineStyleNone], NSUnderlineStyleAttributeName,
							   [NSCursor pointingHandCursor], NSCursorAttributeName, 
							   nil];
	
	[self.headerTextView setLinkTextAttributes:linkAttrs];
	[self.messageTextView setLinkTextAttributes:linkAttrs];
	
	// DOESN'T WORK for programmatically filled views
	//  [self.messageTextView setAutomaticLinkDetectionEnabled:NO];
}





#pragma mark Update



- (void) updateViews
{
	if (self.commit.changes.count < 1)
	{
		[self.commit loadChangesWithBlock:^{}];
	}
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSViewFrameDidChangeNotification 
												  object:self.tableView];
	[self updateCommitHeader];
	[self.tableView setPostsFrameChangedNotifications:YES];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(tableViewDidResize:)
												 name:NSViewFrameDidChangeNotification
											   object:self.tableView];
	
	// Fix for Lion: scroll to the top when switching commit
	{
		NSScrollView* scrollView = self.tableView.enclosingScrollView;
		NSClipView* clipView = scrollView.contentView;
		[clipView scrollToPoint:NSMakePoint(0, 0)];
		[scrollView reflectScrolledClipView:clipView];
	}
}

- (void) updateCommitHeader
{
	GBCommit* aCommit = self.commit;
	
	if (!aCommit) return;
	if ([aCommit isStage]) return;
	
	[self.headerTextView setEditable:NO];
	[self.headerTextView setString:@""];
	
	if (!self.headerRTFTemplate)
	{
		self.headerRTFTemplate = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"GBCommitViewControllerHeader" ofType:@"rtf"]];
	}
	
	{
		NSTextStorage* storage = [self.headerTextView textStorage];
		[storage beginEditing];
		[storage readFromData:self.headerRTFTemplate options:nil documentAttributes:nil];
		[self updateTemplate:storage withCommit:aCommit];
		[storage endEditing];
	}
	
	NSString* message = aCommit.message ? aCommit.message : @"";
	{
		// this hoopla with replacing attributed string is needed because otherwise during search highlighted color is applied to the whole string, not the specified range.
		NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString:message];
		[attrString beginEditing];
		[self updateMessageStorage:attrString];
		[attrString endEditing];
		
		NSTextStorage* storage = [self.messageTextView textStorage];
		[storage setAttributedString:attrString];
	}
	
	NSString* email = aCommit.authorEmail;
	
	[self.authorImage setImage:nil];

	[self.userpicController loadImageForEmail:email withBlock:^{
		if (email && [self.commit.authorEmail isEqualToString:email]) // make sure we are still displaying the email we've asked for
		{
			NSImage* image = [self.userpicController imageForEmail:email];
			[self.authorImage setImage:image];
		}
		self.authorImage.layer.masksToBounds = YES;
		self.authorImage.layer.cornerRadius = 3.0;
		CGColorRef borderColorRef = CGColorCreateGenericGray(0.0, 0.15);
		self.authorImage.layer.borderColor = borderColorRef;
		CGColorRelease(borderColorRef);
		self.authorImage.layer.borderWidth = 1.0;
		[self updateHeaderSize];
	}];	
	[self updateHeaderSize];
}

- (void) updateMessageStorage:(NSMutableAttributedString*)storage
{
	// I had an idea to paint "Signed-off-by: ..." line in grey, but I have a better use of my time right now. Oleg.
	
	[self highlightURLsInAttributedString:storage];
	
	[storage addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:12.0] range:NSMakeRange(0, [[storage string] length])];
	
	if (self.commit.searchQuery)
	{
		NSColor* highlightColor = [GBStyle searchHighlightColor];
		NSMutableString* storageString = [storage mutableString];
		for (NSValue* value in [self.commit.foundRangesByProperties objectForKey:@"message"])
		{
			NSRange range = [value rangeValue];
			if (range.location != NSNotFound)
			{
				
				[storage addAttribute:NSBackgroundColorAttributeName
								value:highlightColor
								range:range];
				
				// Find other occurrences of the same substring and highlight them.
				// Note: this might not be very consistent with token case-sensitive option, but this does not affect search results - only highlighting.
				NSString* substr = [storageString substringWithRange:range];
				while(1)
				{
					NSRange remainingRange = NSMakeRange(range.location + range.length, [storageString length] - range.location - range.length);
					if (remainingRange.length < 1) break;
					range = [storageString rangeOfString:substr options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch range:remainingRange];
					if (range.length < 1) break;
					[storage addAttribute:NSBackgroundColorAttributeName
									value:highlightColor
									range:range];
				}
			}
		}
	}
}

- (void) updateTemplate:(NSTextStorage*)storage withCommit:(GBCommit*)aCommit
{
	for (NSString* line in [NSArray arrayWithObjects:
							@"	Parent 1: 	$parentId1", 
							@"	Parent 2: 	$parentId2",
							@"	Commit: 	$commitId",
							@"	Date: 	$authorDate",
							@"	Author: 	$Author Name <$author@email>",
							@"	 	Committed by $Committer Name <$committer@email>",
							@"	Tags: 	$tags",
							nil])
	{
		[storage updateAttribute:NSParagraphStyleAttributeName forSubstring:line withBlock:^(id style){
			NSMutableParagraphStyle* mutableStyle = [style mutableCopy];
			if (!mutableStyle)
			{
				mutableStyle = [[NSMutableParagraphStyle alloc] init];
			}
			[mutableStyle setLineBreakMode:NSLineBreakByTruncatingTail];
			return (id)mutableStyle;
		}];
	}
	
	// Replace placeholders
	
	NSMutableString* string = [storage mutableString];
	
	
	NSString* parentId1 = [aCommit.parentIds objectAtIndex:0 or:nil];
	NSString* parentId2 = [aCommit.parentIds objectAtIndex:1 or:nil];
	
	if (!parentId1 && !parentId2)
	{
		[string replaceOccurrencesOfString:@"	Parent 1: 	$parentId1\n" 
								withString:@""];
		[string replaceOccurrencesOfString:@"	Parent 2: 	$parentId2\n" 
								withString:@""];
	}
	else if (parentId1 && !parentId2)
	{
		[string replaceOccurrencesOfString:@"Parent 1:" 
								withString:@"Parent:"];
		[string replaceOccurrencesOfString:@"	Parent 2: 	$parentId2\n" 
								withString:@""];
	}
	
	
	for (NSUInteger parentIndex = 0; parentIndex < [aCommit.parentIds count]; parentIndex++)
	{
		NSString* parentId = [aCommit.parentIds objectAtIndex:parentIndex];
		NSString* placeholder = [NSString stringWithFormat:@"$parentId%d", (int)(parentIndex + 1)];
		[storage addAttribute:NSLinkAttributeName
						value:[NSURL URLWithString:[NSString stringWithFormat:@"gitbox://internal/commits/%@", parentId]]
					substring:placeholder];
		[string replaceOccurrencesOfString:placeholder withString:parentId];    
	}
	
	[storage addAttribute:NSLinkAttributeName
					value:[self mailtoLinkForEmail:aCommit.authorEmail commit:aCommit]
				substring:@"<$author@email>"];
	
	[string replaceOccurrencesOfString:@"$commitId" 
							withString:aCommit.commitId];
	
	[string replaceOccurrencesOfString:@"$authorDate" 
							withString:[aCommit fullDateString]];
	
	[string replaceOccurrencesOfString:@"$Author Name" 
							withString:aCommit.authorName];
	
	[string replaceOccurrencesOfString:@"<$author@email>" 
							withString:aCommit.authorEmail];
	
	if ([aCommit.authorName isEqualToString:aCommit.committerName])
	{
		[string replaceOccurrencesOfString:@"\n	 	Committed by $Committer Name <$committer@email>"
								withString:@""];
	}
	else
	{
		[storage addAttribute:NSLinkAttributeName
						value:[self mailtoLinkForEmail:aCommit.committerEmail commit:aCommit]
					substring:@"<$committer@email>"];
		
		[string replaceOccurrencesOfString:@"$Committer Name" 
								withString:aCommit.committerName];
		
		[string replaceOccurrencesOfString:@"<$committer@email>" 
								withString:aCommit.committerEmail];      
	}
	
	NSArray* tags = [self.repositoryController.repository tagsForCommit:self.commit];
	
	if ([tags count] > 0)
	{
		if ([tags count] == 1)
		{
			[string replaceOccurrencesOfString:@"Tags:" 
									withString:@"Tag:"];
		}
		
		NSString* tagsString = [[[tags valueForKey:@"name"] sortedArrayUsingSelector:@selector(self)] componentsJoinedByString:@", "];
		[string replaceOccurrencesOfString:@"$tags" 
								withString:tagsString];
	}
	else
	{
		[string replaceOccurrencesOfString:@"\n	Tags: 	$tags"
								withString:@""];
	}
	
	if (self.commit.searchQuery)
	{
		NSMutableArray* stringsToHighlight = [NSMutableArray array];
		
		for (id key in [NSArray arrayWithObjects:@"commitId", @"authorName", @"authorEmail", @"committerName", @"committerEmail", nil])
		{
			NSArray* ranges = [self.commit.foundRangesByProperties objectForKey:key];
			if (ranges && [ranges isKindOfClass:[NSValue class]])
			{
				ranges = [NSArray arrayWithObject:ranges];
			}
			
			for (NSValue* val in ranges)
			{
				NSRange r = [val rangeValue];
				NSString* s = [self.commit valueForKey:key];
				if (s && r.location != NSNotFound && r.length > 0 && [s length] > 0)
				{
					// We don't check that range is within the string because we assume it was found in that string.
					NSString* substring = [s substringWithRange:r];
					if (substring)
					{
						[stringsToHighlight addObject:substring];
					}
				}
			} // each range
		} // each key
		
		NSColor* highlightColor = [GBStyle searchHighlightColor];
		for (NSString* str in stringsToHighlight)
		{
			[storage addAttribute:NSBackgroundColorAttributeName
							value:highlightColor
						substring:str];
			
		}
		
	} // if searchQuery
}

- (NSString*) mailtoLinkForEmail:(NSString*)email commit:(GBCommit*)aCommit
{
	return [NSString stringWithFormat:@"mailto:%@?subject=%@", 
			[email stringByAddingAllPercentEscapesUsingEncoding:NSUTF8StringEncoding],
			[[aCommit subjectForReply] stringByAddingAllPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

- (void) updateHeaderSize
{
	// First, adjust the width of the header text view depending on what image do we have.
	CGFloat widthOffsetForPicture = 12.0;
	if ([self.authorImage image])
	{
		widthOffsetForPicture = 88.0;
	}
	
	NSSize size = [[self.headerTextView enclosingScrollView] frame].size;
	size.width = [self.headerView frame].size.width - widthOffsetForPicture;
	[[self.headerTextView enclosingScrollView] setFrameSize:size];
	
	// Force layout
	[[self.headerTextView layoutManager] glyphRangeForTextContainer:[self.headerTextView textContainer]];
	[[self.messageTextView layoutManager] glyphRangeForTextContainer:[self.messageTextView textContainer]];
	
	NSRect headerTVRect  = [[self.headerTextView layoutManager] usedRectForTextContainer:[self.headerTextView textContainer]];
	NSRect messageTVRect = [[self.messageTextView layoutManager] usedRectForTextContainer:[self.messageTextView textContainer]];
	
	//  NSLog(@"COMMIT: headerTVRect = %@ (textContainer: %@)", NSStringFromRect(headerTVRect), NSStringFromSize([[self.headerTextView textContainer] containerSize]));
	//  NSLog(@"COMMIT: messageTVRect = %@ (textContainer: %@)", NSStringFromRect(messageTVRect), NSStringFromSize([[self.messageTextView textContainer] containerSize]));
	
	CGFloat headerTVHeight = ceil(headerTVRect.size.height);
	CGFloat messageTVHeight = ceil(messageTVRect.size.height);
	
	//  NSLog(@"COMMIT: headerTVHeight = %f [img: %f], messageTVHeight = %f", headerTVHeight, [self.authorImage frame].size.height, messageTVHeight);
	
	headerTVHeight += 0.0;
	messageTVHeight += 0.0;
	
	// From top to bottom:
	// 1. header top padding
	// 2. headerTextView height
	// 3. header bottom padding
	// 4. line NSBox height
	// 5. message top padding
	// 6. messageTextView height
	// 7. message bottom padding
	
	static CGFloat authorImagePadding = 10.0;
	static CGFloat headerTopPadding = 8.0;
	static CGFloat headerBottomPadding = 8.0;
	static CGFloat messageTopPadding = 8.0;
	static CGFloat messageBottomPadding = 8.0;
	
	headerTVHeight = MAX(headerTVHeight + 2*headerTopPadding, [self.authorImage frame].size.height + 2*authorImagePadding) - 2*headerTopPadding;
	
	CGFloat currentY = messageBottomPadding;
	
	{
		NSRect fr = [[self.messageTextView enclosingScrollView] frame];
		fr.size.height = messageTVHeight;
		fr.origin.y = currentY;
		[[self.messageTextView enclosingScrollView] setFrame:fr];
		
		//NSLog(@"COMMIT: messageTextView: %@", NSStringFromRect(fr));
		
		currentY += fr.size.height;
	}
	
	currentY += messageTopPadding;
	
	{
		NSRect fr = [self.horizontalLine frame];
		fr.origin.y = currentY;
		[self.horizontalLine setFrame:fr];
		
		//NSLog(@"COMMIT: horizontalLine: %@", NSStringFromRect(fr));
		currentY += fr.size.height;
	}
	
	currentY += headerBottomPadding;
    
	{
		NSRect fr = [[self.headerTextView enclosingScrollView] frame];
		fr.size.height = headerTVHeight;
		fr.origin.y = currentY;
		[[self.headerTextView enclosingScrollView] setFrame:fr];
		
		//NSLog(@"COMMIT: headerTextView: %@", NSStringFromRect(fr));
		
		currentY += fr.size.height;
	}
	
	currentY += headerTopPadding;
	
	{
		NSRect fr = [self.authorImage frame];
		fr.origin.y = currentY - authorImagePadding - fr.size.height;
		[self.authorImage setFrame:fr];
	}
	
	{
		NSRect fr = self.headerView.frame;
		fr.size.height = headerTopPadding + 
		[self.headerTextView frame].size.height + 
		headerBottomPadding +
		[self.horizontalLine frame].size.height +
		messageTopPadding + 
		[self.messageTextView frame].size.height + 
		messageBottomPadding;
		BOOL autoresizesSubviews = [self.headerView autoresizesSubviews];
		[self.headerView setAutoresizesSubviews:NO];
		[self.headerView setFrame:fr];
		[self.headerView setAutoresizesSubviews:autoresizesSubviews];
	}
	
	[self.tableView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:0]];
	
	[self.headerTextView scrollRangeToVisible:NSMakeRange(0, 1)];
	[[self.headerTextView enclosingScrollView] reflectScrolledClipView:[[self.headerTextView enclosingScrollView] contentView]];
	
	//  [self.messageTextView scrollRangeToVisible:NSMakeRange(0, 1)];
	//  [[self.messageTextView enclosingScrollView] reflectScrolledClipView:[[self.headerTextView enclosingScrollView] contentView]];
	//  
	//  [[self.messageTextView enclosingScrollView] setNeedsDisplay:YES];
	//  [self.messageTextView setNeedsDisplay:YES];
	
	[self performSelector:@selector(fixupRareGlitchWithTextView) withObject:nil afterDelay:0.0];
}

- (void) fixupRareGlitchWithTextView
{
	[self.messageTextView scrollRangeToVisible:NSMakeRange(0, 1)];
	[[self.messageTextView enclosingScrollView] reflectScrolledClipView:[[self.headerTextView enclosingScrollView] contentView]];
	[[self.messageTextView enclosingScrollView] setNeedsDisplay:YES];
	[self.messageTextView setNeedsDisplay:YES];
}




#pragma mark Actions


- (IBAction) stageExtractFile:_
{
	GBChange* change = [[[self selectedChanges] firstObject] nilIfBusy];
	if (!change || ![change validateExtractFile]) return;
	
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setNameFieldLabel:NSLocalizedString(@"Save As:", @"Commit")];
	[panel setNameFieldStringValue:[change defaultNameForExtractedFile]];
	[panel setPrompt:NSLocalizedString(@"Save", @"Commit")];
	[panel setDelegate:self];
	[[GBMainWindowController instance] sheetQueueAddBlock:^{
		[panel beginSheetModalForWindow:[[self view] window] completionHandler:^(NSInteger result){
			if (result == NSFileHandlingPanelOKButton)
			{
				[change extractFileWithTargetURL:[panel URL]];
				NSString* path = [[panel URL] path];
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 700000000), dispatch_get_main_queue(), ^{
					[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];  
				});
			}
			[[GBMainWindowController instance] sheetQueueEndBlock];
		}];
	}];
}

- (BOOL) validateStageExtractFile:_
{
	if ([[self selectedChanges] count] != 1) return NO;
	return [[[[self selectedChanges] firstObject] nilIfBusy] validateExtractFile];
}

- (void) doubleClickChange:(GBChange *)aChange
{
	static BOOL alreadyClicked = NO;
	if (alreadyClicked) return;
	alreadyClicked = YES;
	[aChange launchDiffWithBlock:^{
	}];
	
	// reset flag on the next cycle when all doubleClicks are processed.
	dispatch_async(dispatch_get_main_queue(), ^{
		alreadyClicked = NO;
	});
}




#pragma mark NSTextViewDelegate


- (BOOL)textView:(NSTextView *)aTextView clickedOnLink:(id)link atIndex:(NSUInteger)charIndex
{
	if ([link isKindOfClass:[NSURL class]])
	{
		NSURL* aURL = link;
		if ([[aURL host] isEqual:@"internal"])
		{
			NSString* path = [aURL path];
			if ([path rangeOfString:@"/commits/"].location == 0)
			{
				NSString* commitId = [[path pathComponents] lastObject];
				[self performSelector:@selector(selectCommitId:) withObject:commitId afterDelay:0.0];
				return YES;
			}
		}
	}
	
	return NO;
}


- (void) selectCommitId:(NSString*)aCommitId
{
	[self.repositoryController selectCommitId:aCommitId];
}





#pragma mark Resizing


- (void) tableViewDidResize:(id)notification
{
	if (![self.tableView inLiveResize]) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tableViewDidLiveResizeDelayed) object:nil];
	[self performSelector:@selector(tableViewDidLiveResizeDelayed) withObject:nil afterDelay:0.1];
}

- (void) tableViewDidLiveResizeDelayed
{
	[self updateHeaderSize];
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
	NSString* extension = [enteredName pathExtension];
	NSString* basename = [enteredName stringByDeletingPathExtension];
	
	if (aURL && enteredName && [enteredName length] > 0)
	{
		NSString* targetPath = [[aPanel directoryURL] path];
		NSUInteger counter = 0;
		while ([[NSFileManager defaultManager] fileExistsAtPath:[targetPath stringByAppendingPathComponent:uniqueName]])
		{
			counter++;
			if (extension && ![extension isEqualToString:@""] && basename && ![basename isEqualToString:@""])
			{
				uniqueName = [[basename stringByAppendingFormat:@"%lu", counter] stringByAppendingPathExtension:extension];
			}
			else
			{
				uniqueName = [enteredName stringByAppendingFormat:@"%lu", counter];
			}
		}
		[aPanel setNameFieldStringValue:uniqueName];
	}
}






#pragma mark Private



- (void) highlightURLsInAttributedString:(NSMutableAttributedString*)textStorage
{
	NSString* string = [textStorage string];
	NSRange searchRange = NSMakeRange(0, string.length);
	NSRange foundRange = NSMakeRange(NSNotFound, 0);
	[textStorage beginEditing];
	do
	{
		@try
		{
			if ([NSRegularExpression class])
			{
				NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:@"(\\w+://|www\\.)" options:0 error:NULL];
				if (regexp)
				{
					foundRange = [regexp rangeOfFirstMatchInString:string options:0 range:searchRange];
				}
			}
			else // Snow Leopard does not support regexps, try common schemes
			{
				NSRange wwwRange   = [string rangeOfString:@"www."     options:0 range:searchRange];
				NSRange httpsRange = [string rangeOfString:@"https://" options:0 range:searchRange];
				NSRange httpRange  = [string rangeOfString:@"http://"  options:0 range:searchRange];
				NSRange rdarRange  = [string rangeOfString:@"rdar://"  options:0 range:searchRange];
				NSRange ftpRange   = [string rangeOfString:@"ftp://"   options:0 range:searchRange];
				
				foundRange = wwwRange;
				
				if (httpsRange.location < foundRange.location) foundRange = httpsRange;
				if (httpRange.location < foundRange.location)  foundRange = httpRange;
				if (rdarRange.location < foundRange.location)  foundRange = rdarRange;
				if (ftpRange.location < foundRange.location)   foundRange = ftpRange;
			}
			
			if (foundRange.length > 0)
			{
				NSUInteger minLength = foundRange.length;
				
				// Restrict the searchRange so that it won't find the same string again
				searchRange.location = (foundRange.location+1);
				searchRange.length = string.length - searchRange.location;
				
				// We assume the URL ends with a whitespace (punctuation will be trimmed below)
				NSRange endOfURLRange = [string rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet] options:0 range:searchRange];
				
				// The URL could also end at the end of the text.  The next line fixes it in case it does
				if (endOfURLRange.location == NSNotFound)
				{
					endOfURLRange.location = string.length;
				}
				
				// Set foundRange's length to the length of the URL
				foundRange.length = endOfURLRange.location - foundRange.location;
				
				NSString* urlString = [string substringWithRange:foundRange];
				
				// Trim trailing punctuation.
				NSString* urlString2 = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
				
				if (foundRange.length > urlString2.length) // have trimmed something
				{
					// if the slash "/" was trimmed, put it back.
					if ([[urlString substringWithRange:NSMakeRange(urlString2.length, 1)] isEqualToString:@"/"])
					{
						urlString2 = [urlString2 stringByAppendingString:@"/"];
					}
				}
				urlString = urlString2;
				foundRange.length = urlString.length;
				
				if ([urlString rangeOfString:@"www"].location == 0) 
				{
					if ([urlString length] < [@"www.t.co" length]) // min domain name: www.t.co
					{
						urlString = nil;
					}
					else
					{
						urlString = [NSString stringWithFormat:@"http://%@", urlString];  
					}
				}
				
				if (urlString && urlString.length >= minLength)
				{
					// Grab the URL from the text
					NSURL* theURL = [NSURL URLWithString:urlString];
					
					if (theURL)
					{
						// Make the link attributes
						NSDictionary* linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
														theURL, NSLinkAttributeName,
														//[NSNumber numberWithInt:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
														nil];
						
						// Finally, apply those attributes to the URL in the text
						[textStorage addAttributes:linkAttributes range:foundRange];
					} // not url
				} // nil string
			} // is found range
		} // try
		@catch (NSException * e)
		{
			NSLog(@"ERROR: GBStageViewController: exception caught while highlighting URLs inside text view. %@", e);
			foundRange.length = 0;
			break;
		}    
	} while (foundRange.length != 0); //repeat the do block until it no longer finds anything
	[textStorage endEditing];
}



@end
