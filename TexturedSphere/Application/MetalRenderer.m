/*
 MetalRenderer.m
 TexturedSphere
 
 Created by Mark Lim Pak Mun on 13/08/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

// Set to 1 iff device supports Layered Rendering
#define usesCubemapTexture 0

@import simd;
@import ModelIO;
@import MetalKit;
#import <TargetConditionals.h>
#import "MetalRenderer.h"
#import "AAPLMathUtilities.h"
#import "SphereMesh.h"
#import "BoxMesh.h"
#import "MTKTextureLoader+HDR.h"
#import "VirtualCamera.h"

#include "ShaderTypes.h"


typedef NS_OPTIONS(NSUInteger, ImageSize) {
    QtrK    = 256,
    HalfK   = 512,
    OneK    = 1024,
    TwoK    = 2048,
    ThreeK  = 3072,
    FourK   = 4096,
};


/// Main class that performs the rendering.
@implementation MetalRenderer {
    id<MTLDevice> _device;
    MTKView* _mtkView;

    id<MTLCommandQueue> _commandQueue;

    id<MTLRenderPipelineState> _sphereRenderPipelineState;
    MTLRenderPassDescriptor* _renderPassDescriptor;

    id<MTLRenderPipelineState> _renderToCubemapTexturePipelineState;
    MTLRenderPassDescriptor* _offScreenRenderPassDescriptor;
    id<MTLBuffer> _uniformsBuffers;
    id<MTLTexture> _cubemapTexture;
    id<MTLTexture> _renderTargetDepthTexture;

    id<MTLTexture> _equiRectangularTexture;

    id<MTLDepthStencilState> _sphereDepthStencilState;
    id<MTLTexture> _depthTexture;

    SphereMesh* _sphereMesh;
    BoxMesh* _cubeMesh;
    CGFloat _cubeSize;

    VirtualCamera* _camera;

    matrix_float4x4 _projectionMatrix;
}

/// Initialize the renderer with the MetalKit view that references the Metal device you render with.
/// You also use the MetalKit view to set the pixel format and other properties of the drawable.
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        _mtkView = mtkView;
       _commandQueue = [_device newCommandQueue];
 
        NSString* name = @"EquiRectImage.hdr";
        _equiRectangularTexture = [self loadTextureWithContentsOfFile:name
                                                                isHDR:YES];
        _sphereMesh = [[SphereMesh alloc] initWithRadius:1.0
                                                  device:_device];
        // "inwardNormals" must be set to be true.
        _cubeMesh = [[BoxMesh alloc] initWithDimensions:(vector_float3){2.0, 2.0, 2.0}
                                          inwardNormals:YES
                                                 device:_device];
        _cubeSize = HalfK;
        [self buildPipelineStates];
        [self buildResources];

#if usesCubemapTexture
        // Set the common size of each of the 2D face of the cube texture here.
        [self renderToCubemapTexture:_cubemapTexture
                            faceSize:_cubeSize];
#endif
        _camera = [[VirtualCamera alloc] initWithScreenSize:_mtkView.drawableSize];
    }

    return self;
}

-(id<MTLTexture>) loadTextureWithContentsOfFile:(NSString *)name
                                          isHDR:(BOOL)isHDR {
    MTKTextureLoader* textureLoader = [[MTKTextureLoader alloc] initWithDevice:_device];
    id<MTLTexture> mtlTexture;
    if (isHDR == YES) {
        NSError *error = nil;
         mtlTexture = [textureLoader newTextureFromRadianceFile:name
                                                          error:&error];
        if (error != nil) {
            NSLog(@"Can't load hdr file:%@", error);
            exit(1);
        }
    }
    else {
        // place holder
    }
    return mtlTexture;
}

- (void) buildPipelineStates {
    id<MTLLibrary> library = [_device newDefaultLibrary];
    // Load the vertex function from the library
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"SphereVertexShader"];
#if usesCubemapTexture
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"CubeLookupShader"];
#else
    // Load the fragment function from the library
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"SphereLookupShader"];
#endif
    // Create a reusable pipeline state
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = @"Render Sphere Pipeline";
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = _mtkView.depthStencilPixelFormat;
    // We are texturing a sphere.
    pipelineDescriptor.vertexDescriptor = _sphereMesh.metalKitVertexDescriptor;

    NSError *error = nil;
    _sphereRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                             error:&error];
    if (!_sphereRenderPipelineState) {
        NSLog(@"Failed to create create render pipeline state, error %@", error);
    }

    //////////
    // Set up a cube texture for rendering to and sampling from
    MTLTextureDescriptor *cubeMapDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:MTLPixelFormatRGBA16Float
                                                                                              size:_cubeSize
                                                                                         mipmapped:NO];
#if (TARGET_OS_IOS || TARGET_OS_TV)
    cubeMapDesc.storageMode = MTLStorageModeShared;
#else
    cubeMapDesc.storageMode = MTLStorageModeManaged;
#endif
    cubeMapDesc.usage       = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;

    _cubemapTexture = [_device newTextureWithDescriptor:cubeMapDesc];
    MTLTextureDescriptor *cubeMapDepthDesc = [MTLTextureDescriptor textureCubeDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                                   size:_cubeSize
                                                                                              mipmapped:NO];
    cubeMapDepthDesc.storageMode = MTLStorageModePrivate;
    cubeMapDepthDesc.usage       = MTLTextureUsageRenderTarget;
    _renderTargetDepthTexture    = [_device newTextureWithDescriptor:cubeMapDepthDesc];

    // Reuse the above descriptor object and change properties that differ.
    pipelineDescriptor.label = @"Offscreen Render Pipeline";
    pipelineDescriptor.sampleCount = 1;
    pipelineDescriptor.vertexFunction = [library newFunctionWithName:@"cubeMapVertexShader"];
    pipelineDescriptor.fragmentFunction = [library newFunctionWithName:@"outputCubeMapTexture"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    pipelineDescriptor.vertexDescriptor = _cubeMesh.metalKitVertexDescriptor;
    pipelineDescriptor.inputPrimitiveTopology = MTLPrimitiveTopologyClassTriangle;
    _renderToCubemapTexturePipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor
                                                                            error:&error];
    if (_renderToCubemapTexturePipelineState == nil) {
        NSLog(@"Failed to create render to texture pipeline state:%@", error);
    }

    // If we intend to save a generated texture, then an offscreen render is necessary.
    _offScreenRenderPassDescriptor = [MTLRenderPassDescriptor new];
    _offScreenRenderPassDescriptor.colorAttachments[0].loadAction  = MTLLoadActionClear;
    _offScreenRenderPassDescriptor.colorAttachments[0].clearColor  = MTLClearColorMake(1, 1, 1, 1);
    _offScreenRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    _offScreenRenderPassDescriptor.depthAttachment.clearDepth      = 1.0;
    _offScreenRenderPassDescriptor.depthAttachment.loadAction      = MTLLoadActionClear;
    _offScreenRenderPassDescriptor.colorAttachments[0].texture     = _cubemapTexture;
    _offScreenRenderPassDescriptor.depthAttachment.texture         = _renderTargetDepthTexture;
    // Requires iOS 12.x
    _offScreenRenderPassDescriptor.renderTargetArrayLength         = 6;

}

// We will not be using triple buffering.
- (void) buildResources {
    _uniformsBuffers = [_device newBufferWithLength:sizeof(Uniforms)
                                            options:MTLResourceStorageModeShared];
}

-(id<MTLDepthStencilState>) buildDepthStencilStateWithDevice:(id<MTLDevice>)device
                                              isWriteEnabled:(BOOL)flag {

    MTLDepthStencilDescriptor* depthStencilDescriptor = [[MTLDepthStencilDescriptor init] alloc];
    depthStencilDescriptor.depthCompareFunction = MTLCompareFunctionLess;
    depthStencilDescriptor.depthWriteEnabled = flag;
    return [device newDepthStencilStateWithDescriptor:depthStencilDescriptor];
}

- (void) buildDepthBuffer {
    CGSize drawableSize = _mtkView.drawableSize;
    MTLTextureDescriptor* depthTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float
                                                                                            width:drawableSize.width
                                                                                           height:drawableSize.height
                                                                                            mipmapped:NO];
    depthTexDesc.resourceOptions = MTLResourceStorageModePrivate;
    depthTexDesc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    _depthTexture = [_device newTextureWithDescriptor:depthTexDesc];
}

/*
 The parameter "texture" must be an instance of MTLTextureTypeCube
 We assume a virtual camera is placed at the origin of the cube;
  the forward direction of the camera is pointing at the centre of +Z face and
  its up direction pointing at the centre of +Y face.
 The camera will be rotated to capture 6 views.
 */
