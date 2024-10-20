#import "OATask.h"
#import "GBActivity.h"
#import "NSData+OADataHelpers.h"

@interface GBActivity ()
@property(nonatomic, strong) NSMutableData* data;
@end 

@implementation GBActivity

@synthesize isRunning;

@synthesize date;
@synthesize path;
@synthesize command;
@synthesize status;

@synthesize textOutput;
@synthesize data;
@synthesize dataLength;

#pragma mark Init


- (id) init
{
  if ((self = [super init]))
  {
    self.date = [NSDate date];
    self.data = [NSMutableData dataWithLength:0];
  }
  return self;
}

- (OATask*) task
{
	return (__bridge OATask*)_taskRef;
}

- (void) appendData:(NSData*)chunk
{
  if (!chunk) return;
  [self.data appendData:chunk];
  self.textOutput = [self.data UTF8String];
  NSUInteger l = [self.data length];
  self.dataLength = l ? [NSString stringWithFormat:@"%d", (int)l] : @"";
}

- (void) trimIfNeeded
{
  int trimLimit = 100*1024;
  if (self.data && [self.data length] > trimLimit)
  {
    NSUInteger skippedBytes = ([self.data length] - trimLimit);
    [self.data setData:[self.data subdataWithRange:NSMakeRange(0, 10000)]];
    
    NSData* noticeData = [[NSString stringWithFormat:@"\n\n[skipped %lu bytes]\n", skippedBytes] dataUsingEncoding:NSUTF8StringEncoding];
    [self.data appendData:noticeData];
    self.textOutput = [self.data UTF8String];
  }
}



#pragma mark Interrogation

- (NSString*) line
{
  return [NSString stringWithFormat:@"%@\t%@\t%@", self.path, self.command, self.status];
}

@end
