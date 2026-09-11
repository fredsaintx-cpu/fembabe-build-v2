#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <pthread.h>

#define SOCK_PATH "/var/mobile/Library/Caches/vcam.sock"

void *copy_data(void *arg) {
    int *fds = (int*)arg;
    char buf[65536];
    ssize_t n;
    while ((n = read(fds[0], buf, sizeof(buf))) > 0)
        write(fds[1], buf, n);
    close(fds[0]);
    close(fds[1]);
    free(fds);
    return NULL;
}

void *handle_obs(void *arg) {
    int obs_fd = *(int*)arg;
    free(arg);
    
    // Connect to Unix socket (where RTMPServer will connect)
    int usock = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un uaddr = {0};
    uaddr.sun_len = sizeof(uaddr);
    uaddr.sun_family = AF_UNIX;
    strcpy(uaddr.sun_path, SOCK_PATH);
    
    // Wait for RTMPServer to connect to Unix socket
    // Actually we need RTMPServer to be the server on unix socket
    // Let's flip it - we create unix server, RTMPServer connects
    
    // For now just forward to existing unix client
    if (connect(usock, (struct sockaddr*)&uaddr, sizeof(uaddr)) < 0) {
        close(obs_fd);
        close(usock);
        return NULL;
    }
    
    int *fds1 = malloc(8); fds1[0] = obs_fd; fds1[1] = usock;
    int *fds2 = malloc(8); fds2[0] = usock; fds2[1] = obs_fd;
    
    pthread_t t1, t2;
    pthread_create(&t1, NULL, copy_data, fds1);
    pthread_create(&t2, NULL, copy_data, fds2);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    return NULL;
}

int main() {
    // Create Unix socket server for SpringBoard to connect to
    unlink(SOCK_PATH);
    int usrv = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un uaddr = {0};
    uaddr.sun_len = sizeof(uaddr);
    uaddr.sun_family = AF_UNIX;
    strcpy(uaddr.sun_path, SOCK_PATH);
    bind(usrv, (struct sockaddr*)&uaddr, sizeof(uaddr));
    chmod(SOCK_PATH, 0777);
    listen(usrv, 1);
    
    // TCP server for OBS
    int tsrv = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(tsrv, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in taddr = {0};
    taddr.sin_len = sizeof(taddr);
    taddr.sin_family = AF_INET;
    taddr.sin_port = htons(1935);
    bind(tsrv, (struct sockaddr*)&taddr, sizeof(taddr));
    listen(tsrv, 5);
    
    while (1) {
        // Wait for SpringBoard to connect to Unix socket
        int uclient = accept(usrv, NULL, NULL);
        if (uclient < 0) continue;
        
        // Wait for OBS to connect to TCP
        int tclient = accept(tsrv, NULL, NULL);
        if (tclient < 0) { close(uclient); continue; }
        
        // Forward bidirectionally
        int *fds1 = malloc(8); fds1[0] = tclient; fds1[1] = uclient;
        int *fds2 = malloc(8); fds2[0] = uclient; fds2[1] = tclient;
        
        pthread_t t1, t2;
        pthread_create(&t1, NULL, copy_data, fds1);
        pthread_create(&t2, NULL, copy_data, fds2);
        pthread_detach(t1);
        pthread_detach(t2);
    }
    return 0;
}
