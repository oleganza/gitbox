extern NSString* OATaskNotification;
@class OAActivity;
@interface OATask : NSObject
{
  NSString* executableName;
  NSString* launchPath;
  NSString* currentDirectoryPath;
  NSTask* nstask;
  NSMutableData* output;
  NSArray* arguments;
  
  BOOL avoidIndicator;
  BOOL ignoreFailure;
  
  NSTimeInterval pollingPeriod;
  NSTimeInterval terminateTimeout;
  
  id standardOutput;
  id standardError;
  
  OAActivity* activity;
}

@property(nonatomic,retain) NSString* executableName;
@property(nonatomic,retain) NSString* launchPath;
@property(nonatomic,retain) NSString* currentDirectoryPath;
@property(nonatomic,retain) NSTask* nstask;
@property(nonatomic,retain) NSMutableData* output;
@property(nonatomic,retain) NSArray* arguments;

@property(nonatomic,assign) BOOL avoidIndicator;
@property(nonatomic,assign) BOOL ignoreFailure;

@property(nonatomic,assign) NSTimeInterval pollingPeriod;
@property(nonatomic,assign) NSTimeInterval terminateTimeout;

@property(nonatomic,retain) id standardOutput;
@property(nonatomic,retain) id standardError;

@property(nonatomic,retain) OAActivity* activity;

+ (id) task;


#pragma mark Interrogation

+ (NSString*) systemPathForExecutable:(NSString*)executable;
- (NSString*) systemPathForExecutable:(NSString*)executable;
- (int) terminationStatus;
- (BOOL) isError;
- (NSString*) command;


#pragma mark Mutation methods

- (id) launch;
- (id) launchAndWait;
- (id) launchWithArguments:(NSArray*)args;
- (id) launchWithArgumentsAndWait:(NSArray*)args;

- (void) terminate;

- (id) showError;
- (id) showErrorIfNeeded;

- (id) subscribe:(id)observer selector:(SEL) selector;
- (id) unsubscribe:(id)observer;

- (NSString*) rememberedPathForExecutable:(NSString*)exec;
- (void) rememberPath:(NSString*)aPath forExecutable:(NSString*)exec;

#pragma mark API for subclasses

- (void) didFinish;

@end
