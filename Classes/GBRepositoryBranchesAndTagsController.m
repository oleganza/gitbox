#import "GBRepository.h"
#import "GBRemote.h"
#import "GBRepositoryBranchesAndTagsController.h"

@interface GBRepositoryBranchesAndTagsController ()

@property(nonatomic, retain) NSMutableArray* branchesToDelete;
@property(nonatomic, retain) NSMutableArray* tagsToDelete;
@property(nonatomic, retain) NSMutableArray* remoteBranchesToDelete;

@end

@implementation GBRepositoryBranchesAndTagsController

@synthesize branchesBinding;
@synthesize tagsBinding;
@synthesize remoteBranchesBinding;

@synthesize branchesController;
@synthesize tagsController;
@synthesize remoteBranchesController;

@synthesize deleteBranchButton;
@synthesize deleteTagButton;
@synthesize deleteRemoteBranchButton;

@synthesize branchesToDelete;
@synthesize tagsToDelete;
@synthesize remoteBranchesToDelete;

- (void) dealloc
{
	[branchesBinding release];       branchesBinding = nil;
	[tagsBinding release];           tagsBinding = nil;
	[remoteBranchesBinding release]; remoteBranchesBinding = nil;
	
	[branchesController release];       branchesController = nil;
	[tagsController release];           tagsController = nil;
	[remoteBranchesController release]; remoteBranchesController = nil;
	
	[deleteBranchButton release];       deleteBranchButton = nil;
	[deleteTagButton release];          deleteTagButton = nil;
	[deleteRemoteBranchButton release]; deleteRemoteBranchButton = nil;
	
	[branchesToDelete release];       branchesToDelete = nil;
	[tagsToDelete release];           tagsToDelete = nil;
	[remoteBranchesToDelete release]; remoteBranchesToDelete = nil;
	
	[super dealloc];
}

- (id) initWithRepository:(GBRepository*)repo
{
	if ((self = [super initWithRepository:repo]))
	{
		self.branchesBinding       = [NSMutableArray array];
		self.tagsBinding           = [NSMutableArray array];
		self.remoteBranchesBinding = [NSMutableArray array];
		
		self.branchesToDelete       = [NSMutableArray array];
		self.tagsToDelete           = [NSMutableArray array];
		self.remoteBranchesToDelete = [NSMutableArray array];
	}
	return self;
}

- (NSString*) title
{
	return NSLocalizedString(@"Branches and Tags", @"");
}

- (void) updateButtonTitles
{
	if ([[self.branchesController selectedObjects] count] < 2)
	{
		[self.deleteBranchButton setTitle:NSLocalizedString(@"Delete Branch", @"GBSettings")];
	}
	else
	{
		[self.deleteBranchButton setTitle:NSLocalizedString(@"Delete Branches", @"GBSettings")];
	}
	
	if ([[self.tagsController selectedObjects] count] < 2)
	{
		[self.deleteTagButton setTitle:NSLocalizedString(@"Delete Tag", @"GBSettings")];
	}
	else
	{
		[self.deleteTagButton setTitle:NSLocalizedString(@"Delete Tags", @"GBSettings")];
	}
	
	if ([[self.remoteBranchesController selectedObjects] count] < 2)
	{
		[self.deleteRemoteBranchButton setTitle:NSLocalizedString(@"Delete Branch", @"GBSettings")];
	}
	else
	{
		[self.deleteRemoteBranchButton setTitle:NSLocalizedString(@"Delete Branches", @"GBSettings")];
	}
}

- (void) cancel
{
	self.branchesToDelete       = [NSMutableArray array];
	self.tagsToDelete           = [NSMutableArray array];
	self.remoteBranchesToDelete = [NSMutableArray array];
}

- (void) save
{
	[self.repository removeRemoteRefs:[self.remoteBranchesToDelete arrayByAddingObjectsFromArray:self.tagsToDelete] withBlock:^{
		[self.repository removeRefs:[self.branchesToDelete arrayByAddingObjectsFromArray:self.tagsToDelete] withBlock:^{
			self.branchesToDelete       = [NSMutableArray array];
			self.tagsToDelete           = [NSMutableArray array];
			self.remoteBranchesToDelete = [NSMutableArray array];
		}];
	}];
}

- (void) viewDidLoad
{
	[super viewDidLoad];
	
	self.branchesBinding = [[self.repository.localBranches mutableCopy] autorelease];
	self.tagsBinding = [[self.repository.tags mutableCopy] autorelease];
	
	NSMutableArray* rs = [NSMutableArray array];
	for (GBRemote* remote in self.repository.remotes)
	{
		[rs addObjectsFromArray:remote.branches];
	}
	
	self.remoteBranchesBinding = rs;
	
	[self updateButtonTitles];
}

- (IBAction) deleteBranch:(id)sender
{
	self.dirty = YES;
	[self.branchesToDelete addObjectsFromArray:[self.branchesController selectedObjects]];
	[self.branchesController remove:sender];
}

- (IBAction) deleteTag:(id)sender
{
	self.dirty = YES;
	[self.tagsToDelete addObjectsFromArray:[self.tagsController selectedObjects]];
	[self.tagsController remove:sender];
}

- (IBAction) deleteRemoteBranch:(id)sender
{
	self.dirty = YES;
	[self.remoteBranchesToDelete addObjectsFromArray:[self.remoteBranchesController selectedObjects]];
	[self.remoteBranchesController remove:sender];
}




#pragma mark NSTableViewDelegate


- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[self updateButtonTitles];
}


@end
