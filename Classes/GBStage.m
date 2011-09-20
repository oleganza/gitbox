#import "GBStage.h"
#import "GBChange.h"
#import "GBRepository.h"
#import "GBTask.h"
#import "GBRefreshIndexTask.h"
#import "GBStagedChangesTask.h"
#import "GBAllStagedFilesTask.h"
#import "GBUnstagedChangesTask.h"
#import "GBUntrackedChangesTask.h"
#import "OABlockGroup.h"
#import "NSData+OADataHelpers.h"
#import "NSArray+OAArrayHelpers.h"
#import "NSObject+OASelectorNotifications.h"

@implementation GBStage

@synthesize stagedChanges;
@synthesize unstagedChanges;
@synthesize untrackedChanges;
@synthesize currentCommitMessage;

@synthesize hasStagedChanges;

#pragma mark Init

- (void) dealloc
{
	[stagedChanges release]; stagedChanges = nil;
	[unstagedChanges release]; unstagedChanges = nil;
	[untrackedChanges release]; untrackedChanges = nil;
	[currentCommitMessage release]; currentCommitMessage = nil;
	[super dealloc];
}

- (NSString*) description
{
	return [NSString stringWithFormat:@"<GBStage:%p %@ (%d staged, %d not staged, %d untracked)>", self, self.repository.url, (int)[self.stagedChanges count], (int)[self.unstagedChanges count], (int)[self.untrackedChanges count]];
}


#pragma mark Interrogation


- (NSArray*) sortedChanges
{
	NSMutableArray* allChanges = [NSMutableArray array];
	
	[allChanges addObjectsFromArray:self.stagedChanges];
	[allChanges addObjectsFromArray:self.unstagedChanges];
	[allChanges addObjectsFromArray:self.untrackedChanges];
	
	[allChanges sortUsingSelector:@selector(compareByPath:)];
	
	return allChanges;
}

- (BOOL) isDirty
{
	return ([self.stagedChanges count] + [self.unstagedChanges count]) > 0;
}

- (BOOL) isStashable
{
	return ([self.stagedChanges count] + [self.unstagedChanges count]) > 0;
}

- (BOOL) isCommitable
{
	return [self.stagedChanges count] > 0;
}

// Returns a good default human-readable message like "somefile.c, other.txt, Makefile and 5 others"
- (NSString*) defaultStashMessage
{
	// Displaying only file names, skipping duplicates.
	
	NSArray* stashableChanges = [(self.stagedChanges ? self.stagedChanges : [NSArray array]) arrayByAddingObjectsFromArray:(self.unstagedChanges ? self.unstagedChanges : [NSArray array])];
	
	int totalChanges = [stashableChanges count];
	
	NSMutableSet* uniqueNames = [NSMutableSet set]; // also would produce some sort of randomness to avoid displaying same top files.
	
	for (GBChange* change in stashableChanges)
	{
		NSString* name = [[[change fileURL] absoluteString] lastPathComponent];
		[uniqueNames addObject:name];
	}
	
	NSArray* list = [uniqueNames allObjects];
	
	if ([list count] < 1) return NSLocalizedString(@"No changes", @"GBStage");
	
	if ([list count] <= 4)
	{
		// Simply list all files
		list = [list sortedArrayUsingSelector:@selector(self)];
		return [list componentsJoinedByString:@", "];
	}
	
	// Show first N files and then count of the rest (which will be > 1)
	int visibleFiles = 2;
	
	return [NSString stringWithFormat:NSLocalizedString(@"%@ and %d more files", @"GBStage"), 
			[[[list subarrayWithRange:NSMakeRange(0, visibleFiles)] sortedArrayUsingSelector:@selector(self)] componentsJoinedByString:@", "],
			totalChanges - visibleFiles];
}




#pragma mark Actions


- (void) update
{
	self.hasStagedChanges = (self.stagedChanges && [self.stagedChanges count] > 0);
	self.changes = [self sortedChanges];
	[self notifyWithSelector:@selector(commitDidUpdateChanges:)];
}

- (void) loadChangesIfNeededWithBlock:(void(^)())block
{
	if (self.changes) // for stage it's enough to have non-nil array, even empty.
	{
		if (block) block();
		return;
	}
	
	[super loadChangesIfNeededWithBlock:block];
}


