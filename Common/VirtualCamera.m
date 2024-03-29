//
//  VirtualCamera.m
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 30/07/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import "VirtualCamera.h"

@implementation VirtualCamera
{
@public
    matrix_float4x4 _viewMatrix;
    simd_quatf _orientation;
    BOOL _dragging;

@private
    // These are private
    float _sphereRadius;
    CGSize _screenSize;

    // Use to compute the viewmatrix
    vector_float3 _eye;
    vector_float3 _target;
    vector_float3 _up;

    vector_float3 _startPoint;
    vector_float3 _endPoint;
    simd_quatf _previousQuat;
    simd_quatf _currentQuat;
}

- (instancetype)initWithScreenSize:(CGSize)size
{
    self = [super init];
    if (self != nil) {
        _screenSize = size;
        _sphereRadius = 1.0f;

        _viewMatrix = matrix_identity_float4x4;
        _eye = vector_make(0.0f, 0.0f, -3.0f);
        _target = vector_make(0.0f, 0.0f, 0.0f);
        _up =  vector_make(0.0f, 1.0f, 0.0f);
        [self updateViewMatrix];

        // Initialise to a quaternion identity.
        _orientation  = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
        _previousQuat = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
        _currentQuat  = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);

        _startPoint = vector_make(0,0,0);
        _endPoint = vector_make(0,0,0);
    }
    return self;
}

- (void)setPosition:(vector_float3)position
{
    _eye = position;
    [self updateViewMatrix];
}

// The simd library function simd_quaternion(from, to) will compute
//  correctly if the angle between the 2 vectors is less than 90 degrees.
// Returns a rotation quaternion such that q*u = v
// Tutorial 17 RotationBetweenVectors quaternion_utils.cpp
- (simd_quatf)rotationBetweenVector:(vector_float3)from
                          andVector:(vector_float3)to
{
    vector_float3 u = simd_normalize(from);
    vector_float3 v = simd_normalize(to);

    // Angle between the 2 vectors
    float cosTheta = simd_dot(u, v);
    vector_float3 rotationAxis;
    //float angle = acosf(cosTheta);
    //printf("angle:%f\n", degrees_from_radians(angle));
    if (cosTheta < -1 + 0.001f) {
        // Special case when vectors in opposite directions:
        //  there is no "ideal" rotation axis.
        // So guess one; any will do as long as it's perpendicular to u
        rotationAxis = simd_cross(vector_make(0.0f, 0.0f, 1.0f), u);
        float length2 = simd_dot(rotationAxis, rotationAxis);
        if ( length2 < 0.01f ) {
            // Bad luck, they were parallel, try again!
            rotationAxis = simd_cross(vector_make(1.0f, 0.0f, 0.0f), u);
        }

        rotationAxis = simd_normalize(rotationAxis);
        return simd_quaternion(radians_from_degrees(180.0f), rotationAxis);
    }

    // Compute rotation axis which is perpendicular to the plane of u and v.
    rotationAxis = simd_cross(u, v);

    // The "rotationAxis" is not a unit vector even though u and v
    // are unit vectors. It must be normalised.

    rotationAxis = simd_normalize(rotationAxis);
    // Normalising the "rotationAxis" and using it to instantiate a
    // quaternion will be produce a unit quaternion (magnitude 1.0)
    // which is a rotation quaternion.
    // Note: there is a "-" sign before the angle.
    simd_quatf q = simd_quaternion(-acosf(cosTheta), rotationAxis);
    return q;
}


- (void)updateViewMatrix {
    // Metal follows the left hand rule with +z direction into the screen.
    _viewMatrix = matrix_look_at_left_hand(_eye,
                                           _target,
                                           _up);
}

- (void)update:(float)duration
{
    _orientation = _currentQuat;
    [self updateViewMatrix];
}

// Handle resize.
- (void)resizeWithSize:(CGSize)newSize
{
    _screenSize = newSize;
}

/*
 Project the mouse coords on to a hemisphere of radius 1.0 units.
 Returns the 3D projected point on the hemisphere.
 */
