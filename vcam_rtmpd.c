#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/stat.h>

#define SOCK_PATH "/var/mobile/Library/Caches/vcam.sock"

void *fwd(void *arg) {
    int *p = (int*)arg;
    char b[65536];
    ssize_t n;
    while ((n = read(p[0], b, sizeof(b))) > 0) write(p[1], b, n);
    free(p);
    return NULL;
}

int main() {
    unlink(SOCK_PATH);
    
    int us = socket(AF_UNIX, SOCK_STREAM, 0);
    struct sockaddr_un ua;
    memset(&ua, 0, sizeof(ua));
    ua.sun_family = AF_UNIX;
    strncpy(ua.sun_path, SOCK_PATH, sizeof(ua.sun_path)-1);
    bind(us, (struct sockaddr*)&ua, sizeof(ua));
    chmod(SOCK_PATH, 0777);
    listen(us, 1);
    
    int ts = socket(AF_INET, SOCK_STREAM, 0);
    int o = 1;
    setsockopt(ts, SOL_SOCKET, SO_REUSEADDR, &o, sizeof(o));
    struct sockaddr_in ta;
    memset(&ta, 0, sizeof(ta));
    ((char*)&ta)[0] = sizeof(ta);
    ta.sin_family = AF_INET;
    ta.sin_port = htons(1935);
    bind(ts, (struct sockaddr*)&ta, sizeof(ta));
    listen(ts, 5);
    
    while (1) {
        int uc = accept(us, NULL, NULL);
        if (uc < 0) continue;
        int tc = accept(ts, NULL, NULL);
        if (tc < 0) { close(uc); continue; }
        
        int *a = malloc(8); a[0]=tc; a[1]=uc;
        int *b = malloc(8); b[0]=uc; b[1]=tc;
        pthread_t t1, t2;
        pthread_create(&t1, NULL, fwd, a);
        pthread_create(&t2, NULL, fwd, b);
        pthread_detach(t1);
        pthread_detach(t2);
    }
}
