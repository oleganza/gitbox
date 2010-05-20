#import "GBModels.h"

#import "NSFileManager+OAFileManagerHelpers.h"
#import "NSArray+OAArrayHelpers.h"

@implementation GBRemote

@synthesize alias;
@synthesize URLString;
@synthesize branches;

@synthesize repository;



#pragma mark Init


- (NSArray*) branches
{
  if (!branches)
  {
    NSMutableArray* list = [NSMutableArray array];
    NSURL* aurl = [self.repository gitURLWithSuffix:[@"refs/remotes" stringByAppendingPathComponent:self.alias]];
    for (NSURL* aURL in [NSFileManager contentsOfDirectoryAtURL:aurl])
    {
      if ([[NSFileManager defaultManager] isReadableFileAtPath:aURL.path])
      {
        NSString* name = [[aURL pathComponents] lastObject];
        if (![name isEqualToString:@"HEAD"])
        {
          GBRef* ref = [[GBRef new] autorelease];
          ref.repository = self.repository;
          ref.name = name;
          ref.remoteAlias = self.alias;
          [list addObject:ref];
        }
      }
    }
    self.branches = list;
  }
  return [[branches retain] autorelease];
}

- (void) dealloc
{
  self.alias = nil;
  self.URLString = nil;
  self.branches = nil;
  [super dealloc];
}


#pragma mark Info


- (GBRef*) defaultBranch
{
  for (GBRef* ref in self.branches)
  {
    if ([ref.name isEqualToString:@"master"]) return ref;
  }
  return [self.branches firstObject];
}



#pragma mark Actions


- (void) addBranch:(GBRef*)branch
{
  self.branches = [self.branches arrayByAddingObject:branch];
}


@end