- (void) renderToCubemapTexture:(id<MTLTexture>)texture
                       faceSize:(CGFloat)size {

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    _offScreenRenderPassDescriptor.colorAttachments[0].texture = texture;

    matrix_float4x4 captureProjectionMatrix = matrix_perspective_left_hand(radians_from_degrees(90),
                                                                           1.0,
                                                                           0.1, 10.0);
    matrix_float4x4 captureViewMatrices[6];
    // We start by first rotating the virtual camera +90 degrees about the y-axis. (yaw)
    captureViewMatrices[0] = matrix_look_at_left_hand(vector_make(0, 0, 0),     // eye is at the origin of the cube.
                                                      vector_make(1, 0, 0),     // centre of +X face
                                                      vector_make(0, 1, 0));    // Up

    // The camera is rotated -90 degrees about the y-axis. (yaw)
    captureViewMatrices[1] = matrix_look_at_left_hand(vector_make( 0, 0, 0),
                                                      vector_make(-1, 0, 0),    // centre of -X face
                                                      vector_make( 0, 1, 0));
    
    // The camera is rotated -90 degrees about the x-axis. (pitch)
    captureViewMatrices[2] = matrix_look_at_left_hand(vector_make(0, 0,  0),
                                                      vector_make(0, 1,  0),    // centre of +Y face
                                                      vector_make(0, 0, -1));

    // We rotate the camera  is rotated +90 degrees about the x-axis. (pitch)
    captureViewMatrices[3] = matrix_look_at_left_hand(vector_make( 0,  0, 0),
                                                      vector_make( 0, -1, 0),   // centre of -Y face
                                                      vector_make( 0,  0, 1));

    // The camera is now at its initial position pointing in the +z direction.
    // The up vector of the camera is pointing in the +y direction.
    captureViewMatrices[4] = matrix_look_at_left_hand(vector_make(0, 0, 0),
                                                      vector_make(0, 0, 1),     // centre of +Z face
                                                      vector_make(0, 1, 0));

    // The camera is rotated +180 (-180) degrees about the y-axis. (yaw)
    captureViewMatrices[5] = matrix_look_at_left_hand(vector_make(0, 0,  0),
                                                      vector_make(0, 0, -1),    // centre of -Z face
                                                      vector_make(0, 1,  0));
    // Allocate memory for an InstanceParams object. This buffer is divided into
    //  6 memory blocks each of size InstanceParams which is the size of a matrix_float4x4
    // KIV: Align on 256 block boundary?
    id<MTLBuffer> instanceParmsBuffer = [_device newBufferWithLength:sizeof(InstanceParams) * 6
                                                             options:MTLResourceStorageModeShared];
    void *bufferPointer = instanceParmsBuffer.contents;
    matrix_float4x4 viewProjectionMatrix;
    for (int i=0; i<6; i++) {
        viewProjectionMatrix = matrix_multiply(captureProjectionMatrix,
                                               captureViewMatrices[i]);
        //NSLog(@"%p", bufferPointer + sizeof(InstanceParams) * i);
        memcpy(bufferPointer + sizeof(InstanceParams) * i,
               &viewProjectionMatrix,
               sizeof(InstanceParams));
    }
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer) {
        MTLCommandBufferStatus status = buffer.status;
        if (status == MTLCommandBufferStatusError) {
            NSError *error = buffer.error;
            NSLog(@"Command Buffer Error %@", error);
            return;
        }
        if (status == MTLCommandBufferStatusCompleted) {
            NSLog(@"Rendering to the texture was successfully completed");
            // We can do something within this block of code.
        #if (TARGET_OS_IOS || TARGET_OS_TV)
            CFTimeInterval executionDuration = buffer.GPUEndTime - buffer.GPUStartTime;
            NSLog(@"Execution Time to render: %f s", executionDuration);
        #endif
        }
    }];


    id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:_offScreenRenderPassDescriptor];
    //NSLog(@"%@", _offScreenRenderPassDescriptor);

    renderEncoder.label = @"Offscreen Render Pass";
    [renderEncoder setRenderPipelineState:_renderToCubemapTexturePipelineState];
    // The following 2 statements are important.
    MTLViewport viewPort = {0, 0,
                            size, size,
                            0, 1};
    [renderEncoder setViewport:viewPort];
    [renderEncoder setFrontFacingWinding:MTLWindingClockwise];
    [renderEncoder setCullMode:MTLCullModeBack];
    // We expect the cube mesh consists of only one vertexBuffer.
    [renderEncoder setVertexBuffer:instanceParmsBuffer
                            offset:0
                           atIndex:1];
    [renderEncoder setFragmentTexture:_equiRectangularTexture
                              atIndex:0];
    // Set mesh's vertex buffers
    MTKMesh *mtkMesh = _cubeMesh.metalKitMesh;
    for (NSUInteger bufferIndex = 0; bufferIndex < mtkMesh.vertexBuffers.count; bufferIndex++) {
        MTKMeshBuffer *vertexBuffer = mtkMesh.vertexBuffers[bufferIndex];
        if ((NSNull *)vertexBuffer != [NSNull null]) {
            [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                    offset:vertexBuffer.offset
                                   atIndex:bufferIndex];
        }
    }

    NSArray<MTKSubmesh *> *mtkSubmesh = mtkMesh.submeshes;
    for (NSUInteger bufferIndex = 0; bufferIndex < mtkSubmesh.count; bufferIndex++) {
        MTKSubmesh *mtkSubmesh = mtkMesh.submeshes[bufferIndex];
        if ((NSNull *)mtkSubmesh != [NSNull null]) {
            [renderEncoder drawIndexedPrimitives:mtkSubmesh.primitiveType
                                      indexCount:mtkSubmesh.indexCount
                                       indexType:mtkSubmesh.indexType
                                     indexBuffer:mtkSubmesh.indexBuffer.buffer
                               indexBufferOffset:mtkSubmesh.indexBuffer.offset
                                   instanceCount:6
                                      baseVertex:0
                                    baseInstance:0];
        }
    }

    [renderEncoder endEncoding];
    [commandBuffer commit];
    // Calling waitUntilCompleted blocks the CPU thread until the
    //  render-into-a-texture operation is complete on the GPU.
    //[commandBuffer waitUntilCompleted];
}

