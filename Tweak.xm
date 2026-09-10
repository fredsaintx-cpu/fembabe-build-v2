// FemBabe Overlay v17 - Direct API Activation
// Clean UI + HTTP POST to v.fembabe.org/api/vcam/activate

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define FEMBABE_TAG 0xFB0017

#pragma mark - Globals

static UIWindow *g_overlayWin = nil;
static UIButton *g_fbButton = nil;
static CGPoint g_dragStart;

#pragma mark - Get Device Public Key

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
                    NSLog(@"[FemBabe] Activate response: %@", json);
                    
                    if ([json[@"ok"] boolValue]) {
                        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
                        [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
                        [[NSUserDefaults standardUserDefaults] synchronize];
                        
                        // Call login2
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

#pragma mark - Show Login UI

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

#pragma mark - Overlay Window

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

#pragma mark - Draggable Button

@interface FBButton : UIButton
@property (nonatomic) CGPoint startCenter;
@end

@implementation FBButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    self.startCenter = self.window.center;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint prev = [touch previousLocationInView:nil];
    CGPoint curr = [touch locationInView:nil];
    CGFloat dx = curr.x - prev.x;
    CGFloat dy = curr.y - prev.y;
    UIWindow *win = self.window;
    win.center = CGPointMake(win.center.x + dx, win.center.y + dy);
}

@end

#pragma mark - Get Active Scene

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

#pragma mark - Build Overlay

static void buildOverlay(void) {
    if (g_overlayWin) return;
    
    UIWindowScene *scene = getActiveScene();
    if (!scene) return;
    
    FBOverlayWindow *win = [[FBOverlayWindow alloc] initWithWindowScene:scene];
    win.frame = CGRectMake(20, 150, 50, 50);
    win.windowLevel = UIWindowLevelAlert + 10000;
    win.backgroundColor = [UIColor clearColor];
    win.rootViewController = [[UIViewController alloc] init];
    win.rootViewController.view.backgroundColor = [UIColor clearColor];
    
    FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
    btn.backgroundColor = [UIColor colorWithRed:0.41 green:0.12 blue:0.80 alpha:1.0];
    btn.layer.cornerRadius = 25;
    btn.tag = FEMBABE_TAG;
    [btn setTitle:@"F" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    
    [btn addAction:[UIAction actionWithHandler:^(UIAction *action) {
        UIImpactFeedbackGenerator *haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [haptic impactOccurred];
        showLoginUI();
    }] forControlEvents:UIControlEventTouchUpInside];
    
    [win.rootViewController.view addSubview:btn];
    win.hidden = NO;
    g_overlayWin = win;
    g_fbButton = btn;
    
    NSLog(@"[FemBabe] v17 overlay - Direct API activation");
}

#pragma mark - Block B Button

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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ buildOverlay(); });
    }
}
