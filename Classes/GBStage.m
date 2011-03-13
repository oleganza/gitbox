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
  self.stagedChanges = nil;
  self.unstagedChanges = nil;
  self.untrackedChanges = nil;
  self.currentCommitMessage = nil;
  [super dealloc];
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

- (BOOL) isCommitable
{
  return [self.stagedChanges count] > 0;
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
            if (block) block();
            [self notifyWithSelector:@selector(commitDidUpdateChanges:)];
          }]; // untracked
        }]; // unstaged
        
      }];

    }]; // staged
  }]; // refresh-index
}



- (void) stageDeletedPaths:(NSArray*)pathsToDelete withBlock:(void(^)())block
{
  block = [[block copy] autorelease];
  
  if ([pathsToDelete count] <= 0)
  {
    if (block) block();
    return;
  }
  
  GBTask* task = [self.repository task];
  task.arguments = [[NSArray arrayWithObjects:@"update-index", @"--remove", nil] arrayByAddingObjectsFromArray:pathsToDelete];
  [self.repository launchTask:task withBlock:^{
    [task showErrorIfNeeded];
    if (block) block();
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
  
  GBTask* task = [self.repository task];
  task.arguments = [[NSArray arrayWithObjects:@"add", nil] arrayByAddingObjectsFromArray:pathsToAdd];
  [self.repository launchTask:task withBlock:^{
    [task showErrorIfNeeded];
    if (block) block();
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
      [pathsToDelete addObject:[aChange.srcURL path]];
    }
    else
    {
      [pathsToAdd addObject:[aChange.fileURL path]];
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
      [addedPaths addObject:aChange.fileURL.path];
    }
    else
    {
      [otherPaths addObject:aChange.fileURL.path];
    }
  }

  //
  // run two tasks: "git reset" and "git rm --cached"
  //       do not run if paths list is empty
  //       use a single common queue to make it easier to order the tasks
  //       "git rm --cached" is needed in case when HEAD does not yet exist
  [OABlockGroup groupBlock:^(OABlockGroup* blockGroup){
    
    if ([otherPaths count] > 0)
    {
      GBTask* resetTask = [self.repository task];
      resetTask.arguments = [[NSArray arrayWithObjects:@"reset", @"--", nil] arrayByAddingObjectsFromArray:otherPaths];
      [self.repository launchTask:resetTask withBlock:^{
        // Commented out because git spits out error code even if the unstage is successful.
        // [task showErrorIfNeeded];
      }];
    }
    
    if ([addedPaths count] > 0)
    {
      GBTask* rmTask = [self.repository task];
      rmTask.arguments = [[NSArray arrayWithObjects:@"rm", @"--cached", @"--force", nil] arrayByAddingObjectsFromArray:addedPaths];
      [self.repository launchTask:rmTask withBlock:^{
        // Commented out because git spits out error code even if the unstage is successful.
        // [task showErrorIfNeeded];
      }];    
    }
  } continuation: block];
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
    [paths addObject:aChange.fileURL.path];
  }
  GBTask* task = [self.repository task];
  task.arguments = [[NSArray arrayWithObjects:@"checkout", @"HEAD", @"--", nil] arrayByAddingObjectsFromArray:paths];
  [self.repository launchTask:task withBlock:^{
    if (block) block();
  }];
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
        [URLsToTrash addObject:[aChange fileURL]];
      }
      else
      {
        [pathsToGitRm addObject:[[aChange fileURL] path]];
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
    GBTask* task = [self.repository task];
    task.arguments = [[NSArray arrayWithObjects:@"rm", nil] arrayByAddingObjectsFromArray:pathsToGitRm];
    trashingBlock = [[trashingBlock copy] autorelease];
    [self.repository launchTask:task withBlock:^{
      trashingBlock();
    }];
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
    return NSLocalizedString(@"Working directory clean", @"Stage");
  }
  
  NSMutableArray* titles = [NSMutableArray array];
  
  if (modifications > 0)
  {
    if (modifications == 1)
    {
      [titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d modified file",@""), modifications]];
    }
    else
    {
      [titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d modified files",@""), modifications]];
    }

  }
  if (newFiles > 0)
  {
    if (newFiles == 1)
    {
      [titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d new file",@""), newFiles]];
    }
    else
    {
      [titles addObject:[NSString stringWithFormat:NSLocalizedString(@"%d new files",@""), newFiles]];
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
