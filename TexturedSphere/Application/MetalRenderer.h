/*
 MetalRenderer.h
 TexturedSphere

 Created by Mark Lim Pak Mun on 13/08/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

#import <MetalKit/MetalKit.h>

@class VirtualCamera;

/// Platform-independent renderer class.
@interface MetalRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;

@property (nonatomic) VirtualCamera* _Nonnull camera;

@end
