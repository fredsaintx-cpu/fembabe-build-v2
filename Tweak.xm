#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;
static UITextField *keyField = nil;
static UIView *activationPanel = nil;

static void doLogin(NSString *key) {
    // Get Settings VC class
    Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!settingsClass) return;
    
    // Create and configure
    id vc = [[settingsClass alloc] init];
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setUsername:), key);
    ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setPassword:), key);
    
    // Hide our panel
    activationPanel.hidden = YES;
    [keyField resignFirstResponder];
    
    // Present it so user can tap native Login button
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [overlayWindow.rootViewController presentViewController:nav animated:YES completion:nil];
    
    AudioServicesPlaySystemSound(1519);
}

static void showActivationPanel(void) {
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
        [activationPanel addSubview:keyField];
        
        UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        activateBtn.frame = CGRectMake(15, 75, 120, 44);
        [activateBtn setTitle:@"Activate" forState:UIControlStateNormal];
        [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        activateBtn.backgroundColor = [UIColor purpleColor];
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

// Hide camera's orange button
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
