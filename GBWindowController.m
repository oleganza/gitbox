#import "GBWindowController.h"
#import "GBRepository.h"
#import "GBRef.h"

@implementation GBWindowController

@synthesize repository;
@synthesize delegate;

@synthesize currentBranchPopUpButton;
@synthesize currentBranchCheckoutRemoteBranchMenuItem;
@synthesize currentBranchCheckoutTagMenuItem;

- (void) dealloc
{
  self.currentBranchPopUpButton = nil;
  self.currentBranchCheckoutRemoteBranchMenuItem = nil;
  self.currentBranchCheckoutTagMenuItem = nil;
  
  [super dealloc];
}


- (void) updateCurrentBranchMenus
{
  // Local branches
  
  GBRef* currentBranch = self.repository.currentRef;
  NSPopUpButton* button = self.currentBranchPopUpButton;
  [button removeAllItems];
  for (GBRef* localBranch in self.repository.localBranches)
  {
    [button addItemWithTitle:[localBranch name]];
    NSMenuItem* item = [button lastItem];
    [item setAction:@selector(checkoutBranch:)];
    [item setTarget:self];
    [item setRepresentedObject:localBranch];
    if ([localBranch isEqual:currentBranch])
    {
      [button selectItem:item];
    }
  }
  
  [button.menu addItem:[NSMenuItem separatorItem]];
  
  
  // Tags

  NSMenu* tagsMenu = [self.currentBranchCheckoutTagMenuItem menu];
  [tagsMenu removeAllItems];
  for (GBRef* tag in self.repository.tags)
  {
    NSMenuItem* item = [[NSMenuItem new] autorelease];
    [item setAction:@selector(checkoutBranch:)];
    [item setTarget:self];
    [item setRepresentedObject:tag];    
    [tagsMenu addItem:item];
  }
  if ([[tagsMenu itemArray] count] > 0)
  {
    [button.menu addItem:self.currentBranchCheckoutTagMenuItem];
  }
  
  
  // Remote branches
  
  NSMenu* remoteBranchesMenu = [self.currentBranchCheckoutRemoteBranchMenuItem menu];
  [remoteBranchesMenu removeAllItems];
  for (GBRef* remoteBranch in self.repository.remoteBranches)
  {
    NSMenuItem* item = [[NSMenuItem new] autorelease];
    [item setAction:@selector(checkoutRemoteBranch:)];
    [item setTarget:self];
    [item setRepresentedObject:remoteBranch];
    [remoteBranchesMenu addItem:item];
  }
  if ([[remoteBranchesMenu itemArray] count] > 0)
  {
    [button.menu addItem:self.currentBranchCheckoutRemoteBranchMenuItem];
  }
  
  
  // If no branch is found the name could be empty.
  // I make sure that the name is set nevertheless.
  [button setTitle:[currentBranch displayName]];  
}

- (void) updateCurrentBranchLabel
{
  // if [self.repository isTagCheckout]
  // if [self.repository isBranchCheckout]
  // if [self.repository isCommitCheckout]
}




#pragma mark Actions


- (IBAction) checkoutBranch:(NSMenuItem*)sender
{
  [self.repository checkoutRef:[sender representedObject]];
  [self updateCurrentBranchMenus];
  [self updateCurrentBranchLabel];
}

- (IBAction) checkoutRemoteBranch:(id)sender
{
  NSLog(@"TODO: create a default name taking in account exiting branch names; show modal prompt and confirm");
  [self updateCurrentBranchLabel];
}




#pragma mark NSWindowController

- (void)windowDidLoad
{
  [self.window setTitleWithRepresentedFilename:self.repository.path];
  [self updateCurrentBranchMenus];
}



#pragma mark NSWindowDelegate


- (void)windowWillClose:(NSNotification *)notification
{
  if ([[NSWindowController class] instancesRespondToSelector:@selector(windowWillClose:)]) 
  {
    [(id<NSWindowDelegate>)super windowWillClose:notification];
  }
  [self.delegate windowControllerWillClose:self];
}

@end
