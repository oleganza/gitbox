#import "GBRepository.h"
#import "GBRef.h"
#import "GBCommit.h"
#import "GBHistoryTask.h"
#import "NSData+OADataHelpers.h"

@interface GBHistoryTask ()
@end

@implementation GBHistoryTask

@synthesize branch;
@synthesize joinedBranch;
@synthesize substructedBranch;
@synthesize beforeTimestamp;
@synthesize includeDiff;

@synthesize limit;
@synthesize skip;

@synthesize commits;


- (NSUInteger) limit
{
  if (limit <= 0) limit = 1000;
  return limit;
}

- (void) dealloc
{
  self.branch = nil;
  self.joinedBranch = nil;
  self.substructedBranch = nil;
  self.commits = nil;
  [super dealloc];
}

- (NSArray*) arguments
{
  // FIXME: should use %B in some later git version rather than %w(10000,4,4)...%b
  NSMutableArray* args = [NSMutableArray arrayWithObjects:@"log", nil];
  
  [args addObject:[self.branch commitish]];
  
  //  NSLog(@"%@ rev-list arguments:", [self class]);
  //  NSLog(@"branch: %@", self.branch);
  //  NSLog(@"joinedBranch: %@", self.joinedBranch);
  //  NSLog(@"substructedBranch: %@", self.substructedBranch);
  
  if (self.joinedBranch)
  {
    [args addObject:[self.joinedBranch commitish]];
  }
  if (self.substructedBranch)
  {
    [args addObject:@"--not"];
    [args addObject:[self.substructedBranch commitish]];
  }
  
  if (self.includeDiff)
  {
    [args addObject:[NSString stringWithFormat:@"--patch", self.limit]];
  }
  
  if (self.limit > 0)
  {
    [args addObject:[NSString stringWithFormat:@"--max-count=%d", self.limit]];
  }
  
  if (self.skip > 0)
  {
    [args addObject:[NSString stringWithFormat:@"--skip=%d", self.skip]];
  }
  
  if (self.beforeTimestamp)
  {
    [args addObject:[NSString stringWithFormat:@"--before=%d", self.beforeTimestamp]];
  }
  
  [args addObject: @"--format=commit %H%n"
   "tree %T%n"
   "parents %P%n"
   "authorName %an%n"
   "authorEmail %ae%n"
   "committerName %cn%n"
   "committerEmail %ce%n"
   "authorDate %ai%n"
   "committerTimestamp %ct%n"
   "%n"
   "%w(99999,4,4)%B"];
  
   // adding explicit path argument to allow branch names with slashes
  [args addObject:@"--"];
  [args addObject:@"."];
  
//  NSLog(@"arguments: %@", [[args subarrayWithRange:NSMakeRange(4, [args count] - 4)] componentsJoinedByString:@" "]);
//  NSLog(@"--");
  return args;
}

- (void) didFinishInBackground
{
  [super didFinishInBackground];
  if ([self isError])
  {
    self.commits = [NSArray array];
  }
  else
  {
    self.commits = [self commitsFromRawFormatData:self.output];
  }
}


