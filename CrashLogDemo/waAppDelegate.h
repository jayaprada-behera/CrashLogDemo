//
//  waAppDelegate.h
//  CrashLogDemo
//
//  Created by Jayaprada Behera on 7/15/13.
//  Copyright (c) 2013 Webileapps. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

@class waViewController;

@interface waAppDelegate : UIResponder <UIApplicationDelegate,UIAlertViewDelegate,MFMailComposeViewControllerDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) waViewController *viewController;

@end