- (void) loadChangesWithBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	
	GBTask* refreshIndexTask = [GBRefreshIndexTask taskWithRepository:self.repository];
	[self.repository launchTask:refreshIndexTask withBlock:^{
		
		GBStagedChangesTask* stagedChangesTask = [GBStagedChangesTask taskWithRepository:self.repository];
		[self.repository launchTask:stagedChangesTask withBlock:^{
			
			[OABlockGroup groupBlock:^(OABlockGroup* blockGroup){
				
				if ([stagedChangesTask terminationStatus] == 0)
				{
					self.stagedChanges = stagedChangesTask.changes;
					//[self update];
				}
				else
				{
					// diff-tree failed: we don't have a HEAD commit, try another task
					GBAllStagedFilesTask* stagedChangesTask2 = [GBAllStagedFilesTask taskWithRepository:self.repository];
					[blockGroup enter];
					[self.repository launchTask:stagedChangesTask2 withBlock:^{
						self.stagedChanges = stagedChangesTask2.changes;
						//[self update];
						[blockGroup leave];
					}];
				}
				
			} continuation: ^{
				
				GBUnstagedChangesTask* unstagedChangesTask = [GBUnstagedChangesTask taskWithRepository:self.repository];
				[self.repository launchTask:unstagedChangesTask withBlock:^{
					self.unstagedChanges = unstagedChangesTask.changes;
					//[self update];
					
					GBUntrackedChangesTask* untrackedChangesTask = [GBUntrackedChangesTask taskWithRepository:self.repository];
					[self.repository launchTask:untrackedChangesTask withBlock:^{
						self.untrackedChanges = untrackedChangesTask.changes;
						[self update];
                        
						/*
						 // TODO: parse changes as GBSubmoduleStatusChange (subclass of GBChange)
						 [self.repository updateSubmodulesWithBlock:^{
						 // TODO: remove GBChanges for submodule previously added by ls-files (GBAllStagedFilesTask) or other task.
						 // TODO: add GBChanges for submodules if needed (add later)
						 [self update];
						 if (block) block();
						 }];
						 */
						// remove this line when updateSubmodulesWithBlock is uncommented.
						
						[self.repository updateConflictState];
						
						if (block) block();
						[self notifyWithSelector:@selector(commitDidUpdateChanges:)];
					}]; // untracked
				}]; // unstaged
				
			}];
			
		}]; // staged
	}]; // refresh-index
}

// helper method to process more than 4096 files in chunks
- (void) launchTaskByChunksWithArguments:(NSArray*)args paths:(NSArray*)allPaths block:(void(^)())block taskCallback:(void(^)(GBTask*))taskCallback
{
	taskCallback = [[taskCallback copy] autorelease];
	[OABlockGroup groupBlock:^(OABlockGroup *group) {
		for (NSArray* paths in [allPaths arrayOfChunksBySize:1000])
		{
			[group enter];
			GBTask* task = [self.repository task];
			task.arguments = [args arrayByAddingObjectsFromArray:paths];
			[self.repository launchTask:task withBlock:^{
				if (taskCallback) taskCallback(task);
				[group leave];
			}];
		}
	} continuation:block];
}

- (void) stageDeletedPaths:(NSArray*)pathsToDelete withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	
	if ([pathsToDelete count] <= 0)
	{
		if (block) block();
		return;
	}
	
	[self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"update-index", @"--remove", nil]
									paths:pathsToDelete
									block:block
							 taskCallback:^(GBTask *task) {
								 [task showErrorIfNeeded];
							 }];
}

- (void) stageAddedPaths:(NSArray*)pathsToAdd withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	
	if ([pathsToAdd count] <= 0)
	{
		if (block) block();
		return;
	}
	
	[self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"add", @"--force", nil]
									paths:pathsToAdd
									block:block
							 taskCallback:^(GBTask *task) {
								 [task showErrorIfNeeded];
							 }];
}

- (void) stageChanges:(NSArray*)theChanges withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	
	NSMutableArray* pathsToDelete = [NSMutableArray array];
	NSMutableArray* pathsToAdd = [NSMutableArray array];
	for (GBChange* aChange in theChanges)
	{
		[aChange setStagedSilently:YES];
		if ([aChange isDeletedFile])
		{
			[pathsToDelete addObject:aChange.srcURL.relativePath];
		}
		else
		{
			[pathsToAdd addObject:aChange.fileURL.relativePath];
		}
	}
	
	[self stageDeletedPaths:pathsToDelete withBlock:^{
		[self stageAddedPaths:pathsToAdd withBlock:block];
	}];
}

