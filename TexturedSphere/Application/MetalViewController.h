/*
 MetalViewController.h
 TexturedSphere
 
 Created by Mark Lim Pak Mun on 13/08/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.
*/

#import <TargetConditionals.h>
#if TARGET_OS_IOS 
@import UIKit;
#define PlatformViewController UIViewController
#else
@import AppKit;
#define PlatformViewController NSViewController
#endif

@import MetalKit;

#import "MetalRenderer.h"

@interface MetalViewController : PlatformViewController

@end
