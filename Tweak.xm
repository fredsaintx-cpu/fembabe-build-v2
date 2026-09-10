#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;
static UITextField *keyField = nil;
static UIView *activationPanel = nil;

static void doLogin(NSString *key) {
    Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!settingsClass) return;
    
    id vc = [[settingsClass alloc] init];
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setUsername:), key);
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setPassword:), key);
    
    // Hide our panel
    activationPanel.hidden = YES;
    [keyField resignFirstResponder];
    
    // Present the Settings VC so user can see the native UI and tap Login
    [overlayWindow.rootViewController presentViewController:vc animated:YES completion:^{
        // After presented, call login
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            ((void(*)(id,SEL))objc_msgSend)(vc, @selector(login));
        });
    }];
    
    AudioServicesPlaySystemSound(1519);
}

static void showActivationPanel(void) {
    if (!activationPanel) {
        activationPanel = [[UIView alloc] initWithFrame:CGRectMake(40, 200, 300, 150)];
        activationPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
        activationPanel.layer.cornerRadius = 12;
        
        keyField = [[UITextField alloc] initWithFrame:CGRectMake(15, 20, 270, 44)];
        keyField.placeholder = @"Enter activation key";
        keyField.backgroundColor = [UIColor whiteColor];
        keyField.layer.cornerRadius = 8;
        keyField.textAlignment = NSTextAlignmentCenter;
        keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        [activationPanel addSubview:keyField];
        
        UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        activateBtn.frame = CGRectMake(15, 80, 130, 50);
        [activateBtn setTitle:@"Activate" forState:UIControlStateNormal];
        [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        activateBtn.backgroundColor = [UIColor purpleColor];
        activateBtn.layer.cornerRadius = 8;
        [activateBtn addTarget:floatButton action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
        [activationPanel addSubview:activateBtn];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(155, 80, 130, 50);
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
- (void)floatTapped { AudioServicesPlaySystemSound(1519); showActivationPanel(); }
- (void)activateTapped {
    NSString *key = keyField.text;
    if (key.length > 0) { doLogin(key); }
}
- (void)closeTapped { [keyField resignFirstResponder]; activationPanel.hidden = YES; }
- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:overlayWindow];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [g setTranslation:CGPointZero inView:overlayWindow];
}
@end

static IMP origSetTitle = NULL;
static void blockB(id self, SEL _cmd, NSString *title, UIControlState state) {
    if ([title isEqualToString:@"B"]) { [self setHidden:YES]; return; }
    ((void(*)(id,SEL,NSString*,UIControlState))origSetTitle)(self, _cmd, title, state);
}

%ctor {
    Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
    if (m) origSetTitle = method_setImplementation(m, (IMP)blockB);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        overlayWindow.windowLevel = UIWindowLevelAlert + 100;
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.hidden = NO;
        overlayWindow.rootViewController = [UIViewController new];
        
        floatButton = [[FBFloatButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
        floatButton.backgroundColor = [UIColor purpleColor];
        [floatButton setTitle:@"F" forState:UIControlStateNormal];
        [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        floatButton.layer.cornerRadius = 25;
        [floatButton addTarget:floatButton action:@selector(floatTapped) forControlEvents:UIControlEventTouchUpInside];
        [floatButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:floatButton action:@selector(handlePan:)]];
        [overlayWindow addSubview:floatButton];
        [overlayWindow makeKeyAndVisible];
    });
}
