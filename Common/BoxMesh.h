//
//  BoxMesh.h
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Mesh.h"

@interface BoxMesh: Mesh

- (instancetype) initWithDimensions:(vector_float3)dimensions
                      inwardNormals:(BOOL)isSkybox
                             device:(id<MTLDevice>)device;

@end
