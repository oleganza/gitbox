
@class GBRepositoriesController;
@class GBBaseRepositoryController;
@class GBRepositoryController;
@class GBRepository;
@class GBHistoryViewController;

@interface GBSourcesController : NSViewController<NSOutlineViewDataSource,
                                                  NSOutlineViewDelegate>
{
  NSUInteger ignoreSelectionChange;
}

@property(nonatomic,retain) GBRepositoriesController* repositoriesController;

@property(nonatomic,retain) NSMutableArray* sections;
@property(nonatomic,retain) IBOutlet NSOutlineView* outlineView;
@property(nonatomic,retain) IBOutlet NSButton* buyButton;

- (void) saveState;
- (void) loadState;

- (void) update;
- (void) updateBadges;
- (void) updateSelectedRow;
- (void) expandLocalRepositories;
- (void) updateSpinnerForRepositoryController:(GBBaseRepositoryController*)repoCtrl;

- (IBAction) addGroup:(id)_;

- (IBAction) selectPreviousRepository:(id)_;
- (IBAction) selectNextRepository:(id)_;

- (IBAction) remove:(id)_;

- (IBAction) selectRightPane:_;

@end