- (void) unstageChanges:(NSArray*)theChanges withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	if ([theChanges count] <= 0)
	{
		if (block) block();
		return;
	}
	NSMutableArray* addedPaths = [NSMutableArray array];
	NSMutableArray* otherPaths = [NSMutableArray array];
	for (GBChange* aChange in theChanges)
	{
		[aChange setStagedSilently:NO];
		if ([aChange isAddedFile])
		{
			[addedPaths addObject:aChange.fileURL.relativePath];
		}
		else
		{
			[otherPaths addObject:aChange.fileURL.relativePath];
		}
	}
	
	//
	// run two tasks: "git reset" and "git rm --cached"
	//       do not run if paths list is empty
	//       use a single common queue to make it easier to order the tasks
	//       "git rm --cached" is needed in case when HEAD does not yet exist
	
	// [task showErrorIfNeeded] is not used because git spits out error code even if the unstage is successful.
	
	[self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"reset", @"--", nil]
									paths:otherPaths
									block:
	 ^{
		 [self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"rm", @"--cached", @"--force", nil]
										 paths:addedPaths
										 block:block 
								  taskCallback:nil];
	 } taskCallback:nil];
}

- (void) stageAllWithBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	GBTask* task = [self.repository task];
	task.arguments = [NSArray arrayWithObjects:@"add", @".", nil];
	[self.repository launchTask:task withBlock:^{
		[task showErrorIfNeeded];
		if (block) block();
	}];
}

- (void) revertChanges:(NSArray*)theChanges withBlock:(void(^)())block
{
	if ([theChanges count] <= 0)
	{
		if (block) block();
		return;
	}
	
	block = [[block copy] autorelease];
	NSMutableArray* paths = [NSMutableArray array];
	for (GBChange* aChange in theChanges)
	{
		[aChange setStagedSilently:NO];
		[paths addObject:aChange.fileURL.relativePath];
	}
	
	[self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"checkout", @"HEAD", @"--", nil]
									paths:paths
									block:block
							 taskCallback:nil];
}

- (void) deleteFilesInChanges:(NSArray*)theChanges withBlock:(void(^)())block
{
	block = [[block copy] autorelease];
	
	NSMutableArray* URLsToTrash = [NSMutableArray array];
	NSMutableArray* pathsToGitRm = [NSMutableArray array];
	
	for (GBChange* aChange in theChanges)
	{
		if (!aChange.staged && [aChange fileURL])
		{
			if ([aChange isUntrackedFile])
			{
				[URLsToTrash addObject:aChange.fileURL];
			}
			else
			{
				[pathsToGitRm addObject:aChange.fileURL.relativePath];
			}
		}
	}
	
	// move to trash
	
	void (^trashingBlock)() = ^{
		if ([URLsToTrash count] > 0)
		{
			[[NSWorkspace sharedWorkspace] recycleURLs:URLsToTrash 
									 completionHandler:^(NSDictionary *newURLs, NSError *error){
										 if (block) block();
									 }];    
		}
		else
		{
			if (block) block();
		}
	};
	
	if ([pathsToGitRm count] > 0)
	{
		[self launchTaskByChunksWithArguments:[NSArray arrayWithObjects:@"rm", @"--force", nil]
										paths:pathsToGitRm
										block:trashingBlock
								 taskCallback:nil];
	}
	else
	{
		trashingBlock();
	}
}






#pragma mark GBCommit overrides


- (BOOL) isStage
{
	return YES;
}

- (GBStage*) asStage
{
	return self;
}

- (NSString*) message
{
	NSUInteger modifications = [self.stagedChanges count] + [self.unstagedChanges count];
	NSUInteger newFiles = [self.untrackedChanges count];
	
	if (modifications + newFiles <= 0)
	{
		return NSLocalizedString(@"Working directory clean", @"GBStage");
	}
	
	NSMutableArray* titles = [NSMutableArray array];
	
	if (modifications > 0)
	{
		if (modifications == 1)
		{
			[titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d modified file",@"GBStage"), modifications]];
		}
		else
		{
			[titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d modified files",@"GBStage"), modifications]];
		}
		
	}
	if (newFiles > 0)
	{
		if (newFiles == 1)
		{
			[titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d new file",@"GBStage"), newFiles]];
		}
		else
		{
			[titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d new files",@"GBStage"), newFiles]];
		}
	}  
	
	return [titles componentsJoinedByString:@", "];
}

- (NSUInteger) totalPendingChanges
{
	NSUInteger modifications = [self.stagedChanges count] + [self.unstagedChanges count];
	NSUInteger newFiles = [self.untrackedChanges count];
	return modifications + newFiles;
}

@end
