//
//  VirtualCamera.m
//  TexturedSphere
//
//  Created by Mark Lim Pak Mun on 13/08/2022.
//  Copyright © 2022 mark lim pak mun. All rights reserved.
//

#import "VirtualCamera.h"

@implementation VirtualCamera {
    simd_quatf _orientation;
    matrix_float4x4 _viewMatrix;

    // Use to compute the viewmatrix
    vector_float3 _eye;
    vector_float3 _target;
    vector_float3 _up;

    float _sphereRadius;
    CGSize _screenSize;
    BOOL _moving;
    vector_float3 _startPoint;
    vector_float3 _endPoint;
    simd_quatf _previousQuat;
    simd_quatf _currentQuat;
}

- (instancetype) initWithScreenSize:(CGSize)size {
    self = [super init];
    if (self != nil) {
        _screenSize = size;
        _sphereRadius = 1.0f;

        _viewMatrix = matrix_identity_float4x4;
        _eye = vector_make(0.0f, 0.0f, -3.0f);
        _target = vector_make(0.0f, 0.0f, 0.0f);
        _up =  vector_make(0.0f, 1.0f, 0.0f);

        // Initialise to a quaternion identity.
        _orientation  = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
        _previousQuat = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);
        _currentQuat  = simd_quaternion(0.0f, 0.0f, 0.0f, 1.0f);

        _startPoint = vector_make(0,0,0);
        _endPoint = vector_make(0,0,0);
    }
    return self;
}

// Position of camera wrt to the centre of the scene.
- (void) setPosition:(vector_float3)position {
    _eye = position;
    [self updateViewMatrix];
}

/*
 The simd library function simd_quaternion(from, to) can be used to
  compute the rotation quaternion. But this function can only compute
  accurately if the angle between the 2 vectors is less than 90 degrees.

 This function can accept an angle of rotation of > 90 degrees
  between the 2 vectors.

 Returns a rotation quaternion such that q*u = v
 Tutorial 17 RotationBetweenVectors quaternion_utils.cpp
 */
-(simd_quatf) rotationBetweenVector:(vector_float3)from
                          andVector:(vector_float3)to {

    vector_float3 u = simd_normalize(from);
    vector_float3 v = simd_normalize(to);

    // Angle between the 2 vectors
    float cosTheta = simd_dot(u, v);
    vector_float3 rotationAxis;

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

    // Compute the rotation axis.
    rotationAxis = simd_cross(u, v);
    // Note: even though u and v are unit vectors, the magnitude of the
    //  vector "rotationAxis" is not likely to be 1.0 because the
    //  vectors u and v are not orthogonal.
    rotationAxis = simd_normalize(rotationAxis);
    // A unit quaternion is produced if the axis is normalised.
    // It can be used for applying a rotation to a 3D coordinate.
    simd_quatf q = simd_quaternion(acosf(cosTheta), rotationAxis);
    return q;
}


-(void) updateViewMatrix {
    // Metal follows the left hand rule with +z direction into the screen.
    _viewMatrix = matrix_look_at_left_hand(_eye,
                                           _target,
                                           _up);
}

- (void) update:(float)duration {
    _orientation = _currentQuat;
    [self updateViewMatrix];
}

// Handle resize of the view.
- (void) resizeWithSize:(CGSize)newSize {
    _screenSize = newSize;
}

/*
 Project the mouse coords on to a sphere of radius 1.0 units.
 Returns the 3D projected point on a sphere.
 */
- (vector_float3) projectMouseX:(float)x
                           andY:(float)y {
    
    vector_float3 point = vector_make(x, y, 0);
    float d = x*x + y*y;
    float rr = _sphereRadius * _sphereRadius;
    if(d <= (0.5f * rr)) {
        // Inside the sphere. Compute the z-coord using the function:
        //      z = sqrt(r^2 - (x^2 + y^2))
        point.z = sqrtf(rr - d);
    }
    else {
        // compute z-coord first using the hyperbolic function:
        //      z = (r^2 / 2) / sqrt(x^2 + y^2)
        // Reference: trackball.c by Gavin Bell at SGI
        point.z = 0.5f * rr / sqrtf(d);

    /*
         Scale x and y down, so the projected 3D position can be on the sphere.
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
            a = y / x;
            x2 = sqrtf((rr - point.z*point.z) / (1 + a*a));
            if(x < 0)   // correct sign
                x2 = -x2;
            y2 = a * x2;
        }
        point.x = x2;
        point.y = y2;
    }
    return point;
}

// Handle mouse interactions.

// Response to a mouse down.
- (void) startMove:(CGPoint)point {
    self.moving = YES;
    // The origin of a metal view is at the left bottom corner.
    // Remap so that the origin is at the centre of the view and
    //  the mouse coordinates (x,y) are in the range [-1.0, 1.0]
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
    _startPoint = [self projectMouseX:mouseX
                                 andY:mouseY];
    // save it for the mouse dragged
    _previousQuat = _currentQuat;
}

// Respond to a mouse dragged
- (void) moveToPoint:(CGPoint)point {
    float mouseX = (2*point.x - _screenSize.width)/_screenSize.width;
    float mouseY = (2*point.y - _screenSize.height)/_screenSize.height;
    _endPoint = [self projectMouseX:mouseX
                               andY:mouseY];
    simd_quatf delta = [self rotationBetweenVector:_startPoint
                                         andVector:_endPoint];

   // Rotate the quaternion "_previousQuat" by the quaternion "delta".
    _currentQuat = simd_mul(delta, _previousQuat);
}

// Response to a mouse up
- (void) endMove {
    self.moving = NO;
    _previousQuat = _currentQuat;
    _orientation = _currentQuat;
}

// Assume only a mouse with 1 scroll wheel.
- (void) scroll:(float)amount {
    static float mouseSensitivity = 0.1;
    vector_float3 pos = _eye;
    // Metal adopts the left hand rule with +z direction into the screen.
    float z = pos.z - amount*mouseSensitivity;
    if (z <= -8.0f)
        z = -8.0f;
    else if (z >= -3.0f)
        z = -3.0f;
    _eye = vector_make(0.0, 0.0, z);
    self.position = _eye;
}

@end
