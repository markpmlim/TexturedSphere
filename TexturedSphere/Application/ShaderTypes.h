//
//  ShaderTypes.h
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// size=64 bytes
typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 viewMatrix;
    matrix_float4x4 modelMatrix;
} Uniforms;

// size = 192 bytes
typedef struct {
    matrix_float4x4 viewProjectionMatrix;
} InstanceParams;

#endif /* ShaderTypes_h */
