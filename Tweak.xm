// FemBabe iOS-18 Overlay v12
// FIXED: No white screen when not logged in, ultra-smooth drag
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <QuartzCore/QuartzCore.h>

#define FEMBABE_TAG 0xFE0BABE

static UIWindow *g_overlayWin = nil;
static UIWindow *g_presentWin = nil;

#pragma mark - Get manager instance

static id getManager(void) {
    Class mgrClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    if (!mgrClass) return nil;
    if ([mgrClass respondsToSelector:@selector(sharedInstance)]) {
        return [mgrClass performSelector:@selector(sharedInstance)];
    }
    return nil;
}

static BOOL isLoggedIn(void) {
    // Check via the VC class
    Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!vcClass) return NO;
    id vc = [[vcClass alloc] init];
    if (!vc) return NO;
    if ([vc respondsToSelector:@selector(loggedin)]) {
        return ((BOOL(*)(id, SEL))objc_msgSend)(vc, @selector(loggedin));
    }
    return NO;
}

#pragma mark - Smooth draggable button

@interface FBButton : UIButton {
    CGPoint _touchOffset;
}
@end

@implementation FBButton

- (void)handleTap {
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];
    
    // If already showing something, dismiss it
    if (g_presentWin.rootViewController.presentedViewController) {
        [g_presentWin.rootViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    // Check login state
    if (isLoggedIn()) {
        // LOGGED IN: Show settings VC (white screen is OK here)
        Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
        if (!vcClass) return;
        UIViewController *vc = [[vcClass alloc] init];
        if (!vc) return;
        [g_presentWin.rootViewController presentViewController:vc animated:YES completion:nil];
    } else {
        // NOT LOGGED IN: Show login alert directly, NO white screen
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe Login"
            message:@"Enter your activation key"
            preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
            tf.placeholder = @"Activation Key";
            tf.secureTextEntry = YES;
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *key = alert.textFields.firstObject.text;
            if (key.length > 0) {
                // Try to activate via the VC
                Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
                if (vcClass) {
                    id vc = [[vcClass alloc] init];
                    // Set the key and call activate
                    if ([vc respondsToSelector:@selector(authActivateTapped)]) {
                        // Store key somewhere the VC can read it, or call login directly
                        [vc performSelector:@selector(authActivateTapped)];
                    }
                }
            }
        }]];
        
        [g_presentWin.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

// ULTRA SMOOTH: Track touch offset, move window layer directly
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    CGPoint touchPoint = [touch locationInView:self];
    _touchOffset = CGPointMake(touchPoint.x - self.bounds.size.width/2, touchPoint.y - self.bounds.size.height/2);
    return YES;
}

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    UIWindow *win = g_overlayWin;
    if (!win) return YES;
    
    CGPoint screenPoint = [touch locationInView:nil];
    CGPoint newCenter = CGPointMake(screenPoint.x - _touchOffset.x, screenPoint.y - _touchOffset.y);
    
    // Bounds
    CGRect screen = [UIScreen mainScreen].bounds;
    newCenter.x = MAX(25, MIN(screen.size.width - 25, newCenter.x));
    newCenter.y = MAX(60, MIN(screen.size.height - 25, newCenter.y));
    
    // Direct layer update - fastest possible
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    win.layer.position = newCenter;
    [CATransaction commit];
    
    return YES;
}

@end

#pragma mark - Passthrough window

@interface FBPresentWindow : UIWindow
@end

@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.rootViewController.presentedViewController) return [super hitTest:point withEvent:event];
    return nil;
}
@end

#pragma mark - Block B button

static IMP orig_setTitle = NULL;
static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (self.tag != FEMBABE_TAG && [title isEqualToString:@"B"]) {
        self.hidden = YES; self.alpha = 0; return;
    }
    ((void(*)(id,SEL,NSString*,UIControlState))orig_setTitle)(self, _cmd, title, state);
}

#pragma mark - Build overlay

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
        if (!scene) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); }); return; }
        
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
        [vc.view addSubview:btn];
        ow.hidden = NO;
        g_overlayWin = ow;
    });
}

__attribute__((constructor)) static void init(void) {
    @autoreleasepool {
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        orig_setTitle = method_setImplementation(m, (IMP)hook_setTitle);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); });
    }
}
