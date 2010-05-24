#import "GBRemoteBranchesTask.h"
#import "GBRemote.h"

@implementation GBRemoteBranchesTask

@synthesize remote;

- (void) dealloc
{
  self.remote = nil;
  [super dealloc];
}

- (NSArray*) arguments
{
  return [NSArray arrayWithObjects:@"ls-remote", @"--tags", @"--heads", self.remote.alias, nil];
}

- (void) didFinish
{
  [super didFinish];
  NSLog(@"TODO: parse branches, create a list");
  [self.remote asyncTaskGotBranches:[NSArray array]];
}

@end