- (vector_float3)projectMouseX:(float)x
                          andY:(float)y
{
    vector_float3 point = vector_make(x, y, 0);
    float d = x*x + y*y;
    float rr = _sphereRadius * _sphereRadius;
    if(d <= (0.5f * rr)) {
        //printf("hemisphere\n");
        // Inside the hemisphere. Compute the z-coord using the function:
        //      z = sqrt(r^2 - (x^2 + y^2))
        point.z = sqrtf(rr - d);
    }
    else {
        // Compute z-coord first using the hyperbolic function:
        //      z = (r^2 / 2) / sqrt(x^2 + y^2)
        // Reference: trackball.c by Gavin Bell at SGI
        //printf("hyperbola\n");
        point.z = 0.5f * rr / sqrtf(d);

    /*
         Scale x and y down, so the projected 3D position can be on the hemisphere.
         If the equation of a sphere is:
                r^2 = x^2 + y^2 + z^2
         with its centre at (0,0,0), then
         let y = ax => x^2 + (ax)^2 + z^2 = r^2
                    => x^2(1 + a^2) = r^2 - z^2
                    => x = sqrt((r^2 - z^2) / (1 + a^2)

        Reference: trackball.cpp by Song Ho Ahn
    */
        float x2, y2, a;
        if(x == 0.0f) {
            // avoid dividing by 0
            x2 = 0.0f;
            // Since x = 0, then
            //    y^2 + z^2 = r^2
            // => y^2 = r^2 - z^2
            // => y = sqrt(r^2 - z^2)
            y2 = sqrtf(rr - point.z*point.z);
            if(y < 0)       // correct sign
                y2 = -y2;
        }
        else {
            //printf("x != 0\n");
            a = y / x;
            x2 = sqrtf((rr - point.z*point.z) / (1 + a*a));
            if(x < 0) {  // correct sign
                x2 = -x2;
            }
            y2 = a * x2;
        }
        // x2, y2 is always >= 0
        point.x = x2;
        point.y = y2;
    }
    return point;
}

// Handle mouse interactions.

/*
 NB. The origin of an iPhone display is at the upper left corner.
 whereas the origin of a macOS display is at the lower left corner.

 The new origin is at the centre of the display.
 We must re-map the mouse location (or touch location) wrt the new origin.
 and the range for both the x-coord and y-coord are [-1.0, 1.0]
 */

// Response to a mouse down or a UIGestureRecognizerStateBegan
- (void)startDraggingFromPoint:(CGPoint)point
{
    self.dragging = YES;
    // Range of mouseX: [-1.0, 1.0]
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
#if TARGET_OS_IOS
    // Invert the y-coordinate
    // Range of mouseY: [-1.0, 1.0]
    float mouseY = (_screenSize.height - 2*point.y )/_screenSize.height;
#else
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
#endif
    _startPoint = [self projectMouseX:mouseX
                                 andY:mouseY];
    // Save it for the mouse dragged
    _previousQuat = _currentQuat;
}

// Respond to a mouse dragged or a UIGestureRecognizerStateChanged
- (void)dragToPoint:(CGPoint)point
{
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
#if TARGET_OS_IOS
    float mouseY = (_screenSize.height - 2*point.y)/_screenSize.height;
#else
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
#endif
    _endPoint = [self projectMouseX:mouseX
                               andY:mouseY];
    simd_quatf delta = [self rotationBetweenVector:_startPoint
                                         andVector:_endPoint];
    _currentQuat = simd_mul(delta, _previousQuat);
}

// Response to a mouse up or a UIGestureRecognizerStateEnded
- (void)endDrag
{
    self.dragging = NO;
    _previousQuat = _currentQuat;
    _orientation = _currentQuat;
}

// Assume only a mouse with 1 scroll wheel.
- (void)zoomInOrOut:(float)amount
{
    static float kmouseSensitivity = 0.1;
    vector_float3 pos = _eye;
    // Metal follows the left hand rule with +z direction into the screen.
    // KIV. mouseSensitivity?
    float z = pos.z + amount*kmouseSensitivity;
    if (z <= -8.0f) {
        z = -8.0f;
    }
    else if (z >= -3.0f) {
        z = -3.0f;
    }
    _eye = vector_make(0.0, 0.0, z);
    self.position = _eye;
}

@end
