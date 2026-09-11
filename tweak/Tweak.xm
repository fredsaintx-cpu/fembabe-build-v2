#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>
#import <sys/mman.h>
#import <fcntl.h>

static UIWindow *overlayWindow = nil;
static IMP orig_setTitle = NULL;
static IMP orig_addSubview = NULL;
static IMP orig_presentVC = NULL;
static IMP orig_getLiveFrame = NULL;
static IMP orig_isRunning = NULL;
static BOOL g_isAuthed = NO;
static id g_settingsVC = nil;

// Ring buffer for RTMP frames from daemon
#define RING_PATH "/tmp/vcam_rtmp_ring.bin"
#define RING_SIZE (16 * 1024 * 1024)  // 16MB
static void *g_ringBase = NULL;
static int g_ringFd = -1;

typedef struct {
    uint32_t magic;         // 0x56434D52 = "VCMR"
    uint32_t writePos;      // Current write position
    uint32_t frameSize;     // Size of current frame
    uint32_t width;
    uint32_t height;
    uint32_t ready;         // Frame ready flag
} RingHeader;

static void showActivationAlert(void);

// v74: Map the ring buffer from daemon
static void mapRingBuffer(void) {
    if (g_ringBase) return;
    
    g_ringFd = open(RING_PATH, O_RDONLY);
    if (g_ringFd < 0) {
        NSLog(@"[FemBabe v74] Ring buffer not found - daemon not running?");
        return;
    }
    
    g_ringBase = mmap(NULL, RING_SIZE, PROT_READ, MAP_SHARED, g_ringFd, 0);
    if (g_ringBase == MAP_FAILED) {
        NSLog(@"[FemBabe v74] mmap failed");
        g_ringBase = NULL;
        close(g_ringFd);
        g_ringFd = -1;
        return;
    }
    NSLog(@"[FemBabe v74] Ring buffer mapped at %p", g_ringBase);
}

// v74: Hook getLiveFrame: to read from ring buffer instead of RTMPServer
static CMSampleBufferRef hook_getLiveFrame(id self, SEL _cmd, CMSampleBufferRef inputBuffer) {
    if (!g_isAuthed || !g_ringBase) {
        if (orig_getLiveFrame) {
            return ((CMSampleBufferRef(*)(id,SEL,CMSampleBufferRef))orig_getLiveFrame)(self, _cmd, inputBuffer);
        }
        return inputBuffer;
    }
    
    RingHeader *header = (RingHeader *)g_ringBase;
    if (header->magic != 0x56434D52 || !header->ready) {
        // No frame ready, return original
        if (orig_getLiveFrame) {
            return ((CMSampleBufferRef(*)(id,SEL,CMSampleBufferRef))orig_getLiveFrame)(self, _cmd, inputBuffer);
        }
        return inputBuffer;
    }
    
    // Frame is ready in ring buffer - create CMSampleBuffer from it
    // For now, just log and pass through - full implementation would create buffer
    static int logCount = 0;
    if (logCount++ % 60 == 0) {
        NSLog(@"[FemBabe v74] Frame ready: %dx%d size=%d", header->width, header->height, header->frameSize);
    }
    
    if (orig_getLiveFrame) {
        return ((CMSampleBufferRef(*)(id,SEL,CMSampleBufferRef))orig_getLiveFrame)(self, _cmd, inputBuffer);
    }
    return inputBuffer;
}

// v74: Force isRunning to return YES
static BOOL hook_isRunning(id self, SEL _cmd) {
    if (g_isAuthed) return YES;
    if (orig_isRunning) return ((BOOL(*)(id,SEL))orig_isRunning)(self, _cmd);
    return NO;
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
                        NSLog(@"[FemBabe v74] Login success!");
                        
                        NSDictionary *encConfig = json[@"encConfig"];
                        if (encConfig[@"ct"]) {
                            NSData *ctData = [[NSData alloc] initWithBase64EncodedString:encConfig[@"ct"] options:0];
                            if (ctData) {
                                NSDictionary *config = [NSJSONSerialization JSONObjectWithData:ctData options:0 error:nil];
                                NSString *sid = config[@"sid"];
                                if (sid) {
                                    ((void(*)(id,SEL,id))objc_msgSend)(api, @selector(setToken:), sid);
                                }
                            }
                        }
                        
                        NSString *licenseSig = json[@"licenseSig"];
                        if (licenseSig) {
                            ((void(*)(id,SEL,id))objc_msgSend)(api, @selector(setToken:), licenseSig);
                        }
                        
                        g_isAuthed = YES;
                        
                        // v74: Map ring buffer after auth
                        mapRingBuffer();
                        
                        ((void(*)(id,SEL))objc_msgSend)(g_settingsVC, @selector(loggedin));
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
    // v74: Hook RTMPServer isRunning
    Class rtmpClass = NSClassFromString(@"RTMPServer");
    if (rtmpClass) {
        Method m = class_getInstanceMethod(rtmpClass, @selector(isRunning));
        if (m) orig_isRunning = method_setImplementation(m, (IMP)hook_isRunning);
    }
    
    // v74: Hook vcamMgr getLiveFrame:
    Class vcamMgr = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
    if (vcamMgr) {
        Method m = class_getInstanceMethod(vcamMgr, @selector(getLiveFrame:));
        if (m) {
            orig_getLiveFrame = method_setImplementation(m, (IMP)hook_getLiveFrame);
            NSLog(@"[FemBabe v74] Hooked getLiveFrame:");
        }
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
