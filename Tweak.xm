// FemBabe iOS-18 Overlay v24 - Trigger camera's own login
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define FEMBABE_TAG 0xFE0BABE

static UIWindow *g_overlayWin = nil;
static UIWindow *g_presentWin = nil;

@interface FBButton : UIButton
@end

@implementation FBButton

- (void)triggerCameraLogin:(NSString *)key {
    // Get the main vcam manager
    Class vcamClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    id shared = nil;
    if (vcamClass && [vcamClass respondsToSelector:@selector(sharedInstance)]) {
        shared = [vcamClass performSelector:@selector(sharedInstance)];
    }
    
    // Try various login methods on the manager
    if (shared) {
        // Try direct login methods
        SEL selectors[] = {
            @selector(loginWithKey:),
            @selector(activateWithKey:),
            @selector(login:),
            @selector(activate:),
            @selector(setActivationKey:),
            @selector(setKey:),
            @selector(doLogin:),
            @selector(performLogin:)
        };
        for (int i = 0; i < sizeof(selectors)/sizeof(selectors[0]); i++) {
            if ([shared respondsToSelector:selectors[i]]) {
                [shared performSelector:selectors[i] withObject:key];
                break;
            }
        }
        
        // Also try setting key via KVC then calling login
        @try { [shared setValue:key forKey:@"activationKey"]; } @catch(NSException *e) {}
        @try { [shared setValue:key forKey:@"key"]; } @catch(NSException *e) {}
        @try { [shared setValue:key forKey:@"licenseKey"]; } @catch(NSException *e) {}
        
        if ([shared respondsToSelector:@selector(login)]) {
            [shared performSelector:@selector(login)];
        }
        if ([shared respondsToSelector:@selector(doLogin)]) {
            [shared performSelector:@selector(doLogin)];
        }
    }
    
    // Try the settings VC class
    Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (settingsClass) {
        id vc = [[settingsClass alloc] init];
        
        // Set key via KVC
        @try { [vc setValue:key forKey:@"activationKey"]; } @catch(NSException *e) {}
        @try { [vc setValue:key forKey:@"key"]; } @catch(NSException *e) {}
        @try { [vc setValue:key forKey:@"keyField"]; } @catch(NSException *e) {}
        
        // Load view to access text fields
        if ([vc isKindOfClass:[UIViewController class]]) {
            [(UIViewController *)vc loadViewIfNeeded];
            // Find text fields and set key
            for (UIView *v in [(UIViewController *)vc view].subviews) {
                if ([v isKindOfClass:[UITextField class]]) {
                    [(UITextField *)v setText:key];
                }
            }
        }
        
        // Call activation methods
        if ([vc respondsToSelector:@selector(authActivateTapped)]) {
            [vc performSelector:@selector(authActivateTapped)];
        }
        if ([vc respondsToSelector:@selector(activateTapped)]) {
            [vc performSelector:@selector(activateTapped)];
        }
        if ([vc respondsToSelector:@selector(login)]) {
            [vc performSelector:@selector(login)];
        }
    }
    
    // Show feedback
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Activating..." message:@"Check if camera panel appears" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [g_presentWin.rootViewController presentViewController:a animated:YES completion:nil];
}

- (void)handleTap {
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];
    
    if (g_presentWin.rootViewController.presentedViewController) {
        [g_presentWin.rootViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe Login" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Activation Key";
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) ws = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [ws triggerCameraLogin:alert.textFields.firstObject.text];
    }]];
    [g_presentWin.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    static CGPoint sc;
    if (pan.state == UIGestureRecognizerStateBegan) sc = g_overlayWin.center;
    else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [pan translationInView:nil];
        g_overlayWin.center = CGPointMake(sc.x + t.x, sc.y + t.y);
    }
}
@end

@interface FBPresentWindow : UIWindow @end
@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    return self.rootViewController.presentedViewController ? [super hitTest:p withEvent:e] : nil;
}
@end

static IMP orig_setTitle = NULL;
static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (self.tag != FEMBABE_TAG && [title isEqualToString:@"B"]) { self.hidden = YES; self.alpha = 0; return; }
    ((void(*)(id,SEL,NSString*,UIControlState))orig_setTitle)(self, _cmd, title, state);
}

static UIWindowScene *activeScene(void) {
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)s;
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
        ow.rootViewController = [UIViewController new];
        
        FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        btn.backgroundColor = [UIColor colorWithRed:0.41 green:0.12 blue:0.80 alpha:1.0];
        btn.layer.cornerRadius = 25;
        btn.tag = FEMBABE_TAG;
        [btn setTitle:@"F" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
        [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)]];
        [ow.rootViewController.view addSubview:btn];
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
