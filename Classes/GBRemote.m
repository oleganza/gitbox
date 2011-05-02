#import "GBRemote.h"
#import "GBRepository.h"
#import "GBRef.h"
#import "GBRemoteRefsTask.h"
#import "GBAskPassController.h"

#import "NSFileManager+OAFileManagerHelpers.h"
#import "NSArray+OAArrayHelpers.h"


@interface GBRemote ()
@property(nonatomic,assign) BOOL isUpdatingRemoteBranches;
- (BOOL) doesNeedFetchNewBranches:(NSArray*)theBranches andTags:(NSArray*)theTags;
@end

@implementation GBRemote

@synthesize alias;
@synthesize URLString;
@synthesize fetchRefspec;
@synthesize branches;
@synthesize newBranches;

@synthesize repository;
@synthesize isUpdatingRemoteBranches;
@synthesize needsFetch;

- (void) dealloc
{
  self.alias = nil;
  self.URLString = nil;
  self.fetchRefspec = nil;
  self.branches = nil;
  self.newBranches = nil;
  [super dealloc];
}


#pragma mark Init


- (NSArray*) branches
{
  if (!branches) self.branches = [NSArray array];
  return [[branches retain] autorelease];
}

- (NSArray*) newBranches
{
  if (!newBranches) self.newBranches = [NSArray array];
  return [[newBranches retain] autorelease];
}





#pragma mark Interrogation


- (GBRef*) defaultBranch
{
  for (GBRef* ref in self.branches)
  {
    if ([ref.name isEqualToString:@"master"]) return ref;
  }
  return [self.branches firstObject];
}

- (NSArray*) pushedAndNewBranches
{
  return [self.branches arrayByAddingObjectsFromArray:self.newBranches];
}

- (void) updateNewBranches
{
  NSArray* names = [self.branches valueForKey:@"name"];
  NSMutableArray* updatedNewBranches = [NSMutableArray array];
  for (GBRef* aBranch in self.newBranches)
  {
    if (aBranch.name && ![names containsObject:aBranch.name])
    {
      [updatedNewBranches addObject:aBranch];
    }
  }
  self.newBranches = updatedNewBranches;
}

- (void) updateBranches
{
  [self updateNewBranches];
  for (GBRef* branch in [self pushedAndNewBranches])
  {
    branch.remote = self;
  }
}

- (BOOL) copyInterestingDataFromRemoteIfApplicable:(GBRemote*)otherRemote
{
  if (self.alias && [otherRemote.alias isEqualToString:self.alias])
  {
    self.newBranches = otherRemote.newBranches;
    [self updateBranches];
    return YES;
  }
  return NO;
}

- (BOOL) isConfiguredToFetchToTheDefaultLocation
{
  if (!self.fetchRefspec) return NO;
  return [self.fetchRefspec rangeOfString:[NSString stringWithFormat:@"refs/heads/*:refs/remotes/%@/*", self.alias]].length > 0;
}

- (NSString*) defaultFetchRefspec
{
  return [NSString stringWithFormat:@"+refs/heads/*:refs/remotes/%@/*", self.alias];
}




#pragma mark Actions


- (void) addNewBranch:(GBRef*)branch
{
  self.newBranches = [self.newBranches arrayByAddingObject:branch];
}

- (void) updateBranchesWithBlock:(void(^)())block
{
	[self updateBranchesSilently:NO withBlock:block];
}

- (void) updateBranchesSilently:(BOOL)silently withBlock:(void(^)())block
{
  block = [[block copy] autorelease];
  
  if (self.isUpdatingRemoteBranches)
  {
    if (block) block();
    return;
  }
  
  self.isUpdatingRemoteBranches = YES;
  [GBAskPassController launchedControllerWithAddress:self.URLString silent:silently taskFactory:^{
    GBRemoteRefsTask* aTask = [GBRemoteRefsTask task];
    aTask.repository = self.repository;
    aTask.remote = self;
    aTask.didTerminateBlock = ^{
      self.isUpdatingRemoteBranches = NO;
      if (![aTask isError])
      {
        // Do not update branches and tags, but simply tell the caller that it needs to fetch tags and branches for real.
        self.needsFetch = [self doesNeedFetchNewBranches:aTask.branches andTags:aTask.tags];
        
        if (block) block();
        
        self.needsFetch = NO; // reset the status after the callback
      }
      else
      {
        if (block) block();
      }
    };
    return aTask;
  }];
}

- (BOOL) doesNeedFetchNewBranches:(NSArray*)theBranches andTags:(NSArray*)theTags
{
  // Set needsFetch = YES if one of the following is true:
  // 1. There's a new branch
  // 2. The branch exists, but commitId differ
  // 3. The tag does not exists
  
  // This code is not optimal, but if you don't have thousands of branches, this should be enough.
	
  for (GBRef* updatedRef in theBranches)
  {
    BOOL foundAnExistingBranch = NO;
    for (GBRef* existingRef in self.branches)
    {
      if (updatedRef.name && existingRef.name && [updatedRef.name isEqualTo:existingRef.name])
      {
        foundAnExistingBranch = YES;
        if (![updatedRef.commitId isEqualTo:existingRef.commitId])
        {
          //NSLog(@"NEEDS FETCH? refs are different: %@ -> %@ [%@]", existingRef, updatedRef, self.alias);
          return YES;
        }
      }
    }
    if (!foundAnExistingBranch)
    {
      //NSLog(@"NEEDS FETCH? did not find an existing ref for %@ [%@]", updatedRef, self.alias);
      return YES;
    }
  }
  
  NSMutableArray* newTagNames = [[[theTags valueForKey:@"name"] mutableCopy] autorelease];
  [newTagNames removeObjectsInArray:[self.repository.tags valueForKey:@"name"]];
  
  if ([newTagNames count] > 0)
  {
    //NSLog(@"NEEDS FETCH? new tag names found: %@ [%@]", [newTagNames componentsJoinedByString:@", "], self.alias);
    return YES;
  }
  
  return NO;
}


@end
