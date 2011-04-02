#import "OABlockTable.h"
#import "OABlockOperations.h"

@interface OABlockTable ()
@property(nonatomic, retain) NSMutableDictionary* table;
@end

@implementation OABlockTable

@synthesize table;

- (id)init
{
  if ((self = [super init]))
  {
    self.table = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)dealloc
{
  self.table = nil;
  [super dealloc];
}

- (BOOL) containsBlockForName:(NSString*)aName
{
  return !![self.table objectForKey:aName];
}

- (void) addBlock:(void(^)())aBlock forName:(NSString*)aName
{
  if (!aBlock) aBlock = ^{}; // put an empty block to mark associated task as running
  [self.table setObject:OABlockConcat([self.table objectForKey:aName], aBlock) forKey:aName];
}

- (void) callBlockForName:(NSString*)aName
{
  void(^aBlock)() = [[self.table objectForKey:aName] retain];
  [self.table removeObjectForKey:aName]; // it is important to remove the block before it is called
  if (aBlock) aBlock();
  [aBlock release];
}

- (void) addBlock:(void(^)())aBlock forName:(NSString*)aName andProceedIfClear:(void(^)())continuation
{
  if ([self containsBlockForName:aName])
  {
    [self addBlock:aBlock forName:aName];
  }
  else
  {
    [self addBlock:aBlock forName:aName];
    if (continuation) continuation();
  }  
}

- (NSString*) description
{
  return [NSString stringWithFormat:@"<OABlockTable:%p names: %@>", [self.table allKeys]];
}


@end
