#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;

@interface FBButton : UIButton
@end

@implementation FBButton
- (void)tapped {
    AudioServicesPlaySystemSound(1519);
}
- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:overlayWindow];
    self.center = CGPointMake(self.center.x + t.x, self.center.y + t.y);
    [g setTranslation:CGPointZero inView:overlayWindow];
}
@end

static IMP origSetTitle = NULL;
static void blockB(id self, SEL _cmd, NSString *title, UIControlState state) {
    if ([title isEqualToString:@"B"]) return;
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
        
        floatButton = [[FBButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
        floatButton.backgroundColor = [UIColor purpleColor];
        [floatButton setTitle:@"F" forState:UIControlStateNormal];
        floatButton.layer.cornerRadius = 25;
        [floatButton addTarget:floatButton action:@selector(tapped) forControlEvents:UIControlEventTouchUpInside];
        [floatButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:floatButton action:@selector(handlePan:)]];
        [overlayWindow addSubview:floatButton];
        [overlayWindow makeKeyAndVisible];
    });
}
