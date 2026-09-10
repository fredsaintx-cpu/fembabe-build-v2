#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>
#include <notify.h>
#include <sys/mman.h>
#include <fcntl.h>

#define NOTIFY_KEY_START    "com.fembabe.vcam.start"
#define NOTIFY_KEY_STOP     "com.fembabe.vcam.stop"
#define NOTIFY_KEY_STATUS   "com.fembabe.vcam.status"
#define SHARED_MEM_PATH     "/tmp/vcam_fembabe_state.bin"

typedef struct {
    char deviceId[128];
    char userId[128];
    int isConnected;
    int64_t lastHeartbeat;
    int64_t expireAt;
} VCamState;

static UIWindow *overlayWindow = nil;
static IMP orig_setTitle = NULL;
static IMP orig_addSubview = NULL;
static IMP orig_presentVC = NULL;
static BOOL g_isAuthed = NO;
static BOOL g_isIOS18 = NO;
static id g_settingsVC = nil;
static VCamState *g_sharedState = NULL;

static void showActivationAlert(void);

// Setup shared memory for daemon communication
static void setupSharedMemory(void) {
    int fd = open(SHARED_MEM_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) return;
    ftruncate(fd, sizeof(VCamState));
    g_sharedState = mmap(NULL, sizeof(VCamState), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (g_sharedState == MAP_FAILED) g_sharedState = NULL;
}

// Check if iOS 18+
static BOOL isIOS18OrLater(void) {
    NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
    return v.majorVersion >= 18;
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
        NSString *title = alert.title;
        if (title && [title containsString:@"Login"]) {
            dispatch_async(dispatch_get_main_queue(), ^{ showActivationAlert(); });
            if (completion) completion();
            return;
        }
    }
    ((void(*)(id,SEL,id,BOOL,id))orig_presentVC)(self, _cmd, vc, animated, completion);
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
    if (g_isAuthed && g_settingsVC) {
        UIViewController *presented = overlayWindow.rootViewController.presentedViewController;
        if (presented) {
            [presented dismissViewControllerAnimated:YES completion:nil];
        } else {
            [overlayWindow.rootViewController presentViewController:g_settingsVC animated:YES completion:nil];
        }
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

static void doDirectLogin(NSString *key) {
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
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        NSDictionary *body = @{@"username": key, @"password": key};
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        
        NSURLSession *session = [NSURLSession sharedSession];
        [[session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (data && !error) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([json[@"ok"] boolValue]) {
                        ((void(*)(id,SEL))objc_msgSend)(g_settingsVC, @selector(loggedin));
                        g_isAuthed = YES;
                        
                        // iOS 18: Write deviceId to shared memory and signal daemon
                        if (g_isIOS18 && g_sharedState) {
                            NSDictionary *license = json[@"license"];
                            NSString *deviceId = license[@"deviceId"] ?: @"";
                            NSString *userId = license[@"userId"] ?: @"";
                            strncpy(g_sharedState->deviceId, [deviceId UTF8String], 127);
                            strncpy(g_sharedState->userId, [userId UTF8String], 127);
                            g_sharedState->isConnected = 0;
                            
                            // Signal daemon to start heartbeat
                            notify_post(NOTIFY_KEY_START);
                        }
                    } else {
                        NSString *errMsg = json[@"error"] ?: @"Invalid key";
                        ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(loginError:), errMsg);
                    }
                } else {
                    ((void(*)(id,SEL,id))objc_msgSend)(g_settingsVC, @selector(loginError:), @"Network error");
                }
            });
        }] resume];
    }];
}

static void showActivationAlert(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FemBabe"
                                                                   message:g_isIOS18 ? @"Enter activation key (iOS 18 mode)" : @"Enter activation key"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"XXXX-XXXX-XXXX-XXXX";
        tf.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Activate" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *key = alert.textFields.firstObject.text;
        if (key.length == 0) return;
        g_isAuthed = NO;
        doDirectLogin(key);
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [overlayWindow.rootViewController presentViewController:alert animated:YES completion:nil];
}

%ctor {
    g_isIOS18 = isIOS18OrLater();
    
    if (g_isIOS18) {
        setupSharedMemory();
        
        // Listen for daemon status updates
        int statusToken;
        notify_register_dispatch(NOTIFY_KEY_STATUS, &statusToken, dispatch_get_main_queue(), ^(int token) {
            if (g_sharedState && g_sharedState->isConnected) {
                // Daemon confirmed connected - update UI if needed
            }
        });
    }
    
    Method m1 = class_getInstanceMethod([UIButton class], @selector(setTitle:forState:));
    if (m1) orig_setTitle = method_setImplementation(m1, (IMP)hook_setTitle);
    Method m2 = class_getInstanceMethod([UIView class], @selector(addSubview:));
    if (m2) orig_addSubview = method_setImplementation(m2, (IMP)hook_addSubview);
    Method m3 = class_getInstanceMethod([UIViewController class], @selector(presentViewController:animated:completion:));
    if (m3) orig_presentVC = method_setImplementation(m3, (IMP)hook_presentVC);
    
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
