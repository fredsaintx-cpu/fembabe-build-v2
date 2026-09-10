#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;
static UITextField *keyField = nil;
static UIView *activationPanel = nil;

static void doLogin(NSString *key) {
    // Save key
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
    [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // Get login API and call without callback
    Class loginAPIClass = NSClassFromString(@"iCdfsIdfdEdfsNdfdftqWer");
    if (loginAPIClass) {
        id instance = ((id(*)(Class, SEL))objc_msgSend)(loginAPIClass, @selector(sharedInstance));
        if (instance) {
            ((void(*)(id, SEL, id))objc_msgSend)(instance, @selector(setUrl:), @"https://v.fembabe.org");
            
            // Call login without callback - just fire and forget
            SEL loginSel = NSSelectorFromString(@"login:password:callback:");
            ((void(*)(id, SEL, id, id, id))objc_msgSend)(instance, loginSel, key, key, nil);
        }
    }
    
    // Also set vcam state
    Class vcamClass = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    if (vcamClass) {
        id vcam = ((id(*)(Class, SEL))objc_msgSend)(vcamClass, @selector(sharedInstance));
        ((void(*)(id, SEL, BOOL))objc_msgSend)(vcam, @selector(setFloatWindow:), YES);
    }
    
    // Hide panel and vibrate
    if (activationPanel) activationPanel.hidden = YES;
    AudioServicesPlaySystemSound(1519);
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

static IMP originalSetTitleForState = NULL;
static void blockedSetTitle(id self, SEL _cmd, NSString *title, UIControlState state) {
    if (title && [title isEqualToString:@"B"]) return;
    if (originalSetTitleForState) {
        ((void(*)(id, SEL, NSString*, UIControlState))originalSetTitleForState)(self, _cmd, title, state);
    }
}

%ctor {
    @autoreleasepool {
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        if (m) originalSetTitleForState = method_setImplementation(m, (IMP)blockedSetTitle);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (overlayWindow) return;
            
            overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = [UIColor clearColor];
            overlayWindow.userInteractionEnabled = YES;
            overlayWindow.hidden = NO;
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
