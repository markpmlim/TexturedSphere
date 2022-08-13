//
//  VirtualCamera.h
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import <TargetConditionals.h>
#if (TARGET_OS_IOS || TARGET_OS_TV)
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

#import "AAPLMathUtilities.h"

#define kRADIUS_SCALE 0.5

@interface VirtualCamera : NSObject

- (nonnull instancetype) initWithScreenSize:(CGSize)size;

- (simd_quatf) rotationBetweenVector:(vector_float3)from
                          andVector:(vector_float3)to;

- (void) update:(float)duration;

- (void) resizeWithSize:(CGSize)newSize;

- (void) startMove:(CGPoint)point;

- (void) moveToPoint:(CGPoint)point;

- (void) endMove;

- (void) scroll:(float)amount;

@property (nonatomic) vector_float3 position;
@property (nonatomic) matrix_float4x4 viewMatrix;
@property (nonatomic) vector_float3 eulerAngles;
@property (nonatomic) simd_quatf orientation;
@property (nonatomic, getter=isMoving) BOOL moving;

@end
