#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;

@interface FBPresentWindow : UIWindow
@end

@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface FBButton : UIButton
@property (nonatomic) CGPoint dragStart;
@property (nonatomic) CGPoint winStart;
@end

@implementation FBButton

- (void)handleTap {
    AudioServicesPlaySystemSound(1519);
    
    // Get Settings VC class
    Class loginClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!loginClass) {
        NSLog(@"[FemBabe] Login VC class not found!");
        return;
    }
    
    // Create instance
    id loginVC = [[loginClass alloc] init];
    if (!loginVC) {
        NSLog(@"[FemBabe] Failed to create login VC!");
        return;
    }
    
    // Set server
    if ([loginVC respondsToSelector:@selector(setServer:)]) {
        [loginVC performSelector:@selector(setServer:) withObject:@"https://v.fembabe.org"];
    }
    
    NSLog(@"[FemBabe] Presenting login...");
    
    // Present the Settings VC
    [overlayWindow.rootViewController presentViewController:loginVC animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.dragStart = [gesture locationInView:overlayWindow];
        self.winStart = self.center;
    }
    CGPoint loc = [gesture locationInView:overlayWindow];
    CGFloat dx = loc.x - self.dragStart.x;
    CGFloat dy = loc.y - self.dragStart.y;
    self.center = CGPointMake(self.winStart.x + dx, self.winStart.y + dy);
}

@end

// Block B button
static IMP origSetTitle = NULL;
static void blockB(id self, SEL _cmd, NSString *title, UIControlState state) {
    if ([title isEqualToString:@"B"]) {
        [self setHidden:YES];
        return;
    }
    ((void(*)(id,SEL,NSString*,UIControlState))origSetTitle)(self, _cmd, title, state);
}

%ctor {
    @autoreleasepool {
        // Hook B button
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        if (m) origSetTitle = method_setImplementation(m, (IMP)blockB);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            // Get window scene
            UIWindowScene *scene = nil;
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            if (!scene) return;
            
            // Create overlay window
            overlayWindow = [[FBPresentWindow alloc] initWithWindowScene:scene];
            overlayWindow.frame = [UIScreen mainScreen].bounds;
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = [UIColor clearColor];
            overlayWindow.rootViewController = [[UIViewController alloc] init];
            overlayWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
            overlayWindow.hidden = NO;
            
            // Create purple F button
            floatButton = [[FBButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
            floatButton.backgroundColor = [UIColor purpleColor];
            [floatButton setTitle:@"F" forState:UIControlStateNormal];
            [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            floatButton.layer.cornerRadius = 25;
            floatButton.clipsToBounds = YES;
            
            [floatButton addTarget:floatButton action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatButton action:@selector(handlePan:)];
            [floatButton addGestureRecognizer:pan];
            
            [overlayWindow addSubview:floatButton];
            
            NSLog(@"[FemBabe] Overlay ready!");
        });
    }
}
