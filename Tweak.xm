#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;

static void showCameraSettings() {
    Class settingsClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!settingsClass) return;
    
    id vc = [[settingsClass alloc] init];
    ((void(*)(id, SEL, id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
    
    // Get root VC and present
    UIWindow *keyWindow = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in scene.windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
    }
    
    if (keyWindow && keyWindow.rootViewController) {
        UIViewController *root = keyWindow.rootViewController;
        while (root.presentedViewController) {
            root = root.presentedViewController;
        }
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        [root presentViewController:nav animated:YES completion:nil];
    }
    
    AudioServicesPlaySystemSound(1519);
}

@interface FBFloatButton : UIButton
@end

@implementation FBFloatButton

- (void)floatTapped {
    AudioServicesPlaySystemSound(1519);
    showCameraSettings();
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
