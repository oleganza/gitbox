@class GBToolbarController;
@class NSViewController;
@protocol GBMainWindowItem <NSObject>
@optional
- (NSString*) windowTitle;
- (NSURL*) windowRepresentedURL;
- (GBToolbarController*) toolbarController;
- (NSViewController*) viewController;
- (void) willDeselectWindowItem;
- (void) didSelectWindowItem;
@end
