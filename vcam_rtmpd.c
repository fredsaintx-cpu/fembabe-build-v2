#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <pthread.h>
#include <fcntl.h>

#define UNIX_SOCK_PATH "/var/mobile/Library/Caches/vcam.sock"

static int client_fd = -1;
static volatile int has_client = 0;

void *forward_thread(void *arg) {
    int *fds = (int*)arg;
    int from = fds[0], to = fds[1];
    free(fds);
    char buf[65536];
    while (1) {
        ssize_t n = read(from, buf, sizeof(buf));
        if (n <= 0) break;
        write(to, buf, n);
    }
    return NULL;
}

void *handle_unix_client(void *arg) {
    int ufd = *(int*)arg;
    free(arg);
    while (!has_client) usleep(10000);
    int *fds1 = malloc(8); fds1[0] = ufd; fds1[1] = client_fd;
    int *fds2 = malloc(8); fds2[0] = client_fd; fds2[1] = ufd;
    pthread_t t1, t2;
    pthread_create(&t1, NULL, forward_thread, fds1);
    pthread_create(&t2, NULL, forward_thread, fds2);
    pthread_join(t1, NULL);
    pthread_join(t2, NULL);
    has_client = 0;
    client_fd = -1;
    close(ufd);
    return NULL;
}

void *unix_server(void *arg) {
    unlink(UNIX_SOCK_PATH);
    int userver = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un uaddr;
    memset(&uaddr, 0, sizeof(uaddr));
    uaddr.sun_family = AF_UNIX;
    strcpy(uaddr.sun_path, UNIX_SOCK_PATH);
    bind(userver, (struct sockaddr*)&uaddr, sizeof(uaddr));
    chmod(UNIX_SOCK_PATH, 0777);
    listen(userver, 5);
    while (1) {
        int *ufd = malloc(sizeof(int));
        *ufd = accept(userver, NULL, NULL);
        if (*ufd < 0) { free(ufd); continue; }
        pthread_t t;
        pthread_create(&t, NULL, handle_unix_client, ufd);
        pthread_detach(t);
    }
    return NULL;
}

int main() {
    pthread_t ut;
    pthread_create(&ut, NULL, unix_server, NULL);
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    *((uint8_t*)&addr) = sizeof(struct sockaddr_in);
    addr.sin_family = AF_INET;
    addr.sin_port = htons(1935);
    addr.sin_addr.s_addr = INADDR_ANY;
    
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) return 1;
    if (listen(server_fd, 5) < 0) return 1;
    
    while (1) {
        int cfd = accept(server_fd, NULL, NULL);
        if (cfd < 0) continue;
        client_fd = cfd;
        has_client = 1;
        while (has_client) usleep(100000);
        close(cfd);
    }
    return 0;
}
