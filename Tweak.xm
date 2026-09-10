#import <Foundation/Foundation.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

// Use raw POSIX sockets to bypass iOS 18 Network.framework sandbox
static void triggerLocalNetworkRaw(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Create UDP socket
        int sock = socket(AF_INET, SOCK_DGRAM, 0);
        if (sock < 0) return;
        
        // Enable broadcast
        int broadcast = 1;
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof(broadcast));
        
        // Send to multicast/broadcast to trigger local network
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_port = htons(9999);
        addr.sin_addr.s_addr = inet_addr("224.0.0.1");
        
        const char *msg = "ping";
        sendto(sock, msg, strlen(msg), 0, (struct sockaddr *)&addr, sizeof(addr));
        
        close(sock);
    });
}

%ctor {
    // Trigger early to establish local network before vcam needs it
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        triggerLocalNetworkRaw();
    });
    
    // Also trigger periodically
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        triggerLocalNetworkRaw();
    });
}
