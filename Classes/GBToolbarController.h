@class GBRepositoryController;
@class GBMainWindowController;

@interface GBToolbarController : NSObject

@property(retain) GBBaseRepositoryController* baseRepositoryController;
@property(retain) GBRepositoryController* repositoryController;
@property(retain) IBOutlet NSToolbar* toolbar;
@property(retain) IBOutlet NSPopUpButton* currentBranchPopUpButton;
@property(retain) IBOutlet NSSegmentedControl* pullPushControl;
@property(retain) IBOutlet NSButton* pullButton;
@property(retain) IBOutlet NSPopUpButton* remoteBranchPopUpButton;
@property(retain) IBOutlet NSProgressIndicator* progressIndicator;
@property(retain) IBOutlet NSButton* commitButton;

@property(assign) IBOutlet NSWindow* window;
@property(assign) IBOutlet GBMainWindowController* mainWindowController;
@property(assign) CGFloat sidebarWidth;

- (void) windowDidLoad;
- (void) windowDidUnload;

- (void) update;
- (void) updateDisabledState;
- (void) updateSpinner;
- (void) updateBranchMenus;
- (void) updateCurrentBranchMenus;
- (void) updateRemoteBranchMenus;
- (void) updateSyncButtons;
- (void) updateCommitButton;
- (void) updateAlignment;

- (void) saveState;
- (void) loadState;

#pragma mark IBActions

- (IBAction) fetch:(id)_;
- (IBAction) pullOrPush:(NSSegmentedControl*)segmentedControl;
- (IBAction) pull:(id)sender;
- (IBAction) push:(id)sender;
- (BOOL) validateFetch:(id)sender;
- (BOOL) validatePull:(id)sender;
- (BOOL) validatePush:(id)sender;

- (IBAction) checkoutBranch:(NSMenuItem*)sender;
- (IBAction) checkoutRemoteBranch:(id)sender;
- (IBAction) checkoutNewBranch:(id)sender;
- (IBAction) selectRemoteBranch:(id)sender;
- (IBAction) createNewRemoteBranch:(id)sender;
- (IBAction) createNewRemote:(id)sender;


@end
