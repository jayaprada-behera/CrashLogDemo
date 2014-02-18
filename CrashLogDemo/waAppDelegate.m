//
//  waAppDelegate.m
//  CrashLogDemo
//
//  Created by Jayaprada Behera on 7/15/13.
//  Copyright (c) 2013 Webileapps. All rights reserved.
//

#import "waAppDelegate.h"

#import "waViewController.h"

id refToSelf;
#define CRASHLOG_ALERT_TAG 0x16
#define CRASH_FILE_NAME     @"CRASH_LOG.txt"
#define CRASHLOG_DEV_TO     @"abc@gmail.com"
#define CRASHLOG_DEV_CC  @"xyz@gmail.com"
#define CRASH_SUBJECT @"You seem to have had problems with this app earlier. Please help us by reporting logs to Dev team."

@implementation waAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    refToSelf = self;
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);


    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.viewController = [[waViewController alloc] initWithNibName:@"waViewController" bundle:nil];
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long) NULL), ^(void) {
        [self checkForCrashLogs:nil];
    });

    return YES;
}
# pragma mark - Crash Log addition

/**Catching exception at realtime */

static void  uncaughtExceptionHandler(NSException *exception) {
    [refToSelf saveCrashWithForException:exception];
    // Internal error reporting
    abort();
}

-(void) saveCrashWithForException:(NSException *)exception {
    NSString *filePath = [self prepareCrashFile];
    if (filePath) {
        
        NSString *exceptionDetails = [NSString stringWithFormat:@"\nCrash: %@ \n Stack Trace:\n %@ ", exception, [exception callStackSymbols] ];
        NSLog(@"%@",exceptionDetails);
        NSData *crashData = [exceptionDetails dataUsingEncoding:NSUTF8StringEncoding];
        
        NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:filePath];
        [fileHandler seekToEndOfFile];
        [fileHandler writeData:crashData];
        [fileHandler closeFile];
    }else {
        NSLog(@"Crash file creation failed");
    }
}

/**
 Prepare the crash file header for better readability - Append a line on the top from the method -(NSString *) firstLineData .
 @return the absolute path of the file.
 */
-(NSString *) prepareCrashFile{
    NSString *path;
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	path = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Crashes"];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if ([fileMgr fileExistsAtPath:path]) {
        //      Check if file exists
        path = [path stringByAppendingPathComponent:CRASH_FILE_NAME];
        if ([fileMgr fileExistsAtPath:path])
        {
            NSData *firstLine = [self firstLineData];
            if (!firstLine) {
                firstLine = [[NSData alloc]init];
            }
            NSFileHandle *fileHandler = [NSFileHandle fileHandleForUpdatingAtPath:path];
            [fileHandler seekToEndOfFile];
            [fileHandler writeData:firstLine];
            [fileHandler closeFile];
            return path;
        }else {
            //      Create File path
            [self createFileAtPath:path];
            return path;
        }
    }else{
        //        Create Directory and File path
        NSError *error;
        if (![fileMgr createDirectoryAtPath:path
                withIntermediateDirectories:NO
                                 attributes:nil
                                      error:&error])
		{
            NSString *msg = [NSString stringWithFormat:@"Create directory error: %@",error ];
			NSLog(@"%@",msg);
            return nil;
		}
        //      Create File path
        path = [path stringByAppendingPathComponent:CRASH_FILE_NAME];
        [self createFileAtPath:path];
        return path;
        
    }
    
    
    return nil;
}

/**
 Creates a filepath with the contents returned from the  method -(NSString *) firstLineData
 */

-(void) createFileAtPath:(NSString *) path{
    NSData *firstLine = [self firstLineData];
    if (!firstLine) {
        firstLine = [[NSData alloc]init];
    }
    [[NSFileManager defaultManager] createFileAtPath:path
                                            contents:[self firstLineData]
                                          attributes:nil];
}

/**
 Prepares the file header of the crash file.
 @return NSData object prepared from the string which contains Date of crash and version of the app along with bundle ID.
 
 */
