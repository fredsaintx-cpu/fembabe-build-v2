// FemBabe iOS-18 Overlay v15 - SIMPLE
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define FEMBABE_TAG 0xFE0BABE

static UIWindow *g_overlayWin = nil;
static UIWindow *g_presentWin = nil;

@interface FBButton : UIButton
@end

@implementation FBButton

- (void)handleTap {
    NSLog(@"[FemBabe] F tapped!");
    
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];
    
    // Dismiss if already showing
    if (g_presentWin.rootViewController.presentedViewController) {
        NSLog(@"[FemBabe] Dismissing...");
        [g_presentWin.rootViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    // Get the VC class
    Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    NSLog(@"[FemBabe] VC class: %@", vcClass);
    if (!vcClass) return;
    
    // Create and present
    UIViewController *vc = [[vcClass alloc] init];
    NSLog(@"[FemBabe] VC instance: %@", vc);
    if (!vc) return;
    
    NSLog(@"[FemBabe] Presenting...");
    [g_presentWin.rootViewController presentViewController:vc animated:YES completion:^{
        NSLog(@"[FemBabe] Presented! Calling authLoginTapped...");
        if ([vc respondsToSelector:@selector(authLoginTapped)]) {
            [vc performSelector:@selector(authLoginTapped)];
        }
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIWindow *win = g_overlayWin;
    if (!win) return;
    
    static CGPoint startCenter;
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        startCenter = win.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:nil];
        CGPoint newCenter = CGPointMake(startCenter.x + translation.x, startCenter.y + translation.y);
        
        CGRect screen = [UIScreen mainScreen].bounds;
        newCenter.x = MAX(25, MIN(screen.size.width - 25, newCenter.x));
        newCenter.y = MAX(60, MIN(screen.size.height - 25, newCenter.y));
        
        win.center = newCenter;
    }
}

@end

@interface FBPresentWindow : UIWindow
@end

@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.rootViewController.presentedViewController) return [super hitTest:point withEvent:event];
    return nil;
}
@end

static IMP orig_setTitle = NULL;
static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (self.tag != FEMBABE_TAG && [title isEqualToString:@"B"]) {
        self.hidden = YES; self.alpha = 0; return;
    }
    ((void(*)(id,SEL,NSString*,UIControlState))orig_setTitle)(self, _cmd, title, state);
}

static UIWindowScene *activeScene(void) {
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
    }
    return nil;
}

static void buildOverlay(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_overlayWin) return;
        UIWindowScene *scene = activeScene();
        if (!scene) { 
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); }); 
            return; 
        }
        
        NSLog(@"[FemBabe] Building overlay with scene: %@", scene);
        
        FBPresentWindow *pw = [[FBPresentWindow alloc] initWithWindowScene:scene];
        pw.frame = [UIScreen mainScreen].bounds;
        pw.windowLevel = UIWindowLevelAlert + 5000;
        pw.backgroundColor = [UIColor clearColor];
        pw.rootViewController = [UIViewController new];
        pw.hidden = NO;
        g_presentWin = pw;
        
        UIWindow *ow = [[UIWindow alloc] initWithWindowScene:scene];
        ow.frame = CGRectMake(20, 150, 50, 50);
        ow.windowLevel = UIWindowLevelAlert + 10000;
        ow.backgroundColor = [UIColor clearColor];
        ow.layer.cornerRadius = 25;
        ow.clipsToBounds = YES;
        UIViewController *vc = [UIViewController new];
        ow.rootViewController = vc;
        
        FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        btn.backgroundColor = [UIColor colorWithRed:0.41 green:0.12 blue:0.80 alpha:1.0];
        btn.layer.cornerRadius = 25;
        btn.tag = FEMBABE_TAG;
        [btn setTitle:@"F" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)];
        [btn addGestureRecognizer:pan];
        
        [vc.view addSubview:btn];
        ow.hidden = NO;
        g_overlayWin = ow;
        
        NSLog(@"[FemBabe] Overlay ready!");
    });
}

__attribute__((constructor)) static void init(void) {
    @autoreleasepool {
        NSLog(@"[FemBabe] Init starting...");
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        orig_setTitle = method_setImplementation(m, (IMP)hook_setTitle);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); });
    }
}
