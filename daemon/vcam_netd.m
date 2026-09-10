#import <Foundation/Foundation.h>
#include <notify.h>
#include <sys/mman.h>
#include <fcntl.h>

#define NOTIFY_START    "com.fembabe.vcam.start"
#define NOTIFY_STOP     "com.fembabe.vcam.stop"
#define NOTIFY_STATUS   "com.fembabe.vcam.status"
#define SHARED_PATH     "/tmp/vcam_fembabe_state.bin"

typedef struct {
    char deviceId[128];
    char userId[128];
    int isConnected;
    int64_t lastHeartbeat;
    int64_t expireAt;
} VCamState;

static VCamState *g_state = NULL;
static NSTimer *g_timer = nil;

static void setupMem(void) {
    int fd = open(SHARED_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) return;
    ftruncate(fd, sizeof(VCamState));
    g_state = (VCamState *)mmap(NULL, sizeof(VCamState), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (g_state == MAP_FAILED) g_state = NULL;
}

static void doHeartbeat(void) {
    if (!g_state || strlen(g_state->deviceId) == 0) return;
    
    NSString *deviceId = [NSString stringWithUTF8String:g_state->deviceId];
    NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/heartbeat"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = [[NSString stringWithFormat:@"{\"deviceId\":\"%@\"}", deviceId] dataUsingEncoding:NSUTF8StringEncoding];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (data && !err) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json[@"ok"] boolValue]) {
                g_state->isConnected = 1;
                g_state->lastHeartbeat = (int64_t)[[NSDate date] timeIntervalSince1970];
                notify_post(NOTIFY_STATUS);
                NSLog(@"[vcam_netd] heartbeat OK");
            }
        }
    }] resume];
}

static void startLoop(void) {
    if (g_timer) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        doHeartbeat();
        g_timer = [NSTimer scheduledTimerWithTimeInterval:30.0 repeats:YES block:^(NSTimer *t) { doHeartbeat(); }];
    });
}

static void stopLoop(void) {
    [g_timer invalidate]; g_timer = nil;
    if (g_state) { g_state->isConnected = 0; notify_post(NOTIFY_STATUS); }
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[vcam_netd] iOS 18 network daemon starting");
        setupMem();
        
        int t1, t2;
        notify_register_dispatch(NOTIFY_START, &t1, dispatch_get_main_queue(), ^(int t) { startLoop(); });
        notify_register_dispatch(NOTIFY_STOP, &t2, dispatch_get_main_queue(), ^(int t) { stopLoop(); });
        
        [[NSRunLoop mainRunLoop] run];
        return 0;
    }
}
