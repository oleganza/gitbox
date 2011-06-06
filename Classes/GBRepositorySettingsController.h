
#import "GBWindowControllerWithCallback.h"

@class GBRepository;
@class GBRepositorySettingsViewController;

extern NSString* const GBRepositorySettingsSummary;
extern NSString* const GBRepositorySettingsBranchesAndTags;
extern NSString* const GBRepositorySettingsRemoteServers;
extern NSString* const GBRepositorySettingsIgnoredFiles;
extern NSString* const GBRepositorySettingsGitConfig;

@interface GBRepositorySettingsController : GBWindowControllerWithCallback<NSWindowDelegate>

@property(nonatomic, retain) GBRepository* repository;
@property(nonatomic, copy)   NSString* selectedTab;
@property(nonatomic, retain) IBOutlet NSButton* cancelButton;
@property(nonatomic, retain) IBOutlet NSButton* saveButton;
@property(nonatomic, retain) IBOutlet NSTabView* tabView;

+ (id) controllerWithTab:(NSString*)tab repository:(GBRepository*)repo;

- (IBAction) cancel:(id)sender;
- (IBAction) save:(id)sender;


// Protected

- (void) viewControllerDidChangeDirtyStatus:(GBRepositorySettingsViewController*)ctrl;
- (void) criticalConfirmationWithMessage:(NSString*)message description:(NSString*)desc ok:(NSString*)okOrNil completion:(void(^)(BOOL))completion;

@end
