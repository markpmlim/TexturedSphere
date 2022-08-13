/*
 MTKTextureLoader+HDR.h
 TexturedSphere

 A simple extension to load High Dynamic Range (.hdr) images.
 */


#import <simd/simd.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MTKTextureLoader (HDR)
/// As a source of HDR input, renderer leverages radiance (.hdr) files.
///  This helper method provides a radiance file
/// loaded into an MTLTexture given a source file name
/// Can throw when called from Swift.

- (id<MTLTexture> _Nullable) newTextureFromRadianceFile:(NSString *_Nullable)fileName
                                                  error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
