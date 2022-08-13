//
//  main.m
//  StarterObjC
//
//  Created by Mark Lim on 08/07/2022.
//  Copyright 2022 Incremental Innovation. All rights reserved.
//
#import <TargetConditionals.h>

#if (TARGET_OS_IOS || TARGET_OS_TV)
#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#else
#import <AppKit/AppKit.h>
#endif

#if (TARGET_OS_IOS || TARGET_OS_TV)
int main(int argc, char *argv[]) {

    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

#elif TARGET_OS_MAC
int main(int argc, char *argv[]) {
    return NSApplicationMain(argc,  (const char **) argv);
}
#endif

