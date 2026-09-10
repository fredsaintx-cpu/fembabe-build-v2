#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;

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
        
        // Present Settings VC like beta1_1_9
        Class cls = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
        if (!cls) return;
        id vc = [[cls alloc] init];
        if (!vc) return;
        if ([vc respondsToSelector:@selector(setServer:)])
            ((void(*)(id,SEL,id))objc_msgSend)(vc, @selector(setServer:), @"https://v.fembabe.org");
        [overlayWindow.rootViewController presentViewController:vc animated:YES completion:nil];
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

static IMP origSetTitle = NULL;
static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if ([title isEqualToString:@"B"]) { self.hidden = YES; return; }
    ((void(*)(id,SEL,id,UIControlState))origSetTitle)(self, _cmd, title, state);
}

%ctor {
    @autoreleasepool {
        Method m = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
        if (m) origSetTitle = method_setImplementation(m, (IMP)hook_setTitle);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
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
            btn.backgroundColor = [UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1];
            [btn setTitle:@"F" forState:UIControlStateNormal];
            [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            btn.layer.cornerRadius = 25;
            btn.clipsToBounds = YES;
            [btn addTarget:btn action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(handlePan:)]];
            [overlayWindow addSubview:btn];
        });
    }
}
