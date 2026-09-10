// FemBabe Overlay v19 - Direct API + Aggressive B-Kill

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define FEMBABE_TAG 0xFB0019

static UIWindow *g_overlayWin = nil;
static UIButton *g_fbButton = nil;

#pragma mark - Aggressive B Killer

static void killBButtonsInView(UIView *view) {
    if (!view) return;
    
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *title = [btn titleForState:UIControlStateNormal];
        CGRect frame = btn.frame;
        
        if ([title isEqualToString:@"B"] && btn.tag != FEMBABE_TAG) {
            btn.hidden = YES;
            btn.alpha = 0;
            btn.userInteractionEnabled = NO;
            [btn removeFromSuperview];
        }
        if (frame.size.width <= 80 && frame.size.height <= 80 && btn.tag != FEMBABE_TAG && btn != g_fbButton) {
            CGFloat r = 0, g = 0, b = 0, a = 0;
            if (btn.backgroundColor) {
                [btn.backgroundColor getRed:&r green:&g blue:&b alpha:&a];
                if (r > 0.8 && g > 0.3 && g < 0.7 && b < 0.3) {
                    btn.hidden = YES;
                    btn.alpha = 0;
                    [btn removeFromSuperview];
                }
            }
        }
    }
    
    for (UIView *sub in view.subviews) {
        killBButtonsInView(sub);
    }
}

static void killAllBButtons(void) {
    // Use scenes to get windows (iOS 15+)
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        
        for (UIWindow *win in windowScene.windows) {
            if (win == g_overlayWin) continue;
            
            CGRect f = win.frame;
            if (f.size.width <= 200 && f.size.height <= 200 && win.tag != FEMBABE_TAG) {
                win.hidden = YES;
                win.alpha = 0;
            }
            
            killBButtonsInView(win);
        }
    }
}

#pragma mark - Device Pub Key

static NSString *getDevicePubKey(void) {
    Class vcamClass = objc_getClass("ifdsflwoWdasdYfsdfJd");
    if (vcamClass) {
        id shared = [vcamClass performSelector:@selector(sharedInstance)];
        if (shared) {
            @try {
                id devicePub = [shared valueForKey:@"devicePub"];
                if ([devicePub isKindOfClass:[NSString class]] && [devicePub length] > 0) {
                    return devicePub;
                }
            } @catch (NSException *e) {}
        }
    }
    return @"";
}

#pragma mark - API Activation

static void activateWithKey(NSString *key, UIViewController *presenter) {
    if (!key || key.length == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error"
            message:@"Please enter an activation key" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [presenter presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/activate"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSString *devicePub = getDevicePubKey();
    NSDictionary *body = @{@"username": key, @"key": key, @"devicePub": devicePub ?: @""};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Activating..."
        message:@"Please wait" preferredStyle:UIAlertControllerStyleAlert];
    [presenter presentViewController:loading animated:YES completion:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loading dismissViewControllerAnimated:YES completion:^{
                    if (error) {
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Network Error"
                            message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [presenter presentViewController:a animated:YES completion:nil];
                        return;
                    }
                    
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    
                    if ([json[@"ok"] boolValue]) {
                        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
                        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        NSURL *login2Url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/login2"];
                        NSMutableURLRequest *login2Req = [NSMutableURLRequest requestWithURL:login2Url];
                        login2Req.HTTPMethod = @"POST";
                        [login2Req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
                        NSDictionary *login2Body = @{@"userId": key, @"username": key, @"devicePub": devicePub ?: @""};
                        login2Req.HTTPBody = [NSJSONSerialization dataWithJSONObject:login2Body options:0 error:nil];
                        
                        [[[NSURLSession sharedSession] dataTaskWithRequest:login2Req
                            completionHandler:^(NSData *d2, NSURLResponse *r2, NSError *e2) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"✓ Activated!"
                                        message:@"FemBabe is now active. Enjoy!" preferredStyle:UIAlertControllerStyleAlert];
                                    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                                    [presenter presentViewController:a animated:YES completion:nil];
                                });
                            }] resume];
                    } else {
                        NSString *errMsg = json[@"error"] ?: @"Activation failed";
                        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Activation Failed"
                            message:errMsg preferredStyle:UIAlertControllerStyleAlert];
                        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                        [presenter presentViewController:a animated:YES completion:nil];
                    }
                }];
            });
        }] resume];
}

static void showLoginUI(void) {
    UIViewController *root = g_overlayWin.rootViewController;
    if (!root) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe Login"
        message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Activation Key";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        activateWithKey(key, root);
    }]];
    
    [root presentViewController:alert animated:YES completion:nil];
}

@interface FBOverlayWindow : UIWindow
@end
@implementation FBOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *sub in self.rootViewController.view.subviews) {
        if ([sub pointInside:[self convertPoint:point toView:sub] withEvent:event]) return YES;
    }
    return NO;
}
@end

@interface FBButton : UIButton
@end
@implementation FBButton
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint prev = [touch previousLocationInView:nil];
    CGPoint curr = [touch locationInView:nil];
    UIWindow *win = self.window;
    win.center = CGPointMake(win.center.x + (curr.x - prev.x), win.center.y + (curr.y - prev.y));
}
@end

static UIWindowScene *getActiveScene(void) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive &&
            [scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            return (UIWindowScene *)scene;
        }
    }
    return nil;
}

static void buildOverlay(void) {
    if (g_overlayWin) return;
    UIWindowScene *scene = getActiveScene();
    if (!scene) return;
    
    FBOverlayWindow *win = [[FBOverlayWindow alloc] initWithWindowScene:scene];
    win.frame = CGRectMake(20, 150, 50, 50);
    win.windowLevel = UIWindowLevelAlert + 10000;
    win.backgroundColor = [UIColor clearColor];
    win.tag = FEMBABE_TAG;
    win.rootViewController = [[UIViewController alloc] init];
    win.rootViewController.view.backgroundColor = [UIColor clearColor];
    
    FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    btn.backgroundColor = [UIColor colorWithRed:0.41 green:0.12 blue:0.80 alpha:1.0];
    btn.layer.cornerRadius = 25;
    btn.tag = FEMBABE_TAG;
    [btn setTitle:@"F" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    
    [btn addAction:[UIAction actionWithHandler:^(__unused UIAction *action) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [haptic impactOccurred];
        showLoginUI();
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [win.rootViewController.view addSubview:btn];
    win.hidden = NO;
    g_overlayWin = win;
    g_fbButton = btn;
    
    killAllBButtons();
}

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if ([title isEqualToString:@"B"] && self.tag != FEMBABE_TAG) {
        self.hidden = YES;
        self.alpha = 0;
        self.userInteractionEnabled = NO;
        return;
    }
    %orig;
}
%end

%ctor {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); killAllBButtons(); });
        for (int i = 1; i <= 10; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, i*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ killAllBButtons(); });
        }
    }
}
