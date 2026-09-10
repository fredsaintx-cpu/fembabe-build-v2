#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;
static UITextField *keyField = nil;
static UIView *activationPanel = nil;

// Get key window helper
static UIWindow* getKeyWindow() {
    NSArray *scenes = [[UIApplication sharedApplication] connectedScenes].allObjects;
    for (id scene in scenes) {
        if ([scene activationState] == 0) continue;
        id delegate = [scene delegate];
        if ([delegate respondsToSelector:@selector(window)]) {
            return [delegate window];
        }
    }
    return nil;
}

// Login callback block type
typedef void (^LoginCallback)(id result);

static void doLogin(NSString *key) {
    // Get the login API class
    Class loginAPIClass = NSClassFromString(@"iCdfsIdfdEdfsNdfdftqWer");
    if (!loginAPIClass) {
        NSLog(@"[FemBabe] Login API class not found");
        return;
    }
    
    // Get shared instance
    id instance = ((id(*)(Class, SEL))objc_msgSend)(loginAPIClass, @selector(sharedInstance));
    if (!instance) {
        NSLog(@"[FemBabe] Could not get login API instance");
        return;
    }
    
    // Set URL
    ((void(*)(id, SEL, id))objc_msgSend)(instance, @selector(setUrl:), @"https://v.fembabe.org");
    
    // Create callback block
    LoginCallback callback = ^(id result) {
        NSLog(@"[FemBabe] Login callback result: %@", result);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Save activation state
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Hide activation panel
            if (activationPanel) {
                activationPanel.hidden = YES;
            }
            
            // Try to show the float window
            Class vcamClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
            if (vcamClass) {
                id vcam = ((id(*)(Class, SEL))objc_msgSend)(vcamClass, @selector(sharedInstance));
                ((void(*)(id, SEL, BOOL))objc_msgSend)(vcam, @selector(setFloatWindow:), YES);
                ((void(*)(id, SEL, BOOL))objc_msgSend)(vcam, @selector(setLive:), YES);
            }
            
            // Also call loggedin on Settings VC
            Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
            if (settingsClass) {
                id vc = [[settingsClass alloc] init];
                ((void(*)(id, SEL, id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
                ((void(*)(id, SEL, id))objc_msgSend)(vc, @selector(setUsername:), key);
                ((void(*)(id, SEL, id))objc_msgSend)(vc, @selector(setPassword:), key);
                ((void(*)(id, SEL))objc_msgSend)(vc, @selector(loggedin));
            }
            
            // Vibrate for feedback
            AudioServicesPlaySystemSound(1519);
        });
    };
    
    // Call login:password:callback:
    SEL loginSel = NSSelectorFromString(@"login:password:callback:");
    ((void(*)(id, SEL, id, id, id))objc_msgSend)(instance, loginSel, key, key, callback);
    
    NSLog(@"[FemBabe] Login called for key: %@", key);
}

static void showActivationPanel() {
    if (!activationPanel) {
        activationPanel = [[UIView alloc] initWithFrame:CGRectMake(50, 200, 280, 140)];
        activationPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
        activationPanel.layer.cornerRadius = 12;
        
        keyField = [[UITextField alloc] initWithFrame:CGRectMake(15, 20, 250, 40)];
        keyField.placeholder = @"Enter activation key";
        keyField.backgroundColor = [UIColor whiteColor];
        keyField.layer.cornerRadius = 8;
        keyField.textAlignment = NSTextAlignmentCenter;
        keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        keyField.autocorrectionType = UITextAutocorrectionTypeNo;
        [activationPanel addSubview:keyField];
        
        UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        activateBtn.frame = CGRectMake(15, 75, 120, 44);
        [activateBtn setTitle:@"Activate" forState:UIControlStateNormal];
        [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        activateBtn.backgroundColor = [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1];
        activateBtn.layer.cornerRadius = 8;
        [activateBtn addTarget:floatButton action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
        [activationPanel addSubview:activateBtn];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(145, 75, 120, 44);
        [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeBtn.backgroundColor = [UIColor darkGrayColor];
        closeBtn.layer.cornerRadius = 8;
        [closeBtn addTarget:floatButton action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [activationPanel addSubview:closeBtn];
        
        [overlayWindow addSubview:activationPanel];
    }
    activationPanel.hidden = NO;
    [keyField becomeFirstResponder];
}

@interface FBFloatButton : UIButton
@end

@implementation FBFloatButton

- (void)floatTapped {
    AudioServicesPlaySystemSound(1519);
    showActivationPanel();
}

- (void)activateTapped {
    NSString *key = keyField.text;
    if (key.length > 0) {
        [keyField resignFirstResponder];
        doLogin(key);
    }
}

- (void)closeTapped {
    [keyField resignFirstResponder];
    activationPanel.hidden = YES;
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:overlayWindow];
    CGPoint newCenter = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
    
    CGFloat halfWidth = self.bounds.size.width / 2;
    CGFloat halfHeight = self.bounds.size.height / 2;
    CGRect bounds = overlayWindow.bounds;
    
    newCenter.x = MAX(halfWidth, MIN(newCenter.x, bounds.size.width - halfWidth));
    newCenter.y = MAX(halfHeight, MIN(newCenter.y, bounds.size.height - halfHeight));
    
    self.center = newCenter;
    [gesture setTranslation:CGPointZero inView:overlayWindow];
}

@end

// B Button blocking
static IMP originalSetTitleForState = NULL;
static void blockedSetTitle(id self, SEL _cmd, NSString *title, UIControlState state) {
    if (title && [title isEqualToString:@"B"]) {
        return;
    }
    if (originalSetTitleForState) {
        ((void(*)(id, SEL, NSString*, UIControlState))originalSetTitleForState)(self, _cmd, title, state);
    }
}

%ctor {
    @autoreleasepool {
        // Block B button
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        if (m) {
            originalSetTitleForState = method_setImplementation(m, (IMP)blockedSetTitle);
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (overlayWindow) return;
            
            overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = [UIColor clearColor];
            overlayWindow.userInteractionEnabled = YES;
            overlayWindow.hidden = NO;
            
            // Pass through touches except for our button
            overlayWindow.rootViewController = [UIViewController new];
            
            floatButton = [[FBFloatButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
            floatButton.backgroundColor = [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1];
            [floatButton setTitle:@"F" forState:UIControlStateNormal];
            [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
            floatButton.layer.cornerRadius = 25;
            floatButton.clipsToBounds = YES;
            
            [floatButton addTarget:floatButton action:@selector(floatTapped) forControlEvents:UIControlEventTouchUpInside];
            
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:floatButton action:@selector(handlePan:)];
            [floatButton addGestureRecognizer:pan];
            
            [overlayWindow addSubview:floatButton];
            [overlayWindow makeKeyAndVisible];
        });
    }
}
