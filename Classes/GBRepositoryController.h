#import "GBMainWindowItem.h"
#import "GBChangeDelegate.h"
#import "GBSidebarItemObject.h"

@class GBRepository;
@class GBRef;
@class GBRemote;
@class GBCommit;

@class GBSidebarItem;
@class GBRepositoryToolbarController;
@class GBRepositoryViewController;
@class OAFSEventStream;
@class OABlockQueue;

@interface GBRepositoryController : NSResponder<GBMainWindowItem, GBSidebarItemObject>

@property(nonatomic, retain) GBRepository* repository;
@property(nonatomic, retain, readonly) NSURL* url;
@property(nonatomic, retain) OABlockQueue* autofetchQueue;
@property(nonatomic, retain) GBSidebarItem* sidebarItem;
@property(nonatomic, assign) NSWindow* window;
@property(nonatomic, retain) GBRepositoryToolbarController* toolbarController;
@property(nonatomic, retain) GBRepositoryViewController* viewController;
@property(nonatomic, retain) GBCommit* selectedCommit;
@property(nonatomic, retain) OAFSEventStream* fsEventStream;
@property(nonatomic, copy) NSString* lastCommitBranchName;
@property(nonatomic, assign) BOOL needsInitialFetch;

@property(nonatomic, assign, readonly, getter=isSearching) BOOL searching;
@property(nonatomic, copy)   NSString* searchString;
@property(nonatomic, retain, readonly) NSArray* searchResults;
@property(nonatomic, assign, readonly) double searchProgress;

@property(nonatomic, assign) NSInteger isRemoteBranchesDisabled;
@property(nonatomic, assign, readonly) NSInteger isDisabled;
@property(nonatomic, assign, readonly) NSInteger isSpinning;

+ (id) repositoryControllerWithURL:(NSURL*)url;

- (id) initWithURL:(NSURL*)aURL;

// Returns a list of search results or stageAndCommits depending on the current state.
- (NSArray*) visibleCommits;
- (NSArray*) stageAndCommits;
- (GBCommit*) contextCommit; // returns a selected commit or a first commit in the list (not the stage!)

- (void) start;
- (void) stop;

- (void) loadCommitsIfNeeded;
- (void) updateRemoteRefs;

- (void) initialFetchIfNeededWithBlock:(void(^)())aBlock;

- (void) checkoutRef:(GBRef*) ref;
- (void) checkoutRef:(GBRef*) ref withNewName:(NSString*)name;
- (void) checkoutNewBranchWithName:(NSString*)name commit:(GBCommit*)aCommit;
- (void) createTagWithName:(NSString*)name commitId:(NSString*)commitId;
- (void) deleteTagWithName:(NSString*)tagName commitId:(NSString*)commitId;
- (void) selectRemoteBranch:(GBRef*) remoteBranch;
- (void) createAndSelectRemoteBranchWithName:(NSString*)name remote:(GBRemote*)aRemote;

- (void) selectCommitId:(NSString*)commitId;

- (void) stageChanges:(NSArray*)changes;
- (void) stageChanges:(NSArray*)changes withBlock:(void(^)())block;
- (void) unstageChanges:(NSArray*)changes;
- (void) revertChanges:(NSArray*)changes;
- (void) deleteFilesInChanges:(NSArray*)changes;

- (void) commitWithMessage:(NSString*)message;

- (void) addOpenMenuItemsToMenu:(NSMenu*)aMenu;

- (void) removeRefs:(NSArray*)refs;

- (IBAction) fetch:(id)sender;
- (IBAction) pull:(id)sender;
- (IBAction) push:(id)sender;
- (IBAction) forcePush:(id)sender;
- (IBAction) rebase:(id)sender;
- (IBAction) rebaseCancel:(id)sender;
- (IBAction) rebaseSkip:(id)sender;
- (IBAction) rebaseContinue:(id)sender;

- (IBAction) openInFinder:(id)sender;
- (IBAction) openInTerminal:(id)sender;
- (IBAction) openInXcode:(NSMenuItem*)sender;

- (BOOL) validateFetch:(id)sender;
- (BOOL) validatePull:(id)sender;
- (BOOL) validatePush:(id)sender;

- (IBAction) nextCommit:(id)sender;
- (IBAction) previousCommit:(id)sender;

- (IBAction) stashChanges:(id)sender;
- (IBAction) applyStash:(NSMenuItem*)sender;
- (IBAction) applyStashMenu:(id)sender;
- (IBAction) removeOldStashes:(NSMenuItem*)sender;
- (IBAction) resetChanges:(id)sender;
- (IBAction) mergeCommit:(NSMenuItem*)sender;
- (IBAction) cherryPickCommit:(NSMenuItem*)sender;
- (IBAction) applyAsPatchCommit:(NSMenuItem*)sender;
- (IBAction) resetBranchToCommit:(NSMenuItem*)sender;
- (IBAction) revertCommit:(NSMenuItem*)sender;

- (IBAction) newTag:(id)sender;
- (IBAction) deleteTag:(id)sender;
- (IBAction) deleteTagMenu:(id)sender;

- (IBAction) openSettings:(id)sender;
- (IBAction) editBranchesAndTags:(id)sender;
- (IBAction) editRemotes:(id)sender;

- (IBAction) performFindPanelAction:(id)sender; // standard selector for cmd+F, cmd+G, cmd+E etc.
- (IBAction) search:(id)sender; // posts notification repositoryControllerSearchDidStart:
- (IBAction) cancelSearch:(id)sender; // posts notification repositoryControllerSearchDidEnd:


@end
