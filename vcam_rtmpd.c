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

#define RING_BUFFER_PATH "/var/mobile/Library/Caches/com.fembabe.vcam.ring.bin"
#define VCAM_WIDTH  1920
#define VCAM_HEIGHT 1080
#define FRAME_SIZE  (VCAM_WIDTH * VCAM_HEIGHT * 4)

typedef struct {
    volatile uint32_t write_index;
    volatile uint32_t read_index;
    volatile uint32_t flags;
    uint32_t width;
    uint32_t height;
    uint64_t timestamp;
    uint32_t size;
    uint8_t pixel_data[FRAME_SIZE];
} VCamRingBuffer;

static VCamRingBuffer *ring_buf = NULL;
static volatile int running = 1;

int init_ring_buffer() {
    int fd = open(RING_BUFFER_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) return -1;
    
    ftruncate(fd, sizeof(VCamRingBuffer));
    ring_buf = mmap(NULL, sizeof(VCamRingBuffer), PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    
    if (ring_buf == MAP_FAILED) return -1;
    
    ring_buf->write_index = 0;
    ring_buf->read_index = 0;
    ring_buf->flags = 1;
    ring_buf->width = VCAM_WIDTH;
    ring_buf->height = VCAM_HEIGHT;
    
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
    
    return 0;
}

void write_frame(const uint8_t *data, uint32_t size) {
    if (!ring_buf || size > FRAME_SIZE) return;
    
    ring_buf->size = size;
    ring_buf->timestamp++;
    memcpy(ring_buf->pixel_data, data, size);
    ring_buf->write_index++;
}

void *handle_client(void *arg) {
    int fd = *(int*)arg;
    free(arg);
    
    if (rtmp_handshake(fd) < 0) {
        close(fd);
        return NULL;
    }
    
    uint8_t buf[65536];
    uint32_t chunk_size = 128;
    uint32_t msg_len = 0, msg_read = 0;
    uint8_t msg_type = 0;
    
    while (running) {
        uint8_t basic;
        if (read_exact(fd, &basic, 1) < 0) break;
        
        uint8_t fmt = (basic >> 6) & 0x03;
        uint32_t csid = basic & 0x3F;
        
        if (csid == 0) { uint8_t b; read_exact(fd, &b, 1); csid = b + 64; }
        else if (csid == 1) { uint8_t b[2]; read_exact(fd, b, 2); csid = b[0] + 64 + (b[1]<<8); }
        
        if (fmt == 0) {
            uint8_t hdr[11]; read_exact(fd, hdr, 11);
            msg_len = (hdr[3]<<16)|(hdr[4]<<8)|hdr[5];
            msg_type = hdr[6];
            msg_read = 0;
        } else if (fmt == 1) {
            uint8_t hdr[7]; read_exact(fd, hdr, 7);
            msg_len = (hdr[3]<<16)|(hdr[4]<<8)|hdr[5];
            msg_type = hdr[6];
            msg_read = 0;
        } else if (fmt == 2) {
            uint8_t hdr[3]; read_exact(fd, hdr, 3);
        }
        
        if (msg_len > sizeof(buf)) msg_len = sizeof(buf);
        
        uint32_t to_read = msg_len - msg_read;
        if (to_read > chunk_size) to_read = chunk_size;
        
        if (read_exact(fd, buf + msg_read, to_read) < 0) break;
        msg_read += to_read;
        
        if (msg_read >= msg_len) {
            if (msg_type == 1 && msg_len >= 4) {
                chunk_size = (buf[0]<<24)|(buf[1]<<16)|(buf[2]<<8)|buf[3];
            } else if (msg_type == 9) {
                write_frame(buf, msg_len);
            } else if (msg_type == 20 || msg_type == 17) {
                uint8_t resp[] = {0x03,0,0,0,0,0,1,20,0,0,0,0,0x05};
                write(fd, resp, sizeof(resp));
            }
            msg_read = 0;
        }
    }
    
    close(fd);
    return NULL;
}

int main() {
    if (init_ring_buffer() < 0) return 1;
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) return 1;
    
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(1935);
    
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) return 1;
    if (listen(server_fd, 5) < 0) return 1;
    
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
