#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <AudioToolbox/AudioToolbox.h>

static UIWindow *overlayWindow = nil;
static UIButton *floatButton = nil;
static UITextField *keyField = nil;
static UIView *activationPanel = nil;
static UILabel *statusLabel = nil;

static void updateStatus(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (statusLabel) statusLabel.text = msg;
    });
}

static void doLogin(NSString *key) {
    updateStatus(@"Activating...");
    
    // Direct HTTP call to API
    NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/activate"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [[NSString stringWithFormat:@"{\"key\":\"%@\"}", key] dataUsingEncoding:NSUTF8StringEncoding];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            updateStatus([NSString stringWithFormat:@"Error: %@", err.localizedDescription]);
            return;
        }
        
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)resp;
        if (httpResp.statusCode != 200) {
            updateStatus([NSString stringWithFormat:@"HTTP %ld", (long)httpResp.statusCode]);
            return;
        }
        
        // Parse response
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json[@"ok"] boolValue]) {
            updateStatus(@"Invalid key");
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Save state
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"FemBabeActivated"];
            [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"FemBabeKey"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            // Set vcam state
            Class vcam = NSClassFromString(@"ifdsflwoWdasdYfsdfJd");
            if (vcam) {
                id inst = ((id(*)(Class,SEL))objc_msgSend)(vcam, @selector(sharedInstance));
                ((void(*)(id,SEL,BOOL))objc_msgSend)(inst, @selector(setFloatWindow:), YES);
                ((void(*)(id,SEL,BOOL))objc_msgSend)(inst, @selector(setLive:), YES);
            }
            
            updateStatus(@"Activated!");
            AudioServicesPlaySystemSound(1519);
            
            // Hide panel after delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                activationPanel.hidden = YES;
            });
        });
    }] resume];
}

static void showActivationPanel(void) {
    if (!activationPanel) {
        activationPanel = [[UIView alloc] initWithFrame:CGRectMake(40, 200, 300, 180)];
        activationPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
        activationPanel.layer.cornerRadius = 12;
        
        keyField = [[UITextField alloc] initWithFrame:CGRectMake(15, 20, 270, 44)];
        keyField.placeholder = @"Enter activation key";
        keyField.backgroundColor = [UIColor whiteColor];
        keyField.layer.cornerRadius = 8;
        keyField.textAlignment = NSTextAlignmentCenter;
        keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        [activationPanel addSubview:keyField];
        
        statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 70, 270, 24)];
        statusLabel.textColor = [UIColor whiteColor];
        statusLabel.textAlignment = NSTextAlignmentCenter;
        statusLabel.font = [UIFont systemFontOfSize:14];
        [activationPanel addSubview:statusLabel];
        
        UIButton *activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        activateBtn.frame = CGRectMake(15, 105, 130, 50);
        [activateBtn setTitle:@"Activate" forState:UIControlStateNormal];
        [activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        activateBtn.backgroundColor = [UIColor purpleColor];
        activateBtn.layer.cornerRadius = 8;
        [activateBtn addTarget:floatButton action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
        [activationPanel addSubview:activateBtn];
        
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(155, 105, 130, 50);
        [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        closeBtn.backgroundColor = [UIColor darkGrayColor];
        closeBtn.layer.cornerRadius = 8;
        [closeBtn addTarget:floatButton action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
        [activationPanel addSubview:closeBtn];
        
        [overlayWindow addSubview:activationPanel];
    }
    statusLabel.text = @"";
    activationPanel.hidden = NO;
    [keyField becomeFirstResponder];
}

@interface FBFloatButton : UIButton
@end

@implementation FBFloatButton
- (void)floatTapped { AudioServicesPlaySystemSound(1519); showActivationPanel(); }
- (void)activateTapped {
    NSString *key = keyField.text;
    if (key.length > 0) { [keyField resignFirstResponder]; doLogin(key); }
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
