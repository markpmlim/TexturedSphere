/*
 MetalViewController.m
 
 
 Created by Mark Lim Pak Mun on 12/07/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

#import "MetalViewController.h"
#import "MetalRenderer.h"
#import "AAPLMathUtilities.h"
#import "VirtualCamera.h"

@implementation MetalViewController {
    MTKView *_view;

    MetalRenderer *_renderer;

    CGPoint _previousMousePoint;
    CGPoint _currentMousePoint;

    vector_float3 _startPoint;
    vector_float3 _endPoint;

    simd_quatf _currentQuat;
    simd_quatf _previousQuat;
    
#if TARGET_OS_IOS 
    UIPanGestureRecognizer *_panGesture;
    UIPinchGestureRecognizer *_pinchGesture;
#endif
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set the view to use the default device.
    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();

    if (!_view.device) {
        assert(!"Metal is not supported on this device.");
        return;
    }
    _view.colorPixelFormat = MTLPixelFormatRGBA16Float;
    _view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;

    _renderer = [[MetalRenderer alloc] initWithMetalKitView:_view];

    if (!_renderer) {
        assert(!"Renderer failed initialization.");
        return;
    }

    // Initialize renderer with the view size.
    [_renderer mtkView:_view
drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;

#if TARGET_OS_IOS
   _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                            action:@selector(panGestureDidRecognize:)];
    [self.view addGestureRecognizer:_panGesture];

    _pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(pinchGestureDidRecognize:)];
    [self.view addGestureRecognizer:_pinchGesture];
#endif
}

- (void) dealloc {
#if TARGET_OS_IOS
    [self.view removeGestureRecognizer:_panGesture];
    [self.view removeGestureRecognizer:_pinchGesture];
#endif
}

#if TARGET_OS_OSX
// This is called whenever there is a change in the view size.
- (void) viewDidLayout {
}

- (BOOL) becomeFirstResponder {
    return YES;
}




// location in window has origin at bottom left.
- (void) mouseDown:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    [_renderer.camera startDraggingFromPoint:mouseLocation];

}

- (void) mouseDragged:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    if (_renderer.camera.isDragging) {
        [_renderer.camera dragToPoint:mouseLocation];
    }
}

- (void) mouseUp:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    [_renderer.camera endDrag];

}

// We can move most of the code to the VirtualCamera class
- (void)scrollWheel:(NSEvent *)event {
    float dz = event.scrollingDeltaY;
    [_renderer.camera zoomInOrOut:dz];
 }
#else

- (void) panGestureDidRecognize:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    switch(gesture.state) {
        case UIGestureRecognizerStateBegan:
            [_renderer.camera startDraggingFromPoint:location];
            break;
        case UIGestureRecognizerStateChanged:
            if (_renderer.camera.isDragging) {
                [_renderer.camera dragToPoint:location];
            }
            break;
        case UIGestureRecognizerStateEnded:
            [_renderer.camera endDrag];
            break;
        default:
            break;
    }
    [gesture setTranslation:CGPointZero
                     inView:self.view];
}

- (void) pinchGestureDidRecognize:(UIPinchGestureRecognizer *)gesture {
    static float previousScale = 1.0;
    float dz = (gesture.scale - previousScale) * 15.0;
    [_renderer.camera zoomInOrOut:dz];
    previousScale = gesture.scale;
    if (gesture.state == UIGestureRecognizerStateEnded) {
        previousScale = 1.0;
    }
}
#endif
@end

