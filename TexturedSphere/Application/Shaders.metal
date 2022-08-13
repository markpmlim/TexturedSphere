/*
 Shaders.metal
 TexturedSphere
 
 Created by Mark Lim Pak Mun on 13/08/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.
 
 */

#include <metal_stdlib>

using namespace metal;

#import "ShaderTypes.h"

typedef struct {
    float4 clip_pos [[position]];
    float2 uv;
} ScreenFragment;

/*
 No geometry are passed to this vertex shader; the range of vid: [0, 2]
 The position and texture coordinates attributes of 3 vertices are
 generated on the fly.
 clip_pos: (-1.0, -1.0), (-1.0,  3.0), (3.0, -1.0)
       uv: ( 0.0,  1.0), ( 0.0, -1.0), (2.0,  1.0)
 The area of the generated triangle covers the entire 2D clip-space.
 Note: any geometry rendered outside this 2D space is clipped.
 Clip-space:
 Range of position: [-1.0, 1.0]
       Range of uv: [ 0.0, 1.0]
 The origin of the uv axes starts at the top left corner of the
   2D clip space with u-axis from left to right and
   v-axis from top to bottom
 For the mathematically inclined, the equation of the line joining
 the 2 points (-1.0,  3.0), (3.0, -1.0) is
        y = -x + 2
 The point (1.0, 1.0) lie on this line. The other 3 points which make up
 the 2D clipspace lie on the lines x=-1 or x=1 or y=-1 or y=1
 */

vertex ScreenFragment
vertexShader(uint vid [[vertex_id]]) {
    // from "Vertex Shader Tricks" by AMD - GDC 2014
    ScreenFragment out;
    out.clip_pos = float4((float)(vid / 2) * 4.0 - 1.0,
                          (float)(vid % 2) * 4.0 - 1.0,
                          0.0,
                          1.0);
    out.uv = float2((float)(vid / 2) * 2.0,
                    1.0 - (float)(vid % 2) * 2.0);
    return out;
}

/*
 The range of uv: [0.0, 1.0]
 The origin of the Metal texture coord system is at the upper-left of the quad.
 */
fragment half4
fragmentShader(ScreenFragment  in  [[stage_in]],
               texture2d<half> tex [[texture(0)]]) {

    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear);

    half4 out_color = tex.sample(textureSampler, in.uv);
    return out_color;
}


constant float2 invAtan = float2(1/(2*M_PI_F), 1/M_PI_F);   // 1/2π, 1/π
// Working as expected.
float2 sampleSphericalMap(float3 direction) {

    // Original code:
    //      tan(θ) = dir.z/dir.x and sin(φ) = dir.y/1.0
    float2 uv = float2(atan2(direction.x, direction.z),
                       asin(-direction.y));

    // The range of u: [ -π,   π ] --> [-0.5, 0.5]
    // The range of v: [-π/2, π/2] --> [-0.5, 0.5]
    uv *= invAtan;
    uv += 0.5;          // [0, 1] for both uv.x & uv.y

    return uv;
}

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct MappingVertex {
    float4 position [[position]];       // clip space
    float4 worldPosition;
    uint whichLayer [[render_target_array_index]];
};

vertex MappingVertex
cubeMapVertexShader(VertexIn                vertexIn        [[stage_in]],
                    unsigned int            instanceId      [[instance_id]],
                    device InstanceParams *instanceParms    [[buffer(1)]])
{
    float4 position = float4(vertexIn.position, 1.0);
    
    MappingVertex outVert;
    // Transform vertex's position into clip space.
    outVert.position = instanceParms[instanceId].viewProjectionMatrix * position;
    // Its position (in object/model space) will be used to access the equiRectangular map texture.
    // Since there is no model matrix, its vertex position is deemed to be in world space.
    // Another way of looking at things is we may consider that the model matrix is the identity matrix.
    outVert.worldPosition = position;
    outVert.whichLayer = instanceId;
    return outVert;
}

// Render to an offscreen texture object in this case a 2D texture.
fragment half4
outputCubeMapTexture(MappingVertex      mappingVertex   [[stage_in]],
                     texture2d<half> equirectangularMap [[texture(0)]]) {

    constexpr sampler mapSampler(s_address::clamp_to_edge,  // default
                                 t_address::clamp_to_edge,
                                 mip_filter::linear,
                                 mag_filter::linear,
                                 min_filter::linear);

    // Magnitude of direction is 1.0 upon normalization.
    float3 direction = normalize(mappingVertex.worldPosition.xyz);
    float2 uv = sampleSphericalMap(direction);
    half4 color = equirectangularMap.sample(mapSampler, uv);
    return color;
}

struct VertexOut {
    float4 position [[position]];   // clip space
    float4 texCoords;               // direction vector
};

vertex VertexOut
SphereVertexShader(VertexIn         vertexIn    [[stage_in]],
                   constant Uniforms &uniforms  [[buffer(1)]]) {

    // The position and normal of the incoming vertex in Model Space.
    // The w-component of position vectors should be set to 1.0
    float4 positionMC = float4(vertexIn.position, 1.0);
    // Transform vertex's position from model coordinates to world coordinates.
    float4 positionWC = uniforms.modelMatrix * positionMC;

    VertexOut vertexOut;
    // The vector from the sphere's origin to any point on its surface can
    //  can be used as a 3D vector to access the cubemap texture.
    vertexOut.texCoords = float4(vertexIn.position, 0.0f);

    // The normal vector can also be used since it is the normalized
    //  vector of the vertex's position attribute.
    // Normal is a vector; its w-component should be set 0.0
    float4 normalMC = float4(vertexIn.normal, 0.0);
    //vertexOut.texCoords = normalMC;

    // Transform incoming vertex's position into clip space
    vertexOut.position = uniforms.projectionMatrix * uniforms.viewMatrix * positionWC;
    return vertexOut;
}

// The Uniforms are not used but have been declared.
fragment half4
CubeLookupShader(VertexOut fragmentIn               [[stage_in]],
                 texturecube<float> cubemapTexture  [[texture(0)]],
                 constant Uniforms & uniforms       [[buffer(1)]])
{
    constexpr sampler cubeSampler(mip_filter::linear,
                                  mag_filter::linear,
                                  min_filter::linear);
    // Have to flip horizontally anymore.
   
    float3 texCoords = float3(fragmentIn.texCoords.x, fragmentIn.texCoords.y, -fragmentIn.texCoords.z);
    texCoords = normalize(texCoords);
    return half4(cubemapTexture.sample(cubeSampler, texCoords));
}


// The Uniforms are not used but to be declared.
fragment float4
SphereLookupShader(VertexOut fragmentIn               [[stage_in]],
                   texture2d<half> equirectangularMap [[texture(0)]],
                   constant Uniforms & uniforms       [[buffer(1)]])
{
    constexpr sampler mapSampler(s_address::clamp_to_edge,  // default
                                 t_address::clamp_to_edge,
                                 mip_filter::linear,
                                 mag_filter::linear,
                                 min_filter::linear);
    // Have to flip horizontally.
    float3 direction = float3(fragmentIn.texCoords.x, fragmentIn.texCoords.y, -fragmentIn.texCoords.z);
    direction = normalize(direction);
    float2 uv = sampleSphericalMap(direction);
    half4 color = equirectangularMap.sample(mapSampler, uv);
    return float4(color);
}

