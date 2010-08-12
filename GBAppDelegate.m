#import "GBAppDelegate.h"
#import "GBRepositoryController.h"
#import "GBActivityController.h"
#import "GBPreferencesController.h"
#import "GBLicenseCheck.h"

#import "GBRepository.h"
#import "GBStage.h"
#import "OATask.h"

#import "NSFileManager+OAFileManagerHelpers.h"
#import "NSAlert+OAAlertHelpers.h"
#import "NSData+OADataHelpers.h"

#import "OAPrimaryMACAddress.h"

@interface GBAppDelegate ()
- (void) storeRepositories;
@end


@implementation GBAppDelegate

@synthesize windowControllers;
@synthesize preferencesController;

- (NSMutableSet*) windowControllers
{
  if (!windowControllers)
  {
    self.windowControllers = [NSMutableSet set];
  }
  return [[windowControllers retain] autorelease];
}

- (void)addWindowController:(id)aController
{
  [self.windowControllers addObject:aController];
}

- (void)removeWindowController:(id)aController
{
  [self.windowControllers removeObject:aController];
}

- (GBRepositoryController*) windowController
{
  GBRepositoryController* windowController = [GBRepositoryController controller];
  windowController.delegate = self;
  [windowController setShouldCascadeWindows:NO];
  return windowController;
}

- (void) dealloc
{
  self.windowControllers = nil;
  self.preferencesController = nil;
  [super dealloc];
}




#pragma mark Actions


- (IBAction) releaseNotes:(id)_
{
  NSString* releaseNotesURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"GBReleaseNotesURL"];
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:releaseNotesURLString]];
}

- (IBAction) openDocument:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  openPanel.delegate = self;
  openPanel.allowsMultipleSelection = NO;
  openPanel.canChooseFiles = YES;
  openPanel.canChooseDirectories = YES;
  if ([openPanel runModal] == NSFileHandlingPanelOKButton)
  {
    [self application:NSApp openFile:[[[openPanel URLs] objectAtIndex:0] path]];
  }
}

- (IBAction) showActivityWindow:(id)sender
{
  [[GBActivityController sharedActivityController] showWindow:sender];
}

- (GBRepositoryController*) openWindowForRepositoryAtURL:(NSURL*)url
{
  if ([self.windowControllers count] > 1)
  {
    if (!GBIsValidLicense())
    {
      [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                               selector:@selector(askForLicense)
                                                 object:nil];
      [self performSelector:@selector(askForLicense)
                 withObject:nil
                 afterDelay:0.0];
      return nil;
    }
  }
  
  if (![self checkGitVersion])
  {
    return nil;
  }
  
  for (GBRepositoryController* ctrl in self.windowControllers)
  {
    if ([ctrl.repository.url isEqual:url])
    {
      [ctrl showWindow:self];
      return ctrl;
    }
  }
  
  GBRepositoryController* windowController = [self windowController];
  windowController.repositoryURL = url;
  [self addWindowController:windowController];
  [windowController showWindow:self];
  return windowController;
}

- (GBRepositoryController*) openRepositoryAtURL:(NSURL*)url
{
  id ctrl = [self openWindowForRepositoryAtURL:url];
  if (ctrl)
  {
    [self storeRepositories];
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:url];    
  }
  return ctrl;
}

- (BOOL) checkGitVersion
{
  NSString* gitVersion = [GBRepository gitVersion];
  if (!gitVersion)
  {
    [NSAlert message:@"Please locate git" 
         description:[NSString stringWithFormat:NSLocalizedString(@"The Gitbox requires git version %@ or later. Please install git or set its path in Preferences.", @""), 
                      [GBRepository supportedGitVersion]]
         buttonTitle:NSLocalizedString(@"Open Preferences",@"")];
    [self.preferencesController showWindow:nil];
    return NO;
  }
  else if (![GBRepository isSupportedGitVersion:gitVersion])
  {
    [NSAlert message:@"Please update git" 
         description:[NSString stringWithFormat:NSLocalizedString(@"The Gitbox works with the version %@ or later. Your git version is %@.\n\nPath to git executable: %@", @""), 
                      [GBRepository supportedGitVersion], 
                      gitVersion,
                      [OATask systemPathForExecutable:@"git"]]
         buttonTitle:NSLocalizedString(@"Open Preferences",@"")];
    [self.preferencesController showWindow:nil];
    return NO;
  }
  return YES;
}

- (IBAction) showDiffToolPreferences:(id)_
{
  [self.preferencesController selectDiffToolTab];
  [self.preferencesController showWindow:nil];
}



#pragma mark Window states


- (void) storeRepositories
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSMutableArray* paths = [NSMutableArray array];
  for (GBRepositoryController* ctrl in self.windowControllers)
  {
    [paths addObject:ctrl.repository.path];
  }
  [defaults setObject:paths forKey:@"openedRepositories"];
}

- (void) loadRepositories
{
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSArray* paths = [defaults objectForKey:@"openedRepositories"];
  if (paths && [paths isKindOfClass:[NSArray class]])
  {
    for (NSString* path in paths)
    {
      if ([NSFileManager isWritableDirectoryAtPath:path] &&
          [GBRepository validRepositoryPathForPath:path])
      {
        [self openWindowForRepositoryAtURL:[NSURL fileURLWithPath:path]];
      } // if path is valid repo
    } // for
  } // if paths
}




#pragma mark License


- (void) askForLicense
{
  //
  
}






#pragma mark GBRepositoryControllerDelegate


- (void) windowControllerWillClose:(GBRepositoryController*)aController
{
  [self removeWindowController:aController];
  [self storeRepositories];
}





#pragma mark NSApplicationDelegate


- (void) applicationDidFinishLaunching:(NSNotification*) aNotification
{
  [self checkGitVersion];
  [self loadRepositories];
}

- (void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self storeRepositories];
}

- (BOOL) applicationShouldOpenUntitledFile:(NSApplication*) app
{
  return NO;
}

- (BOOL) application:(NSApplication*)theApplication openFile:(NSString*)path
{
  if (![NSFileManager isWritableDirectoryAtPath:path])
  {
    [NSAlert message:NSLocalizedString(@"File is not a writable folder.", @"") description:path];
    return NO;
  }
  
  NSString* repoPath = [GBRepository validRepositoryPathForPath:path];
  if (repoPath)
  {
    NSURL* url = [NSURL fileURLWithPath:repoPath];
    [self openRepositoryAtURL:url];
    return YES;
  }
  else 
  {
    NSURL* url = [NSURL fileURLWithPath:path];
    if ([NSAlert prompt:NSLocalizedString(@"The folder is not a git repository.\nMake it a repository?", @"")
                  description:path])
    {
      [GBRepository initRepositoryAtURL:url];
      GBRepositoryController* ctrl = [self openRepositoryAtURL:url];
      if (ctrl)
      {
        [ctrl.repository.stage stageAll];
        [ctrl.repository commitWithMessage:@"Initial commit"];
        return YES;
      }
    }
  }
  return NO;
}




#pragma mark NSOpenSavePanelDelegate


- (BOOL) panel:(id)sender validateURL:(NSURL*)url error:(NSError **)outError
{
  if ([url isFileURL] && [NSFileManager isWritableDirectoryAtPath:[url path]])
  {
    return YES;
  }
  if (outError != NULL)
  {
    *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
  }
  return NO;  
}



@end
