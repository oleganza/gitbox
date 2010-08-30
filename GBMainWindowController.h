
@class GBSourcesController;
@class GBToolbarController;

@interface GBMainWindowController : NSWindowController<NSSplitViewDelegate>
{
}

@property(retain) GBSourcesController* sourcesController;
@property(retain) GBToolbarController* toolbarController;

@property(retain) IBOutlet NSSplitView* splitView;
@property(retain) IBOutlet NSToolbar* toolbar;

+ (id) controller;

- (void) saveState;
- (void) loadState;

- (IBAction) selectPreviousRepository:(id)_;
- (IBAction) selectNextRepository:(id)_;

@end