/*
our format (for ease of NSDate integration and name/email parsing):
(git prepends "commit <SHA1>" on its own; seems like a bug, so i don't rely on that for the future versions of git)
 
commit c1909e72952ec6b95f819a4ad8faa8d69f1d961d
commit c1909e72952ec6b95f819a4ad8faa8d69f1d961d
tree 219a1c0a3f7e2500a3fe07ee5a6300cff10e98bb
parents 2381e39e5ff740883b98c5aca019950f9167b67f
authorName Junio C Hamano
authorEmail gitster@pobox.com
committerName Junio C Hamano
committerEmail gitster@pobox.com
authorDate 2010-05-01 22:05:14 -0700
 
    wt-status: fix 'fprintf' compilation warning

    color_fprintf() has the same function signature as fprintf() and newer 
    gcc warns when a non-constant string is fed as the format

    Signed-off-by: Junio C Hamano <gitster@pobox.com>
 
diff --git a/GBAppDelegate.m b/GBAppDelegate.m
index d350d28..4dc0ac7 100644
--- a/GBAppDelegate.m
+++ b/GBAppDelegate.m
@@ -294,7 +294,10 @@

 - (void)applicationDidBecomeActive:(NSNotification *)aNotification
 {
-  [self.windowController showWindow:self];
+  if (![NSApp keyWindow])
+  {
+    [self.windowController showWindow:self];
+  }
 }
 
commit ddb27a5a6b5ed74c70d56c96592b32eed415d72b
commit ddb27a5a6b5ed74c70d56c96592b32eed415d72b
tree b835a16ef2d995f1628d6d5f280cd1bd6514e216
parents c8c073c4201600b958f5d3bd9e8051b2060bd3f7 ed215b109fc0e352456ea2ef6a0f8375e28466d5
authorName Junio C Hamano
authorEmail gitster@pobox.com
committerName Junio C Hamano
committerEmail gitster@pobox.com
authorDate 2010-05-01 20:23:10 -0700

    Merge branch 'maint'

    * maint:
    index-pack: fix trivial typo in usage string
    git-submodule.sh: properly initialize shell variables
 
diff --git a/icon.psd b/icon.psd
deleted file mode 100644
index a1e8c9b..0000000
Binary files a/icon.psd and /dev/null differ
diff --git a/psd/history-markers.psd b/psd/history-markers.psd
new file mode 100644
index 0000000..831d92d
Binary files /dev/null and b/psd/history-markers.psd differ
 
 */

- (NSArray*) commitsFromRawFormatData:(NSData*)data
{

#define HistoryScanError(msg) { \
  [pool drain]; \
  NSLog(@"ERROR: GBHistoryTask parse error: %@", msg); \
  NSLog(@"INPUT: %@", stringData); \
  return list; \
}
  
  NSMutableArray* list = [NSMutableArray arrayWithCapacity:self.limit];
  
  NSString* stringData = [data UTF8String];
  NSArray* lines = [stringData componentsSeparatedByString:@"\n"];
  
  NSUInteger lineIndex = 0;
  NSString* line = nil;
