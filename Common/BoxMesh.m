//
//  BoxMesh.m
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import "BoxMesh.h"

@interface BoxMesh()

// This property was declared as readonly in Mesh.h
// Must be re-declared here
@property (nonatomic, readwrite) MTKMesh* metalKitMesh;
@property (nonatomic, readwrite) MTLVertexDescriptor* metalKitVertexDescriptor;

@end

@implementation BoxMesh

@synthesize metalKitMesh = _metalKitMesh;
@synthesize metalKitVertexDescriptor = _metalKitVertexDescriptor;

- (instancetype) initWithDimensions:(vector_float3)dimensions
                      inwardNormals:(BOOL)isSkybox
                             device:(id<MTLDevice>)device {
    self = [super init];
    if (self != nil) {
        _metalKitVertexDescriptor = [[MTLVertexDescriptor alloc] init];
        _metalKitVertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
        _metalKitVertexDescriptor.attributes[0].offset = 0;
        _metalKitVertexDescriptor.attributes[0].bufferIndex = 0;
        _metalKitVertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
        _metalKitVertexDescriptor.attributes[1].offset = 3 * sizeof(float);
        _metalKitVertexDescriptor.attributes[1].bufferIndex = 0;
        _metalKitVertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
        _metalKitVertexDescriptor.attributes[2].offset = 6 * sizeof(float);
        _metalKitVertexDescriptor.attributes[2].bufferIndex = 0;
        _metalKitVertexDescriptor.layouts[0].stride = 8 * sizeof(float);
        _metalKitVertexDescriptor.layouts[0].stepRate = 1;
        _metalKitVertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

        // Indicate how each Metal vertex descriptor attribute maps to each Model I/O  attribute
        MDLVertexDescriptor* cubeMDLVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_metalKitVertexDescriptor);
        cubeMDLVertexDescriptor.attributes[0].name = MDLVertexAttributePosition;
        cubeMDLVertexDescriptor.attributes[1].name = MDLVertexAttributeNormal;
        cubeMDLVertexDescriptor.attributes[2].name = MDLVertexAttributeTextureCoordinate;

        MTKMeshBufferAllocator* allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: device];

        // If we use the geometry as a skybox, the parameter "isSkyBox" must be
        //  set to be true (YES).
        MDLMesh *cubeMDLMesh = [MDLMesh newBoxWithDimensions:dimensions
                                                    segments:(vector_uint3){1, 1, 1}
                                                geometryType:MDLGeometryTypeTriangles
                                               inwardNormals:isSkybox
                                                   allocator:allocator];
        cubeMDLMesh.vertexDescriptor = cubeMDLVertexDescriptor;

        NSError *nsErr = nil;

        _metalKitMesh = [[MTKMesh alloc] initWithMesh:cubeMDLMesh
                                                  device:device
                                                   error:&nsErr];
    }

    return self;
}

@end
