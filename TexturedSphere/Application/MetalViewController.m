/*
 MetalViewController.m
 TexturedSphere
 
 Created by Mark Lim Pak Mun on 13/08/2022.
 Copyright © 2022 mark lim pak mun. All rights reserved.

 */

#import "MetalViewController.h"
#import "MetalRenderer.h"
#import "AAPLMathUtilities.h"
#import "VirtualCamera.h"

@implementation MetalViewController {
    MTKView *_view;

    MetalRenderer *_renderer;
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
    UIGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(panGestureDidRecognize:)];
    [self.view addGestureRecognizer:panGesture];

    UIGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(pinchGestureDidRecognize:)];
    [self.view addGestureRecognizer:pinchGesture];

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
    [_renderer.camera startMove:mouseLocation];

}

- (void) mouseDragged:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    if (_renderer.camera.isMoving) {
        [_renderer.camera moveToPoint:mouseLocation];
    }
}

- (void) mouseUp:(NSEvent *)event {
    NSPoint mouseLocation = [self.view convertPoint:event.locationInWindow
                                           fromView:nil];
    [_renderer.camera endMove];

}

// We can move most of the code to the VirtualCamera class
- (void)scrollWheel:(NSEvent *)event {
    CGFloat dz = event.scrollingDeltaY;
    [_renderer.camera scroll:dz];
 }

#else

- (void) panGestureDidRecognize:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    switch(gesture.state) {
        case UIGestureRecognizerStateBegan:
            [_renderer.camera startMove:location];
            break;
        case UIGestureRecognizerStateChanged:
            if (_renderer.camera.isMoving) {
                [_renderer.camera moveToPoint:location];
            }
            break;
        case UIGestureRecognizerStateEnded:
            [_renderer.camera endMove];
            break;
        default:
            break;
    }
    [gesture setTranslation:CGPointZero
                     inView:self.view];
}

- (void) pinchGestureDidRecognize:(UIPinchGestureRecognizer *)gesture {
    CGFloat dz;
    switch(gesture.state)
    {
        case UIGestureRecognizerStateChanged:
            dz = 1.0 / gesture.scale;
            if (gesture.velocity < 0) {
                dz = -dz;
            }
            [_renderer.camera scroll:dz];
            break;
        default:
            break;
    }
}
#endif
@end
