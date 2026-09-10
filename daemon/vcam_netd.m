// vcam_netd - FemBabe network daemon for iOS 18
// Handles heartbeat/connection to v.fembabe.org as root (bypasses sandbox)

#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <notify.h>
#include <sys/mman.h>
#include <fcntl.h>

#define NOTIFY_KEY_START    "com.fembabe.vcam.start"
#define NOTIFY_KEY_STOP     "com.fembabe.vcam.stop"
#define NOTIFY_KEY_STATUS   "com.fembabe.vcam.status"
#define SHARED_MEM_PATH     "/tmp/vcam_fembabe_state.bin"
#define SERVER_URL          "https://v.fembabe.org"

// Shared state structure
typedef struct {
    char deviceId[128];
    char userId[128];
    int isConnected;
    int64_t lastHeartbeat;
    int64_t expireAt;
} VCamState;

static VCamState *g_sharedState = NULL;
static BOOL g_running = YES;
static NSTimer *g_heartbeatTimer = nil;

static void setupSharedMemory(void) {
    int fd = open(SHARED_MEM_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) {
        NSLog(@"[vcam_netd] Failed to open shared mem");
        return;
    }
    ftruncate(fd, sizeof(VCamState));
    g_sharedState = mmap(NULL, sizeof(VCamState), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    
    if (g_sharedState == MAP_FAILED) {
        NSLog(@"[vcam_netd] mmap failed");
        g_sharedState = NULL;
    } else {
        NSLog(@"[vcam_netd] Shared memory ready");
    }
}

static void doHeartbeat(void) {
    if (!g_sharedState || strlen(g_sharedState->deviceId) == 0) return;
    
    NSString *deviceId = [NSString stringWithUTF8String:g_sharedState->deviceId];
    NSURL *url = [NSURL URLWithString:@"https://v.fembabe.org/api/vcam/heartbeat"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{@"deviceId": deviceId};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (data && !err) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json[@"ok"] boolValue]) {
                g_sharedState->isConnected = 1;
                g_sharedState->lastHeartbeat = (int64_t)[[NSDate date] timeIntervalSince1970];
                notify_post(NOTIFY_KEY_STATUS);
                NSLog(@"[vcam_netd] Heartbeat OK");
            }
        } else {
            NSLog(@"[vcam_netd] Heartbeat failed: %@", err);
        }
    }] resume];
}

static void startHeartbeatLoop(void) {
    if (g_heartbeatTimer) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        g_heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 repeats:YES block:^(NSTimer *t) {
            doHeartbeat();
        }];
        // Immediate first heartbeat
        doHeartbeat();
    });
    NSLog(@"[vcam_netd] Heartbeat loop started");
}

static void stopHeartbeatLoop(void) {
    if (g_heartbeatTimer) {
        [g_heartbeatTimer invalidate];
        g_heartbeatTimer = nil;
    }
    if (g_sharedState) {
        g_sharedState->isConnected = 0;
        notify_post(NOTIFY_KEY_STATUS);
    }
    NSLog(@"[vcam_netd] Heartbeat loop stopped");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[vcam_netd] Starting FemBabe network daemon for iOS 18+");
        
        setupSharedMemory();
        
        // Register for start notification
        int startToken;
        notify_register_dispatch(NOTIFY_KEY_START, &startToken, dispatch_get_main_queue(), ^(int token) {
            NSLog(@"[vcam_netd] Received START signal");
            startHeartbeatLoop();
        });
        
        // Register for stop notification
        int stopToken;
        notify_register_dispatch(NOTIFY_KEY_STOP, &stopToken, dispatch_get_main_queue(), ^(int token) {
            NSLog(@"[vcam_netd] Received STOP signal");
            stopHeartbeatLoop();
        });
        
        NSLog(@"[vcam_netd] Daemon ready, waiting for signals...");
        
        // Run forever
        [[NSRunLoop mainRunLoop] run];
        
        return 0;
    }
}
