#import <Foundation/Foundation.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <unistd.h>
#import <pthread.h>

#define LOCAL_PORT 1935
#define REMOTE_HOST "v.fembabe.org"
#define REMOTE_PORT 1935

typedef struct {
    int client_fd;
    int server_fd;
} proxy_conn_t;

void *forward_thread(void *arg) {
    proxy_conn_t *conn = (proxy_conn_t *)arg;
    char buffer[65536];
    ssize_t n;
    while ((n = read(conn->client_fd, buffer, sizeof(buffer))) > 0) {
        write(conn->server_fd, buffer, n);
    }
    shutdown(conn->server_fd, SHUT_WR);
    return NULL;
}

void *reverse_thread(void *arg) {
    proxy_conn_t *conn = (proxy_conn_t *)arg;
    char buffer[65536];
    ssize_t n;
    while ((n = read(conn->server_fd, buffer, sizeof(buffer))) > 0) {
        write(conn->client_fd, buffer, n);
    }
    shutdown(conn->client_fd, SHUT_WR);
    return NULL;
}

void handle_client(int client_fd) {
    NSLog(@"[vcam_netd] New RTMP connection");
    
    struct hostent *he = gethostbyname(REMOTE_HOST);
    if (!he) {
        NSLog(@"[vcam_netd] DNS failed for %s", REMOTE_HOST);
        close(client_fd);
        return;
    }
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        close(client_fd);
        return;
    }
    
    struct sockaddr_in server_addr;
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(REMOTE_PORT);
    memcpy(&server_addr.sin_addr, he->h_addr_list[0], he->h_length);
    
    if (connect(server_fd, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        NSLog(@"[vcam_netd] Connect failed to %s:%d", REMOTE_HOST, REMOTE_PORT);
        close(server_fd);
        close(client_fd);
        return;
    }
    
    NSLog(@"[vcam_netd] Proxying to %s:%d", REMOTE_HOST, REMOTE_PORT);
    
    proxy_conn_t *conn = malloc(sizeof(proxy_conn_t));
    conn->client_fd = client_fd;
    conn->server_fd = server_fd;
    
    pthread_t fwd_t, rev_t;
    pthread_create(&fwd_t, NULL, forward_thread, conn);
    pthread_create(&rev_t, NULL, reverse_thread, conn);
    pthread_join(fwd_t, NULL);
    pthread_join(rev_t, NULL);
    
    close(client_fd);
    close(server_fd);
    free(conn);
    NSLog(@"[vcam_netd] Connection closed");
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        NSLog(@"[vcam_netd] RTMP Proxy 127.0.0.1:%d -> %s:%d", LOCAL_PORT, REMOTE_HOST, REMOTE_PORT);
        
        int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
        int opt = 1;
        setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
        
        struct sockaddr_in addr;
        memset(&addr, 0, sizeof(addr));
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        addr.sin_port = htons(LOCAL_PORT);
        
        if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
            NSLog(@"[vcam_netd] Bind failed");
            return 1;
        }
        listen(listen_fd, 10);
        NSLog(@"[vcam_netd] Listening...");
        
        while (1) {
            struct sockaddr_in client_addr;
            socklen_t client_len = sizeof(client_addr);
            int client_fd = accept(listen_fd, (struct sockaddr *)&client_addr, &client_len);
            if (client_fd >= 0) {
                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                    handle_client(client_fd);
                });
            }
        }
        return 0;
    }
}
