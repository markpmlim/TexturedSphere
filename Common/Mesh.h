//
//  Mesh.m
//  TexturedSphere-iOS
//
//  Created by Mark Lim Pak Mun on 15/07/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>

@interface Submesh : NSObject

@property (nonatomic, readonly, nonnull) MTKSubmesh *metalKitSubmmesh;

@end

@interface Mesh : NSObject

@property (nonatomic, readonly, nonnull) MTKMesh *metalKitMesh;
@property (nonatomic, readonly, nonnull) NSArray<Submesh*> *submeshes;
@property (nonatomic, readonly, nonnull) MTLVertexDescriptor* metalKitVertexDescriptor;

@end
