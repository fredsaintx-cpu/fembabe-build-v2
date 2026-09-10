#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static IMP orig_setTitle = NULL;
static IMP orig_addSubview = NULL;

// Hook setTitle - hide B button
static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (title && [title isEqualToString:@"B"]) {
        self.hidden = YES;
        return;
    }
    if (orig_setTitle) {
        ((void(*)(id,SEL,id,UIControlState))orig_setTitle)(self, _cmd, title, state);
    }
}

// Hook addSubview - hide orange button class
static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    // Check if it's the orange float button class
    Class orangeClass = NSClassFromString(@"iHsfaTkdhwkzopQfsnwBd");
    if (orangeClass && [view isKindOfClass:orangeClass]) {
        view.hidden = YES;
        return; // Don't add it
    }
    if (orig_addSubview) {
        ((void(*)(id,SEL,id))orig_addSubview)(self, _cmd, view);
    }
}

@interface FBPresentWindow : UIWindow
@end
@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self || hit == self.rootViewController.view) ? nil : hit;
}
@end

@interface FBButton : UIButton
@property (nonatomic) CGPoint dragStart;
@property (nonatomic) CGPoint winStart;
@end

@implementation FBButton
- (void)handleTap {
    AudioServicesPlaySystemSound(1519);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe Login"
                                                                   message:@"Enter your activation key"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"Activation Key";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length == 0) return;
        
        Class cls = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
        if (!cls) return;
        id vc = [[cls alloc] init];
        if (!vc) return;
        
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setUsername:), key);
        ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setPassword:), key);
        
        [overlayWindow.rootViewController presentViewController:vc animated:YES completion:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                ((void(*)(id,SEL))objc_msgSend)(vc, @selector(login));
            });
        }];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [overlayWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan) {
        self.dragStart = [g locationInView:overlayWindow];
        self.winStart = self.center;
    }
    CGPoint p = [g locationInView:overlayWindow];
    self.center = CGPointMake(self.winStart.x + p.x - self.dragStart.x, self.winStart.y + p.y - self.dragStart.y);
}
@end

%ctor {
    // Hook setTitle on UIButton
    Method m1 = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
    if (m1) orig_setTitle = method_setImplementation(m1, (IMP)hook_setTitle);
    
    // Hook addSubview on UIView
    Method m2 = class_getInstanceMethod([UIView class], @selector(addSubview:));
    if (m2) orig_addSubview = method_setImplementation(m2, (IMP)hook_addSubview);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        @autoreleasepool {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s; break;
                }
            }
            if (!scene) return;
            
            overlayWindow = [[FBPresentWindow alloc] initWithWindowScene:scene];
            overlayWindow.frame = UIScreen.mainScreen.bounds;
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = UIColor.clearColor;
            overlayWindow.rootViewController = [UIViewController new];
            overlayWindow.hidden = NO;
            
            FBButton *btn = [[FBButton alloc] initWithFrame:CGRectMake(20,100,50,50)];
            btn.backgroundColor = [UIColor colorWithRed:0.4 green:0.0 blue:0.6 alpha:1.0];
            [btn setTitle:@"F" forState:UIControlStateNormal];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            btn.layer.cornerRadius = 25;
            btn.clipsToBounds = YES;
            [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)]];
            [overlayWindow addSubview:btn];
        }
    });
}
