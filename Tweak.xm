// FemBabe iOS-18 Overlay v22
// Direct API + notify camera app
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define FEMBABE_TAG 0xFE0BABE

static UIWindow *g_overlayWin = nil;
static UIWindow *g_presentWin = nil;

@interface FBButton : UIButton
@end

@implementation FBButton

- (void)notifyCameraLoggedIn:(NSDictionary *)loginData withKey:(NSString *)key {
    // Get the main vcam manager
    Class vcamClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    if (vcamClass) {
        id shared = [vcamClass performSelector:@selector(sharedInstance)];
        if (shared) {
            // Try to set login state
            @try { [shared setValue:@YES forKey:@"loggedIn"]; } @catch(NSException *e) {}
            @try { [shared setValue:@YES forKey:@"isLoggedIn"]; } @catch(NSException *e) {}
            @try { [shared setValue:loginData[@"license"] forKey:@"license"]; } @catch(NSException *e) {}
            @try { [shared setValue:loginData[@"licenseSig"] forKey:@"licenseSig"]; } @catch(NSException *e) {}
            @try { [shared setValue:loginData[@"sPub"] forKey:@"sPub"]; } @catch(NSException *e) {}
            @try { [shared setValue:loginData[@"encConfig"] forKey:@"encConfig"]; } @catch(NSException *e) {}
            
            // Try calling login method
            if ([shared respondsToSelector:@selector(setLoggedIn:)]) {
                [shared performSelector:@selector(setLoggedIn:) withObject:@YES];
            }
            if ([shared respondsToSelector:@selector(onLoginSuccess:)]) {
                [shared performSelector:@selector(onLoginSuccess:) withObject:loginData];
            }
            if ([shared respondsToSelector:@selector(handleLoginResponse:)]) {
                [shared performSelector:@selector(handleLoginResponse:) withObject:loginData];
            }
        }
    }
    
    // Also try the settings VC class
    Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (settingsClass) {
        id vc = [[settingsClass alloc] init];
        @try { [vc setValue:@YES forKey:@"loggedin"]; } @catch(NSException *e) {}
        @try { [vc setValue:key forKey:@"username"]; } @catch(NSException *e) {}
        if ([vc respondsToSelector:@selector(loginSuccess)]) {
            [vc performSelector:@selector(loginSuccess)];
        }
    }
}

- (void)activateWithKey:(NSString *)key {
    if (key.length == 0) {
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:@"Enter a key" preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [g_presentWin.rootViewController presentViewController:a animated:YES completion:nil];
        return;
    }
    
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Activating..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [g_presentWin.rootViewController presentViewController:loading animated:YES completion:nil];
    
    // Step 1: Activate
    NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/activate"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSDictionary *body = @{@"username": key, @"key": key, @"devicePub": @""};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    __weak typeof(self) weakSelf = self;
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Error" message:err.localizedDescription ?: @"Network error" preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [g_presentWin.rootViewController presentViewController:a animated:YES completion:nil];
                }];
            });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json[@"ok"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Failed" message:json[@"error"] ?: @"Activation failed" preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [g_presentWin.rootViewController presentViewController:a animated:YES completion:nil];
                }];
            });
            return;
        }
        
        // Step 2: Login2
        NSURL *url2 = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/login2"];
        NSMutableURLRequest *req2 = [NSMutableURLRequest requestWithURL:url2];
        req2.HTTPMethod = @"POST";
        [req2 setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body2 = @{@"userId": key, @"username": key, @"devicePub": @""};
        req2.HTTPBody = [NSJSONSerialization dataWithJSONObject:body2 options:0 error:nil];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:req2 completionHandler:^(NSData *data2, NSURLResponse *resp2, NSError *err2) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    NSDictionary *loginData = nil;
                    if (data2) {
                        loginData = [NSJSONSerialization JSONObjectWithData:data2 options:0 error:nil];
                    }
                    
                    // Save to UserDefaults
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
                    [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
                    if (loginData) {
                        [[NSUserDefaults standardUserDefaults] setObject:loginData forKey:@"FemBabeLoginData"];
                    }
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    // Notify camera app
                    [weakSelf notifyCameraLoggedIn:loginData ?: @{} withKey:key];
                    
                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"✓ Activated!" message:@"Tap F again to open camera settings" preferredStyle:UIAlertControllerStyleAlert];
                    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [g_presentWin.rootViewController presentViewController:a animated:YES completion:nil];
                }];
            });
        }] resume];
    }] resume];
}

- (void)handleTap {
    UIImpactFeedbackGenerator *h = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [h impactOccurred];
    
    if (g_presentWin.rootViewController.presentedViewController) {
        [g_presentWin.rootViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    // Check if already activated - show camera settings
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"FemBabeActivated"]) {
        Class vcamClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
        if (vcamClass) {
            id shared = [vcamClass performSelector:@selector(sharedInstance)];
            if ([shared respondsToSelector:@selector(setFloatWindow:)]) {
                [shared performSelector:@selector(setFloatWindow:) withObject:@YES];
            }
            if ([shared respondsToSelector:@selector(showSettings)]) {
                [shared performSelector:@selector(showSettings)];
            }
            if ([shared respondsToSelector:@selector(toggleSettings)]) {
                [shared performSelector:@selector(toggleSettings)];
            }
        }
        return;
    }
    
    // Show login UI
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe Login" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Activation Key";
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [weakSelf activateWithKey:alert.textFields.firstObject.text];
    }]];
    
    [g_presentWin.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    UIWindow *win = g_overlayWin;
    if (!win) return;
    static CGPoint startCenter;
    if (pan.state == UIGestureRecognizerStateBegan) {
        startCenter = win.center;
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint t = [pan translationInView:nil];
        CGPoint c = CGPointMake(startCenter.x + t.x, startCenter.y + t.y);
        CGRect s = [UIScreen mainScreen].bounds;
        c.x = MAX(25, MIN(s.size.width - 25, c.x));
        c.y = MAX(60, MIN(s.size.height - 25, c.y));
        win.center = c;
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
