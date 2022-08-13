//
//  SphereMesh.m
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import "SphereMesh.h"

@interface SphereMesh()

// This property was declared as readonly in Mesh.h
// Must be re-declared here
@property (nonatomic, readwrite) MTKMesh* metalKitMesh;
@property (nonatomic, readwrite) MTLVertexDescriptor* metalKitVertexDescriptor;

@end

@implementation SphereMesh

@synthesize metalKitMesh = _metalKitMesh;
@synthesize metalKitVertexDescriptor = _metalKitVertexDescriptor;


- (instancetype) initWithRadius:(NSUInteger)radius
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
        MDLVertexDescriptor* sphereMDLVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(_metalKitVertexDescriptor);
        sphereMDLVertexDescriptor.attributes[0].name = MDLVertexAttributePosition;
        sphereMDLVertexDescriptor.attributes[1].name = MDLVertexAttributeNormal;
        sphereMDLVertexDescriptor.attributes[2].name = MDLVertexAttributeTextureCoordinate;

        MTKMeshBufferAllocator* allocator = [[MTKMeshBufferAllocator alloc] initWithDevice: device];

        MDLMesh *sphereMDLMesh = [MDLMesh newEllipsoidWithRadii:(vector_float3){radius, radius, radius}
                                                 radialSegments:500
                                               verticalSegments:500
                                                   geometryType:MDLGeometryTypeTriangles
                                                  inwardNormals:NO
                                                     hemisphere:NO
                                                      allocator:allocator];
        sphereMDLMesh.vertexDescriptor = sphereMDLVertexDescriptor;

        NSError *nsErr = nil;
        _metalKitMesh = [[MTKMesh alloc] initWithMesh:sphereMDLMesh
                                                  device:device
                                                   error:&nsErr];
    }

    return self;
}

@end
