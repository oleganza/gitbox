#import "GBCloneProcessViewController.h"

@implementation GBCloneProcessViewController

@synthesize messageLabel;
@synthesize errorLabel;

- (void) dealloc
{
  self.messageLabel = nil;
  self.errorLabel = nil;
  [super dealloc];
}

- (void) update
{
  // TODO: check for repository controller status
  [self.messageLabel setStringValue:NSLocalizedString(@"  Clone in progress...", @"Clone")];
  [self.errorLabel setStringValue:@""];
}

- (IBAction) cancel:_
{
  // TODO: tell repository controller to stop cloning
}

- (void) loadView
{
  [super loadView];
  [self update];
}


@end
