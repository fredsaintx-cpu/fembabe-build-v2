#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;

@interface FBPresentWindow : UIWindow
@end

@implementation FBPresentWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}
@end

@interface FBButton : UIButton
@property (nonatomic) CGPoint dragStart;
@property (nonatomic) CGPoint winStart;
@end

@implementation FBButton

- (void)handleTap {
    AudioServicesPlaySystemSound(1519);
    
    Class loginClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    if (!loginClass) return;
    
    id loginVC = [[loginClass alloc] init];
    if (!loginVC) return;
    
    if ([loginVC respondsToSelector:@selector(setServer:)]) {
        [loginVC performSelector:@selector(setServer:) withObject:@"https://v.fembabe.org"];
    }
    
    [overlayWindow.rootViewController presentViewController:loginVC animated:YES completion:nil];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.dragStart = [gesture locationInView:overlayWindow];
        self.winStart = self.center;
    }
    CGPoint loc = [gesture locationInView:overlayWindow];
    self.center = CGPointMake(self.winStart.x + (loc.x - self.dragStart.x), 
                               self.winStart.y + (loc.y - self.dragStart.y));
}

@end

%ctor {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            UIWindowScene *scene = nil;
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            if (!scene) return;
            
            overlayWindow = [[FBPresentWindow alloc] initWithWindowScene:scene];
            overlayWindow.frame = [UIScreen mainScreen].bounds;
            overlayWindow.windowLevel = UIWindowLevelAlert + 100;
            overlayWindow.backgroundColor = [UIColor clearColor];
            overlayWindow.rootViewController = [[UIViewController alloc] init];
            overlayWindow.rootViewController.view.backgroundColor = [UIColor clearColor];
            overlayWindow.hidden = NO;
            
            // Dark purple color (0.5, 0, 0.5)
            floatButton = [[FBButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
            floatButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.0 blue:0.5 alpha:1.0];
            [floatButton setTitle:@"F" forState:UIControlStateNormal];
            [floatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            floatButton.titleLabel.font = [UIFont boldSystemFontOfSize:24];
            floatButton.layer.cornerRadius = 25;
            floatButton.clipsToBounds = YES;
            
            [floatButton addTarget:floatButton action:@selector(handleTap) forControlEvents:UIControlEventTouchUpInside];
            [floatButton addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:floatButton action:@selector(handlePan:)]];
            
            [overlayWindow addSubview:floatButton];
        });
    }
}
