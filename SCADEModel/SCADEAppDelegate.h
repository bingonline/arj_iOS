//
//  SCADEAppDelegate.h
//  SCADEModel
//
//  Created by Dev Apple on 19/03/13.
//  Copyright (c) 2013 Esterel Technologies. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>

@class SCADEViewController;

@interface SCADEAppDelegate : UIResponder <UIApplicationDelegate>{
    CMMotionManager *cmMotionManager;
}

@property (readonly) CMMotionManager *cmMotionManager;

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) SCADEViewController *viewController;

@end
