#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pthread.h>
#include <syslog.h>
#include <notify.h>
#include "ring_buffer.h"

static VCamRingBuffer *ring_buf = NULL;
static volatile int running = 1;

int init_ring_buffer() {
    int fd = open(RING_BUFFER_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) {
        syslog(LOG_ERR, "[vcam] Failed to open ring buffer");
        return -1;
    }
    
    ftruncate(fd, sizeof(VCamRingBuffer));
    ring_buf = mmap(NULL, sizeof(VCamRingBuffer), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    
    if (ring_buf == MAP_FAILED) {
        syslog(LOG_ERR, "[vcam] Failed to mmap ring buffer");
        return -1;
    }
    
    atomic_init(&ring_buf->write_index, 0);
    atomic_init(&ring_buf->read_index, 0);
    atomic_init(&ring_buf->flags, 1);
    ring_buf->frame.width = VCAM_WIDTH;
    ring_buf->frame.height = VCAM_HEIGHT;
    
    syslog(LOG_INFO, "[vcam] Ring buffer initialized at %s", RING_BUFFER_PATH);
    return 0;
}

int read_exact(int fd, uint8_t *buf, size_t n) {
    size_t total = 0;
    while (total < n) {
        ssize_t r = read(fd, buf + total, n - total);
        if (r <= 0) return -1;
        total += r;
    }
    return 0;
}

int rtmp_handshake(int fd) {
    uint8_t c0c1[1537], s0s1s2[3073];
    
    if (read_exact(fd, c0c1, 1537) < 0) return -1;
    if (c0c1[0] != 0x03) return -1;
    
    s0s1s2[0] = 0x03;
    memset(s0s1s2 + 1, 0, 1536);
    memcpy(s0s1s2 + 1537, c0c1 + 1, 1536);
    
    if (write(fd, s0s1s2, 3073) != 3073) return -1;
    
    uint8_t c2[1536];
    if (read_exact(fd, c2, 1536) < 0) return -1;
    
    syslog(LOG_INFO, "[vcam] RTMP handshake complete");
    return 0;
}

void write_frame(const uint8_t *data, uint32_t size) {
    if (!ring_buf || size > FRAME_SIZE) return;
    
    ring_buf->frame.size = size;
    ring_buf->frame.timestamp++;
    memcpy(ring_buf->frame.pixel_data, data, size);
    
    atomic_fetch_add(&ring_buf->write_index, 1);
    notify_post(DARWIN_NOTIFY_FRAME);
}

void *handle_client(void *arg) {
    int fd = *(int*)arg;
    free(arg);
    
    syslog(LOG_INFO, "[vcam] Client connected");
    
    if (rtmp_handshake(fd) < 0) {
        close(fd);
        return NULL;
    }
    
    uint8_t buf[8192];
    uint32_t chunk_size = 128;
    
    while (running) {
        uint8_t basic;
        if (read_exact(fd, &basic, 1) < 0) break;
        
        uint8_t fmt = (basic >> 6) & 0x03;
        uint32_t csid = basic & 0x3F;
        
        if (csid == 0) {
            uint8_t b; read_exact(fd, &b, 1); csid = b + 64;
        } else if (csid == 1) {
            uint8_t b[2]; read_exact(fd, b, 2); csid = b[0] + 64 + (b[1] << 8);
        }
        
        uint32_t timestamp = 0, msg_len = 0;
        uint8_t msg_type = 0;
        
        if (fmt == 0) {
            uint8_t hdr[11];
            if (read_exact(fd, hdr, 11) < 0) break;
            timestamp = (hdr[0]<<16)|(hdr[1]<<8)|hdr[2];
            msg_len = (hdr[3]<<16)|(hdr[4]<<8)|hdr[5];
            msg_type = hdr[6];
        } else if (fmt == 1) {
            uint8_t hdr[7];
            if (read_exact(fd, hdr, 7) < 0) break;
            msg_len = (hdr[3]<<16)|(hdr[4]<<8)|hdr[5];
            msg_type = hdr[6];
        } else if (fmt == 2) {
            uint8_t hdr[3];
            if (read_exact(fd, hdr, 3) < 0) break;
        }
        
        if (msg_len > sizeof(buf)) msg_len = sizeof(buf);
        
        uint32_t remaining = msg_len;
        uint32_t pos = 0;
        while (remaining > 0) {
            uint32_t to_read = remaining > chunk_size ? chunk_size : remaining;
            if (read_exact(fd, buf + pos, to_read) < 0) break;
            pos += to_read;
            remaining -= to_read;
            if (remaining > 0) {
                uint8_t cont;
                if (read_exact(fd, &cont, 1) < 0) break;
            }
        }
        
        if (msg_type == 1 && msg_len >= 4) {
            chunk_size = (buf[0]<<24)|(buf[1]<<16)|(buf[2]<<8)|buf[3];
            syslog(LOG_INFO, "[vcam] Chunk size: %u", chunk_size);
        } else if (msg_type == 9) {
            write_frame(buf, msg_len);
        } else if (msg_type == 20 || msg_type == 17) {
            uint8_t resp[32] = {0x03,0,0,0,0,0,1,20,0,0,0,0,0x05};
            write(fd, resp, 13);
        }
    }
    
    close(fd);
    syslog(LOG_INFO, "[vcam] Client disconnected");
    return NULL;
}

int main() {
    openlog("vcam_rtmpd", LOG_PID, LOG_DAEMON);
    syslog(LOG_INFO, "[vcam] Starting FemBabe RTMP daemon v2.0");
    
    if (init_ring_buffer() < 0) return 1;
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        syslog(LOG_ERR, "[vcam] socket failed");
        return 1;
    }
    
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(1935);
    
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        syslog(LOG_ERR, "[vcam] bind failed");
        return 1;
    }
    
    if (listen(server_fd, 5) < 0) {
        syslog(LOG_ERR, "[vcam] listen failed");
        return 1;
    }
    
    syslog(LOG_INFO, "[vcam] Listening on port 1935");
    
    while (running) {
        struct sockaddr_in client;
        socklen_t len = sizeof(client);
        int client_fd = accept(server_fd, (struct sockaddr*)&client, &len);
        if (client_fd < 0) continue;
        
        int *fd_ptr = malloc(sizeof(int));
        *fd_ptr = client_fd;
        
        pthread_t thread;
        pthread_create(&thread, NULL, handle_client, fd_ptr);
        pthread_detach(thread);
    }
    
    return 0;
}