-(NSData *) firstLineData {
    NSString * firstLine = [NSString stringWithFormat:@"\n Date: %@, Version:%@",[NSDate date], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
    NSData *firstData = [firstLine dataUsingEncoding:NSUTF8StringEncoding];
    return firstData;
}

/**
 
 @return Crash file path, if exists otherwise returns nil.
 
 */

-(NSString *) crashFilePath {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Crashes"];
    path = [path stringByAppendingPathComponent:CRASH_FILE_NAME];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        return path;
    }
    return nil;
}


/**
 Deletes crash file form the device, if exists.
 */

-(void) removeCrashFile {
    NSString *path = [self crashFilePath];
    if (path) {
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:path error:&error])
            //Delete it
		{
			NSString *str = [NSString stringWithFormat:@"Delete file error: %@", error];
            NSLog(@"%@",str);
		}
    }
}

/**
 Check for the crash logs and throws an alert if any crash file found with last modification date later than the last reported crash date
 */
-(void) checkForCrashLogs:(id) sender {
    NSString *filePath = [self crashFilePath];
    if (filePath) {
        NSError *error;
        NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
        NSDate *fileDate =[dictionary objectForKey:NSFileModificationDate];
        
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        NSDate *lastModifiedDate = (NSDate *)[prefs objectForKey:@"LAST_MODIFIED_DATE"];
        if ((!lastModifiedDate && fileDate )|| (lastModifiedDate && fileDate && ([lastModifiedDate compare:fileDate] == NSOrderedAscending))) {
            //        Crash log found
            [prefs setObject:fileDate forKey:@"LAST_MODIFIED_DATE"];
            [prefs synchronize];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showCrashAlert:nil];
            });
            //            [self performSelectorOnMainThread:@selector(showCrashAlert:) withObject:nil waitUntilDone:NO];
        }else if (fileDate){
            //        No crash logs
            [prefs setObject:fileDate forKey:@"LAST_MODIFIED_DATE"];
            [prefs synchronize];
            
        }
    }
}
- (void) showCrashAlert:(id) sender {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"" message:CRASH_SUBJECT delegate:self cancelButtonTitle:@"CANCEL" otherButtonTitles:@"CONTINUE", nil];
    alertView.tag = CRASHLOG_ALERT_TAG;
    [alertView show];
}

#pragma mark - AlertView delegate
/// Send email in case user opts for it with the Crash log file attached.

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    
    if ((alertView.tag == CRASHLOG_ALERT_TAG) && (buttonIndex == 1)) {
        MFMailComposeViewController *picker = [[MFMailComposeViewController alloc] init];
        if (picker!= nil) {
            picker.mailComposeDelegate = self;
            
            NSString *sub = [NSString stringWithFormat:@"Chiching App - UI Crash Logs"];
            
            [picker setSubject:sub];
            
            // Set up recipients
            NSArray *toRecipients = [NSArray arrayWithObject:CRASHLOG_DEV_TO];
            // Set up CC recipients
                NSArray *ccRecipients = [NSArray arrayWithObject:CRASHLOG_DEV_CC];
            [picker setToRecipients:toRecipients];
            [picker setCcRecipients:ccRecipients];
            
            // Fill out the email body text
            NSString *emailBody = @"Attaching the crash logs for referrence.. \n";
            
            [picker setMessageBody:emailBody isHTML:NO];
            NSData *data = [NSData dataWithContentsOfFile:[self crashFilePath]];
            [picker addAttachmentData:data mimeType:@"text/xml" fileName:@"CrashLog.txt"];
            if (picker != nil) {
                //                [self.navController.topViewController presentModalViewController:picker animated:YES];
                [self.viewController presentViewController:picker animated:YES completion:nil];
            }else {
                NSLog(@"Email-Picker is nil");
            }
        }
        
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error
{
	NSString *message = @"";
	// Notifies users about errors associated with the interface
	switch (result)
	{
		case MFMailComposeResultCancelled:
			message = @"Result: canceled";
			break;
		case MFMailComposeResultSaved:
			message = @"Result: saved";
			break;
		case MFMailComposeResultSent:{
            [self removeCrashFile];
			message = @"Result: sent";
			break;
        }
		case MFMailComposeResultFailed:
			message = @"Result: failed";
			break;
		default:
			message = @"Result: not sent";
			break;
	}
    NSLog(@"%@",message);
    [self.window.rootViewController dismissModalViewControllerAnimated:YES];
	
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
