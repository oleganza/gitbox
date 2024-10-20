@class GBRepositoriesGroup;
@class GBBaseRepositoryController;
@protocol GBRepositoriesControllerLocalItem <NSObject>
- (void) enumerateRepositoriesWithBlock:(void(^)(GBBaseRepositoryController* repoCtrl))aBlock;
- (GBBaseRepositoryController*) findRepositoryControllerWithURL:(NSURL*)aURL;
- (BOOL) hasRepositoryController:(GBBaseRepositoryController*)repoCtrl;
- (BOOL) isRepositoriesGroup;
- (NSUInteger) repositoriesCount;
- (GBBaseRepositoryController*) repositoryController;
- (void) removeLocalItem:(id<GBRepositoriesControllerLocalItem>)aLocalItem;
- (id) plistRepresentationForUserDefaults;
- (GBRepositoriesGroup*) groupContainingLocalItem:(id<GBRepositoriesControllerLocalItem>)aLocalItem;
@end
