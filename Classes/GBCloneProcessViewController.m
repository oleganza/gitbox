#import "GBCloneProcessViewController.h"
#import "GBCloningRepositoryController.h"

@implementation GBCloneProcessViewController

@synthesize messageLabel;
@synthesize errorLabel;
@synthesize cancelButton;
@synthesize repositoryController;

- (void) dealloc
{
  self.messageLabel = nil;
  self.errorLabel = nil;
  self.cancelButton = nil;
  self.repositoryController = nil;
  [super dealloc];
}

- (void) update
{
  [self.messageLabel setStringValue:NSLocalizedString(@"  Clone in progress...", @"Clone")];
  [self.errorLabel setStringValue:@""];
  [self.cancelButton setTitle:NSLocalizedString(@"Cancel", @"")];
  
  if (self.repositoryController.error)
  {
    [self.messageLabel setStringValue:NSLocalizedString(@"Clone Error", @"Clone")];
    [self.errorLabel setStringValue:NSLocalizedString(@"Check the URL or the network connection. Gitbox needs key without passphrase for SSH connection. The host should be in known_hosts.", @"Clone")];
    [self.cancelButton setTitle:NSLocalizedString(@"Close", @"")];
  }
}

- (IBAction) cancel:_
{
  [self.repositoryController cancelCloning];
}

- (void) loadView
{
  [super loadView];
  [self update];
}


@end
