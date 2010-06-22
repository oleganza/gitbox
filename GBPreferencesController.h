@interface GBPreferencesController : NSWindowController<NSWindowDelegate, NSTextFieldDelegate>
{
  NSTabView* tabView;
  NSTextField* gitPathField;
  NSTextField* gitPathStatusLabel;
  BOOL isOpened;
}

@property(nonatomic,retain) IBOutlet NSTabView* tabView;
@property(nonatomic,retain) IBOutlet NSTextField* gitPathField;
@property(nonatomic,retain) IBOutlet NSTextField* gitPathStatusLabel;

- (NSArray*) diffTools;

@end
