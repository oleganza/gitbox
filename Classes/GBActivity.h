// Presenter for OATask in a GBActivityController

@class OATask;
@interface GBActivity : NSObject

@property(nonatomic,assign) OATask* task;
@property(nonatomic,assign) BOOL isRunning;

@property(nonatomic,retain) NSDate* date;
@property(nonatomic,copy) NSString* path;
@property(nonatomic,copy) NSString* command;
@property(nonatomic,copy) NSString* status;
@property(nonatomic,copy) NSString* textOutput;

- (NSString*) line;
- (void) appendData:(NSData*)chunk;
@end