#define GBHistoryNextLine { \
  lineIndex++; \
  if (lineIndex < [lines count]) { \
    line = [lines objectAtIndex:lineIndex]; \
  } else { \
    line = nil; \
  } \
}
  NSCharacterSet* whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
  while (lineIndex < [lines count])
  {
    NSAutoreleasePool* pool = [NSAutoreleasePool new];
    
    line = [lines objectAtIndex:lineIndex];
    
    if ([line length] > 0)
    {
      GBCommit* commit = [[GBCommit new] autorelease];
      
      // commit 4d235c8044a638108b67e22f94b2876657130fc8
      if ([line hasPrefix:@"commit "])
      {
        commit.commitId = [line substringFromIndex:7]; // 'commit ' skipped
      }
      else HistoryScanError(@"Expected 'commit <sha1>' line");

      GBHistoryNextLine;
      
      if ([line hasPrefix:@"commit "]) // skip additional commit line
      {
        GBHistoryNextLine;
      }
      
      // tree 715659d7f232f1ecbe19674a16c9b03067f6c9e1
      if ([line hasPrefix:@"tree "])
      {
        commit.treeId = [line substringFromIndex:5]; // 'tree ' skipped
      }
      else HistoryScanError(@"Expected 'tree <sha1>' line");
      
      GBHistoryNextLine;
      
      // parents 8d0ea3117597933610e02907d14b443f8996ca3b[<space> <sha1>[<space> <sha1>[...]]] 
      if ([line hasPrefix:@"parents "])
      {
        commit.parentIds = [[line substringFromIndex:8] componentsSeparatedByString:@" "]; // 'parents ' skipped
        if ([commit.parentIds count] == 1 && [[commit.parentIds objectAtIndex:0] isEqualToString:@""])
        {
          commit.parentIds = [NSArray array];
        }
      }
      else HistoryScanError(@"Expected 'parents <sha1>[ <sha1>[...]]' line");
      
      GBHistoryNextLine;
      
      // authorName Junio C Hamano
      if ([line hasPrefix:@"authorName "])
      {
        commit.authorName = [line substringFromIndex:11]; // 'authorName ' skipped
      }
      else HistoryScanError(@"Expected 'authorName <name>' line");
      
      GBHistoryNextLine;
      
      // authorEmail gitster@pobox.com
      if ([line hasPrefix:@"authorEmail "])
      {
        commit.authorEmail = [line substringFromIndex:12]; // 'authorEmail ' skipped
      }
      else HistoryScanError(@"Expected 'authorEmail <email>' line");
      
      GBHistoryNextLine;
      
      // committerName Junio C Hamano
      if ([line hasPrefix:@"committerName "])
      {
        commit.committerName = [line substringFromIndex:14]; // 'committerName ' skipped
      }
      else HistoryScanError(@"Expected 'committerName <name>' line");
      
      GBHistoryNextLine;
      
      // committerEmail gitster@pobox.com
      if ([line hasPrefix:@"committerEmail "])
      {
        commit.committerEmail = [line substringFromIndex:15]; // 'committerEmail ' skipped
      }
      else HistoryScanError(@"Expected 'committerEmail <email>' line");
      
      GBHistoryNextLine;
      
      // authorDate 2010-05-01 20:23:10 -0700
      if ([line hasPrefix:@"authorDate "])
      {
        commit.date = [NSDate dateWithString:[line substringFromIndex:11]]; // 'authorDate ' skipped
      }
      else HistoryScanError(@"Expected 'authorDate <date>' line");
      
      GBHistoryNextLine;

      // committerTimestamp 1302681533
      if ([line hasPrefix:@"committerTimestamp "])
      {
        commit.rawTimestamp = [[line substringFromIndex:19] intValue]; // 'committerTimestamp ' skipped
      }
      else HistoryScanError(@"Expected 'committerTimestamp <timestamp>' line");
      
      GBHistoryNextLine;
      
      // Skip initial empty lines
      while (line && [line length] <= 0)
      {
        GBHistoryNextLine;
      }
      NSMutableArray* rawBodyLines = [NSMutableArray array];
      while (line && [line length] <= 0 || [line hasPrefix:@"    "])
      {
        [rawBodyLines addObject:[line stringByTrimmingCharactersInSet:whitespaceCharacterSet]];
  //      if ([line length] > 0)
  //      {
  //        [rawBodyLines addObject:[line stringByTrimmingCharactersInSet:whitespaceCharacterSet]];
  //      }
        GBHistoryNextLine;
      }
      
      commit.message = [rawBodyLines componentsJoinedByString:@"\n"];
      
      // Stupid git removes LFs between "Signed-off-by" signatures. We fix this by this hack
      // (which is not that awful, actually):
      commit.message = [commit.message stringByReplacingOccurrencesOfString:@"> Signed-off-by:"
                                                                 withString:@">\nSigned-off-by:"];
      
      
      commit.message = [commit.message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      commit.repository = self.repository;
      [list addObject:commit];
      
      
      if (self.includeDiff)
      {
        NSMutableString* diffLines = [NSMutableString string];
        NSMutableString* diffPaths = [NSMutableString string];
        while (lineIndex < [lines count] && ![line hasPrefix:@"commit "])
        {
          //diff --git a/psd/icon.psd b/psd/icon.psd
          if ([line hasPrefix:@"diff"])
          {
            NSString* paths = [line stringByReplacingOccurrencesOfString:@"diff --git a/" withString:@""];
            [diffPaths appendString:paths];
            [diffPaths appendString:@"\n"];
          }
          else if ([line hasPrefix:@"---"] || [line hasPrefix:@"+++"])
          {
            // skip lines like:
            //--- a/GBMainWindowController.h
            //+++ b/GBMainWindowController.h
            //NSLog(@"Skipping diff line: %@", line);
          }
          else if ([line hasPrefix:@"-"] || [line hasPrefix:@"+"])
          {
            [diffLines appendString:[line substringFromIndex:1]];
            [diffLines appendString:@"\n"];
          }
          else
          {
            // skip non-changed diff lines and header lines like:
            //new file mode 100644
            //index 0000000..a1e8c9b
            //Binary files /dev/null and b/psd/icon.psd differ
            //@@ -151,27 +152,29 @@
            //NSLog(@"Skipping diff line: %@", line);
          }
            
          GBHistoryNextLine;
          
        } // loop over diff
        
        commit.diffPaths = diffPaths;
        commit.diffLines = diffLines;
        
      } // if includeDiff
      
    }// if ! empty line
    else
    {
      GBHistoryNextLine;
    }

    [pool drain];
  }
  
  return list;
}

@end
