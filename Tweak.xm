#import <UIKit/UIKit.h>
#import <sys/mman.h>
#import <fcntl.h>
#import <notify.h>
#import <stdatomic.h>

#define RING_BUFFER_PATH "/var/mobile/Library/Caches/com.fembabe.vcam.ring.bin"
#define DARWIN_NOTIFY_FRAME "com.vcam.frame.ready"
#define VCAM_WIDTH  1920
#define VCAM_HEIGHT 1080
#define FRAME_SIZE  (VCAM_WIDTH * VCAM_HEIGHT * 4)

typedef struct {
    uint32_t width;
    uint32_t height;
    uint64_t timestamp;
    uint32_t size;
    uint8_t pixel_data[FRAME_SIZE];
} VCamFrame;

typedef struct {
    atomic_uint write_index;
    atomic_uint read_index;
    atomic_uint flags;
    VCamFrame frame;
} VCamRingBuffer;

@interface ifdsflwoWdasdYfsdfJd : NSObject
+ (id)sharedInstance;
- (void)setLive:(BOOL)live;
- (BOOL)getLive;
- (void)enqueue:(id)frame;
@end

@interface iMswGsfawYfewewUfdsmn : UIViewController {
    NSThread *serverThread;
    NSTimer *timer;
}
@property (nonatomic, retain) NSThread *serverThread;
@end

@interface RTMPServer : NSObject
- (BOOL)isRunning;
- (void)startServerLoop;
- (void)stopServer;
@end

static VCamRingBuffer *g_ring = NULL;
static uint32_t g_last_idx = 0;

static void setup_ring() {
    if (g_ring) return;
    int fd = open(RING_BUFFER_PATH, O_RDONLY);
    if (fd >= 0) {
        g_ring = (VCamRingBuffer *)mmap(NULL, sizeof(VCamRingBuffer), PROT_READ, MAP_SHARED, fd, 0);
        close(fd);
        if (g_ring == MAP_FAILED) g_ring = NULL;
    }
}

%hook RTMPServer
- (BOOL)isRunning {
    return YES;
}
- (void)startServerLoop {
    // Block - our daemon owns port 1935
}
- (void)stopServer {
    // Block
}
%end

%hook iMswGsfawYfewewUfdsmn
- (void)viewDidLoad {
    %orig;
    
    // Force serverThread to non-nil
    Ivar ivar = class_getInstanceVariable([self class], "serverThread");
    if (ivar) {
        NSThread *fakeThread = [[NSThread alloc] init];
        object_setIvar(self, ivar, fakeThread);
    }
    
    // Kill the timer that resets state
    Ivar timerIvar = class_getInstanceVariable([self class], "timer");
    if (timerIvar) {
        NSTimer *t = object_getIvar(self, timerIvar);
        if (t) [t invalidate];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // Force Live toggle enabled
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        for (UIView *v in self.view.subviews) {
            [self enableSwitches:v];
        }
    });
}

%new
- (void)enableSwitches:(UIView *)view {
    if ([view isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)view;
        sw.enabled = YES;
    }
    for (UIView *sub in view.subviews) {
        [self enableSwitches:sub];
    }
}
%end

%hook ifdsflwoWdasdYfsdfJd
- (id)getLiveFrame:(id)arg1 {
    setup_ring();
    
    if (g_ring) {
        uint32_t idx = atomic_load(&g_ring->write_index);
        if (idx != g_last_idx && g_ring->frame.size > 0) {
            g_last_idx = idx;
            // Frame data available at g_ring->frame.pixel_data
            // TODO: Convert to CVPixelBuffer and return
        }
    }
    
    return %orig(arg1);
}
%end

%ctor {
    %init(RTMPServer = objc_getClass("RTMPServer"),
          iMswGsfawYfewewUfdsmn = objc_getClass("iMswGsfawYfewewUfdsmn"),
          ifdsflwoWdasdYfsdfJd = objc_getClass("ifdsflwoWdasdYfsdfJd"));
    
    // Listen for frame notifications
    int token;
    notify_register_dispatch(DARWIN_NOTIFY_FRAME, &token, dispatch_get_main_queue(), ^(int t) {
        // New frame available
    });
    
    NSLog(@"[FemBabe] Hook loaded - ring buffer at %s", RING_BUFFER_PATH);
}