// This is called whenever there is a change in the view size.
- (void) mtkView:(nonnull MTKView *)view
drawableSizeWillChange:(CGSize)size {

    [self buildDepthBuffer];
    float aspectRatio = size.width / (float)size.height;
    _projectionMatrix = matrix_perspective_left_hand(radians_from_degrees(60),
                                                     aspectRatio,
                                                     0.1, 1000);
    [_camera resizeWithSize:size];
}



/// Called whenever the view needs to render.
- (void) drawInMTKView:(nonnull MTKView *)view {

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = @"Command Buffer";

    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;

    if (view.currentDrawable != nil) {
        CGSize drawableSize = view.currentDrawable.layer.drawableSize;
        if (drawableSize.width != (CGFloat)_depthTexture.width ||
            drawableSize.height != (CGFloat)_depthTexture.height) {
            [self buildDepthBuffer];
        }

        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDescriptor.depthAttachment.texture = _depthTexture;
        renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
        renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionDontCare;
        renderPassDescriptor.depthAttachment.clearDepth = 1.0;

        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [_camera update:view.preferredFramesPerSecond];

        // Convert the camera's orientation to a matrix
        matrix_float4x4 sphereModelMatrix = simd_matrix4x4(_camera.orientation);
        Uniforms uniforms = (Uniforms){ _projectionMatrix,
                                        _camera.viewMatrix,
                                        sphereModelMatrix};
        void* bufferPtr = _uniformsBuffers.contents;
        memcpy(bufferPtr, &uniforms, sizeof(Uniforms));

        [renderEncoder setRenderPipelineState:_sphereRenderPipelineState];
        [renderEncoder setFrontFacingWinding:MTLWindingClockwise];
        [renderEncoder setCullMode:MTLCullModeBack];
        // Set mesh's vertex buffers
        MTKMesh *mtkMesh = _sphereMesh.metalKitMesh;
        for (NSUInteger bufferIndex = 0; bufferIndex < mtkMesh.vertexBuffers.count; bufferIndex++) {
            MTKMeshBuffer *vertexBuffer = mtkMesh.vertexBuffers[bufferIndex];
            if ((NSNull *)vertexBuffer != [NSNull null]) {
                [renderEncoder setVertexBuffer:vertexBuffer.buffer
                                        offset:vertexBuffer.offset
                                       atIndex:bufferIndex];
            }
        }

        [renderEncoder setVertexBuffer:_uniformsBuffers
                                offset:0
                               atIndex:1];
#if usesCubemapTexture
        [renderEncoder setFragmentTexture:_cubemapTexture
                                  atIndex:0];
#else
        [renderEncoder setFragmentTexture:_equiRectangularTexture
                                  atIndex:0];
#endif
        NSArray<MTKSubmesh *> *mtkSubmesh = mtkMesh.submeshes;
        for (NSUInteger bufferIndex = 0; bufferIndex < mtkSubmesh.count; bufferIndex++) {
            MTKSubmesh *mtkSubmesh = mtkMesh.submeshes[bufferIndex];
            if ((NSNull *)mtkSubmesh != [NSNull null]) {
                [renderEncoder drawIndexedPrimitives:mtkSubmesh.primitiveType
                                          indexCount:mtkSubmesh.indexCount
                                           indexType:mtkSubmesh.indexType
                                         indexBuffer:mtkSubmesh.indexBuffer.buffer
                                   indexBufferOffset:mtkSubmesh.indexBuffer.offset];
            }
        }
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    }
}

@end
