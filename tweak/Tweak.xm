#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>
#import <notify.h>
#import <sys/mman.h>
#import <fcntl.h>

#define NOTIFY_KEY "com.fembabe.vcam.state"
#define STATE_FILE "/tmp/vcam_fembabe_state.bin"

// State shared with daemon
typedef struct {
    uint8_t isConnected;
    uint8_t isStreaming;
    uint32_t frameCount;
    char serverUrl[256];
} VCamState;

static UIWindow *overlayWindow = nil;
static IMP orig_setTitle = NULL;
static IMP orig_addSubview = NULL;
static IMP orig_presentVC = NULL;
static IMP orig_isConnected = NULL;
static IMP orig_setRtmp = NULL;
static BOOL g_isAuthed = NO;
static id g_settingsVC = nil;
static int g_notifyToken = 0;
static VCamState *g_state = NULL;

static void showActivationAlert(void);

// Map shared state from daemon
static void mapSharedState(void) {
    int fd = open(STATE_FILE, O_RDONLY);
    if (fd < 0) return;
    
    g_state = mmap(NULL, sizeof(VCamState), PROT_READ, MAP_SHARED, fd, 0);
    close(fd);
    
    if (g_state == MAP_FAILED) g_state = NULL;
}

// Check if daemon is connected
static BOOL isDaemonConnected(void) {
    if (!g_state) mapSharedState();
    return g_state ? (g_state->isConnected != 0) : NO;
}

// Hook isConnected - check daemon state
static BOOL hook_isConnected(id self, SEL _cmd) {
    if (isDaemonConnected()) return YES;
    if (orig_isConnected) return ((BOOL(*)(id,SEL))orig_isConnected)(self, _cmd);
    return NO;
}

// Hook setRtmp: to redirect to localhost proxy
static void hook_setRtmp(id self, SEL _cmd, NSString *rtmpUrl) {
    NSLog(@"[FemBabe] Original RTMP URL: %@", rtmpUrl);
    
    // Replace server with localhost proxy
    if (rtmpUrl && [rtmpUrl hasPrefix:@"rtmp://"]) {
        // Extract path after host
        NSRange hostEnd = [rtmpUrl rangeOfString:@"/" options:0 range:NSMakeRange(7, rtmpUrl.length - 7)];
        NSString *path = @"";
        if (hostEnd.location != NSNotFound) {
            path = [rtmpUrl substringFromIndex:hostEnd.location];
        }
        
        // Redirect to localhost proxy
        NSString *localUrl = [NSString stringWithFormat:@"rtmp://127.0.0.1:1935%@", path];
        NSLog(@"[FemBabe] Redirected to: %@", localUrl);
        
        // Store original server for daemon
        if (g_state) {
            strncpy(g_state->serverUrl, rtmpUrl.UTF8String, 255);
        }
        
        if (orig_setRtmp) ((void(*)(id,SEL,id))orig_setRtmp)(self, _cmd, localUrl);
        return;
    }
    
    if (orig_setRtmp) ((void(*)(id,SEL,id))orig_setRtmp)(self, _cmd, rtmpUrl);
}

static void hook_setTitle(UIButton *self, SEL _cmd, NSString *title, UIControlState state) {
    if (title && [title isEqualToString:@"B"]) { self.hidden = YES; return; }
    if (orig_setTitle) ((void(*)(id,SEL,id,UIControlState))orig_setTitle)(self, _cmd, title, state);
}

static void hook_addSubview(UIView *self, SEL _cmd, UIView *view) {
    Class orangeClass = NSClassFromString(@"iHsfaTkdhwkzopQfsnwBd");
    if (orangeClass && [view isKindOfClass:orangeClass]) { view.hidden = YES; return; }
    if (orig_addSubview) ((void(*)(id,SEL,id))orig_addSubview)(self, _cmd, view);
}

