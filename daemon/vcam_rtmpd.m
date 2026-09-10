// FemBabe RTMP Proxy Daemon for iOS 18
// Listens on 127.0.0.1:1935, forwards to actual RTMP server
// Bypasses iOS 18 local network sandbox by running as root

#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <notify.h>
#import <sys/mman.h>
#import <fcntl.h>
#import <unistd.h>

#define LISTEN_PORT 1935
#define NOTIFY_KEY "com.fembabe.vcam.state"
#define STATE_FILE "/tmp/vcam_fembabe_state.bin"
#define BUFFER_SIZE 65536

// State shared with tweak
typedef struct {
    uint8_t isConnected;
    uint8_t isStreaming;
    uint32_t frameCount;
    char serverUrl[256];
} VCamState;

static VCamState *g_state = NULL;
static int g_notifyToken = 0;
static volatile BOOL g_running = YES;

static void setupSharedState(void) {
    int fd = open(STATE_FILE, O_RDWR | O_CREAT, 0666);
    if (fd < 0) {
        NSLog(@"[vcam_rtmpd] Failed to create state file");
        return;
    }
    ftruncate(fd, sizeof(VCamState));
    g_state = mmap(NULL, sizeof(VCamState), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    
    if (g_state == MAP_FAILED) {
        NSLog(@"[vcam_rtmpd] mmap failed");
        g_state = NULL;
        return;
    }
    
    memset(g_state, 0, sizeof(VCamState));
    NSLog(@"[vcam_rtmpd] Shared state initialized at %s", STATE_FILE);
}

static void updateState(BOOL connected, BOOL streaming) {
    if (g_state) {
        g_state->isConnected = connected ? 1 : 0;
        g_state->isStreaming = streaming ? 1 : 0;
    }
    // Notify tweak of state change
    notify_post(NOTIFY_KEY);
}

static void proxyConnection(int clientSock, const char *serverHost, int serverPort) {
    NSLog(@"[vcam_rtmpd] New client connection, forwarding to %s:%d", serverHost, serverPort);
    
    // Connect to actual RTMP server
    int serverSock = socket(AF_INET, SOCK_STREAM, 0);
    if (serverSock < 0) {
        NSLog(@"[vcam_rtmpd] Failed to create server socket");
        close(clientSock);
        return;
    }
    
    struct sockaddr_in serverAddr;
    memset(&serverAddr, 0, sizeof(serverAddr));
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons(serverPort);
    
    // Resolve hostname
    struct hostent *host = gethostbyname(serverHost);
    if (!host) {
        NSLog(@"[vcam_rtmpd] Failed to resolve %s", serverHost);
        close(serverSock);
        close(clientSock);
        return;
    }
    memcpy(&serverAddr.sin_addr, host->h_addr_list[0], host->h_length);
    
    if (connect(serverSock, (struct sockaddr *)&serverAddr, sizeof(serverAddr)) < 0) {
        NSLog(@"[vcam_rtmpd] Failed to connect to server");
        close(serverSock);
        close(clientSock);
        return;
    }
    
    NSLog(@"[vcam_rtmpd] Connected to server %s:%d", serverHost, serverPort);
    updateState(YES, YES);
    
    // Set non-blocking
    fcntl(clientSock, F_SETFL, O_NONBLOCK);
    fcntl(serverSock, F_SETFL, O_NONBLOCK);
    
    char buffer[BUFFER_SIZE];
    fd_set readfds;
    int maxfd = (clientSock > serverSock) ? clientSock : serverSock;
    
    while (g_running) {
        FD_ZERO(&readfds);
        FD_SET(clientSock, &readfds);
        FD_SET(serverSock, &readfds);
        
        struct timeval tv = {1, 0};
        int ret = select(maxfd + 1, &readfds, NULL, NULL, &tv);
        if (ret < 0) break;
        if (ret == 0) continue;
        
        // Client -> Server
        if (FD_ISSET(clientSock, &readfds)) {
            ssize_t n = read(clientSock, buffer, BUFFER_SIZE);
            if (n <= 0) break;
            write(serverSock, buffer, n);
            if (g_state) g_state->frameCount++;
        }
        
        // Server -> Client
        if (FD_ISSET(serverSock, &readfds)) {
            ssize_t n = read(serverSock, buffer, BUFFER_SIZE);
            if (n <= 0) break;
            write(clientSock, buffer, n);
        }
    }
    
    NSLog(@"[vcam_rtmpd] Connection closed");
    updateState(YES, NO);
    close(serverSock);
    close(clientSock);
}

static void runProxy(void) {
    int listenSock = socket(AF_INET, SOCK_STREAM, 0);
    if (listenSock < 0) {
        NSLog(@"[vcam_rtmpd] Failed to create listen socket");
        return;
    }
    
    int opt = 1;
    setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(LISTEN_PORT);
    
    if (bind(listenSock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        NSLog(@"[vcam_rtmpd] Failed to bind to 127.0.0.1:%d", LISTEN_PORT);
        close(listenSock);
        return;
    }
    
    listen(listenSock, 5);
    NSLog(@"[vcam_rtmpd] Listening on 127.0.0.1:%d", LISTEN_PORT);
    updateState(YES, NO);
    
    while (g_running) {
        struct sockaddr_in clientAddr;
        socklen_t clientLen = sizeof(clientAddr);
        
        int clientSock = accept(listenSock, (struct sockaddr *)&clientAddr, &clientLen);
        if (clientSock < 0) continue;
        
        // Get target server from state file or use default
        const char *targetHost = "v.fembabe.org";
        int targetPort = 1935;
        
        if (g_state && g_state->serverUrl[0]) {
            // Parse server URL if set
            // For now use default
        }
        
        // Handle in same thread for simplicity (could fork/thread later)
        proxyConnection(clientSock, targetHost, targetPort);
    }
    
    close(listenSock);
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[vcam_rtmpd] FemBabe RTMP Proxy Daemon starting...");
        
        // Setup shared state
        setupSharedState();
        
        // Register for notify
        notify_register_check(NOTIFY_KEY, &g_notifyToken);
        
        // Run proxy
        runProxy();
        
        NSLog(@"[vcam_rtmpd] Daemon exiting");
        return 0;
    }
}
