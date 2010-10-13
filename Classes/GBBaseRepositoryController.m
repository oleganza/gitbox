#import "GBBaseRepositoryController.h"
#import "NSString+OAStringHelpers.h"

@implementation GBBaseRepositoryController

@synthesize displaysTwoPathComponents;

- (NSURL*) url
{
  // overriden in subclasses
  return nil;
}

- (NSString*) nameForSourceList
{
  if (self.displaysTwoPathComponents)
  {
    return [self longNameForSourceList];
  }
  else
  {
    return [self shortNameForSourceList];
  }
}

- (NSString*) shortNameForSourceList
{
  return [[[self url] path] lastPathComponent];
}

- (NSString*) longNameForSourceList
{
  return [[[self url] path] twoLastPathComponentsWithSlash];
}

- (NSString*) parentFolderName
{
  return [[[[self url] path] stringByDeletingLastPathComponent] lastPathComponent];
}

- (void) setNeedsUpdateEverything {}
- (void) updateRepositoryIfNeeded {}

- (void) beginBackgroundUpdate {}
- (void) endBackgroundUpdate {}

- (void) start {}
- (void) stop {}

@end