static void hook_presentVC(UIViewController *self, SEL _cmd, UIViewController *vc, BOOL animated, void (^completion)(void)) {
    if ([vc isKindOfClass:[UIAlertController class]]) {
        UIAlertController *alert = (UIAlertController *)vc;
        if (alert.title && [alert.title containsString:@"Login"]) {
            dispatch_async(dispatch_get_main_queue(), ^{ showActivationAlert(); });
            if (completion) completion();
            return;
        }
    }
    ((void(*)(id,SEL,id,BOOL,id))orig_presentVC)(self, _cmd, vc, animated, completion);
}

@interface FBWindow : UIWindow
@end
@implementation FBWindow
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
    if (g_isAuthed && g_settingsVC) {
        UIViewController *p = overlayWindow.rootViewController.presentedViewController;
        if (p) [p dismissViewControllerAnimated:YES completion:nil];
        else [overlayWindow.rootViewController presentViewController:g_settingsVC animated:YES completion:nil];
        return;
    }
    showActivationAlert();
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

static void doLogin(NSString *key) {
    Class apiClass = NSClassFromString(@"iCdfsIdfdEdfsNdfdftqWer");
    if (!apiClass) return;
    
    id api = ((id(*)(id,SEL))objc_msgSend)(apiClass, @selector(sharedInstance));
    ((void(*)(id,SEL,id))objc_msgSend)(api, @selector(setUrl:), @"https://v.fembabe.org");
    
    Class vcClass = NSClassFromString(@"iMswGsfawYfewewUfdsmn");
    g_settingsVC = [[vcClass alloc] init];
    ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(setServer:), @"https://v.fembabe.org");
    ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(setUsername:), key);
    ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(setPassword:), key);
    
    [overlayWindow.rootViewController presentViewController:g_settingsVC animated:YES completion:^{
        NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/login2"];
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        req.HTTPBody = [[NSString stringWithFormat:@"{\"username\":\"%@\",\"password\":\"%@\"}", key, key] dataUsingEncoding:NSUTF8StringEncoding];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (data && !e) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([json[@"ok"] boolValue]) {
                        ((void(*)(id,SEL))objc_msgSend)(g_settingsVC, @selector(loggedin));
                        g_isAuthed = YES;
                    } else {
                        ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(loginError:), json[@"error"] ?: @"Invalid key");
                    }
                } else {
                    ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(loginError:), @"Network error");
                }
            });
        }] resume];
    }];
}

static void showActivationAlert(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe" message:@"Enter activation key" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"XXXX-XXXX-XXXX-XXXX";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length > 0) { g_isAuthed = NO; doLogin(key); }
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [overlayWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%ctor {
    // Register for daemon state notifications
    notify_register_check(NOTIFY_KEY, &g_notifyToken);
    
    // Map shared state
    mapSharedState();
    
    // Hook vcam manager
    Class vcamMgr = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    if (vcamMgr) {
        Method m = class_getInstanceMethod(vcamMgr, @selector(isConnected));
        if (m) orig_isConnected = method_setImplementation(m, (IMP)hook_isConnected);
        
        // Hook setRtmp: to redirect to localhost
        Method mr = class_getInstanceMethod(vcamMgr, @selector(setRtmp:));
        if (mr) orig_setRtmp = method_setImplementation(mr, (IMP)hook_setRtmp);
    }
    
    Method m1 = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
    if (m1) orig_setTitle = method_setImplementation(m1, (IMP)hook_setTitle);
    Method m2 = class_getInstanceMethod([UIView class], @selector(addSubview:));
    if (m2) orig_addSubview = method_setImplementation(m2, (IMP)hook_addSubview);
    Method m3 = class_getInstanceMethod([UIViewController class], @selector(presentViewController:animated:completion:));
    if (m3) orig_presentVC = method_setImplementation(m3, (IMP)hook_presentVC);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]] && s.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)s; break;
            }
        }
        if (!scene) return;
        
        overlayWindow = [[FBWindow alloc] initWithWindowScene:scene];
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
    });
}
