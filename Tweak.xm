#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static IMP orig_setTitle = NULL;
static IMP orig_addSubview = NULL;
static IMP orig_presentVC = NULL;
static IMP orig_logout = NULL;
static NSString *g_pendingKey = nil;

static void showActivationAlert(void);

static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (title && [title isEqualToString:@"B"]) { self.hidden = YES; return; }
    if (orig_setTitle) ((void(*)(id,SEL,id,UIControlState))orig_setTitle)(self, _cmd, title, state);
}

static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    Class orangeClass = NSClassFromString(@"iHsfaTkdhwkzopQfsnwBd");
    if (orangeClass && [view isKindOfClass:orangeClass]) { view.hidden = YES; return; }
    if (orig_addSubview) ((void(*)(id,SEL,id))orig_addSubview)(self, _cmd, view);
}

// Hook logout to show our activation alert instead
static void hook_logout(id self, SEL _cmd, id sender) {
    // Dismiss the settings panel
    UIViewController *vc = (UIViewController *)self;
    [vc dismissViewControllerAnimated:YES completion:^{
        // Show our activation alert
        showActivationAlert();
    }];
}

static void hook_presentVC(UIViewController *self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void)) {
    if ([vc isKindOfClass:[UIAlertController class]] && g_pendingKey) {
        UIAlertController *alert = (UIAlertController *)vc;
        NSString *title = alert.title;
        
        if (title && [title containsString:@"Login"]) {
            if (alert.textFields.count > 0) {
                alert.textFields[0].text = g_pendingKey;
            }
            
            ((void(*)(id,SEL,id,BOOL,id))orig_presentVC)(self, _cmd, vc, animated, ^{
                if (completion) completion();
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                    for (UIAlertAction *action in alert.actions) {
                        if (action.style == UIAlertActionStyleDefault) {
                            void (^handler)(UIAlertAction *) = [action valueForKey:@"handler"];
                            if (handler) handler(action);
                            [vc dismissViewControllerAnimated:YES completion:nil];
                            break;
                        }
                    }
                    g_pendingKey = nil;
                });
            });
            return;
        }
    }
    
    ((void(*)(id,SEL,id,BOOL,id))orig_presentVC)(self, _cmd, vc, animated, completion);
}

@interface FBPresentWindow : UIWindow
@end
@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

@interface FBButton : UIButton
@property (nonatomic) CGPoint dragStart;
@property (nonatomic) CGPoint winStart;
@end

@implementation FBButton
- (void)handleTap { showActivationAlert(); }

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        self.dragStart = [g locationInView:overlayWindow];
        self.winStart = self.center;
    }
    CGPoint p = [g locationInView:overlayWindow];
    self.center = CGPointMake(self.winStart.x + p.x - self.dragStart.x, self.winStart.y + p.y - self.dragStart.y);
}
@end

static void showActivationAlert(void) {
    AudioServicesPlaySystemSound(1519);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe"
                                                                   message:@"Enter activation key"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"XXXX-XXXX-XXXX-XXXX";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length == 0) return;
        
        g_pendingKey = [key copy];
        
        Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
        id vc = [[vcClass alloc] init];
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setUsername:), key);
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setPassword:), key);
        
        [overlayWindow.rootViewController presentViewController:vc animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                ((void(*)(id,SEL))objc_msgSend)(vc, @selector(login));
            });
        }];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [overlayWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%ctor {
    Method m1 = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
    if (m1) orig_setTitle = method_setImplementation(m1, (IMP)hook_setTitle);
    Method m2 = class_getInstanceMethod([UIView class], @selector(addSubview:));
    if (m2) orig_addSubview = method_setImplementation(m2, (IMP)hook_addSubview);
    Method m3 = class_getInstanceMethod([UIViewController class], @selector(presentViewController:animated:completion:));
    if (m3) orig_presentVC = method_setImplementation(m3, (IMP)hook_presentVC);
    
    // Hook logout on Settings VC
    Class settingsVC = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (settingsVC) {
        Method m4 = class_getInstanceMethod(settingsVC, @selector(logout:));
        if (m4) orig_logout = method_setImplementation(m4, (IMP)hook_logout);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s; break;
                }
            }
            if (!scene) return;
            
            overlayWindow = [[FBPresentWindow alloc] initWithWindowScene:scene];
            overlayWindow.frame = UIScreen.mainScreen.bounds;
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = UIColor.clearColor;
            overlayWindow.rootViewController = [UIViewController new];
            overlayWindow.hidden = NO;
            
            FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(20,100,50,50)];
            btn.backgroundColor = [UIColor colorWithRed:0.4 green:0.0 blue:0.6 alpha:1.0];
            [btn setTitle:@"F" forState:UIControlStateNormal];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            btn.layer.cornerRadius = 25;
            btn.clipsToBounds = YES;
            [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)]];
            [overlayWindow addSubview:btn];
        }
    });
}
