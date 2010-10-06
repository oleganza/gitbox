
#import "GBRepositoriesControllerDelegate.h"
#import "GBRepositoryControllerDelegate.h"

@class GBRepositoriesController;

@class GBToolbarController;
@class GBSourcesController;
@class GBHistoryViewController;
@class GBStageViewController;
@class GBCommitViewController;
@class GBWelcomeController;
@interface GBMainWindowController : NSWindowController<NSSplitViewDelegate,
                                                       GBRepositoriesControllerDelegate,
                                                       GBRepositoryControllerDelegate>

@property(retain) GBRepositoriesController* repositoriesController;

@property(retain) IBOutlet GBToolbarController* toolbarController;
@property(retain) GBSourcesController* sourcesController;
@property(retain) GBHistoryViewController* historyController;
@property(retain) GBStageViewController* stageController;
@property(retain) GBCommitViewController* commitController;
@property(retain) GBWelcomeController* welcomeController;

@property(retain) IBOutlet NSSplitView* splitView;

+ (id) controller;

- (void) saveState;
- (void) loadState;

- (IBAction) editRepositories:(id)_;
- (IBAction) editGitIgnore:(id)_;
- (IBAction) editGitConfig:(id)_;

- (IBAction) openInTerminal:(id)_;
- (IBAction) openInFinder:(id)_;
- (IBAction) selectPreviousRepository:(id)_;
- (IBAction) selectNextRepository:(id)_;

- (IBAction) showWelcomeWindow:(id)_;

@end
