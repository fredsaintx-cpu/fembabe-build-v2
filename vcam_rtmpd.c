#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <pthread.h>
#include <arpa/inet.h>

#define RING_PATH "/var/mobile/Library/Caches/com.fembabe.vcam.ring.bin"
#define FRAME_SIZE (1920 * 1080 * 4)

typedef struct {
    volatile uint32_t write_index;
    volatile uint32_t flags;
    uint32_t width, height;
    uint64_t timestamp;
    uint32_t size;
    uint8_t data[FRAME_SIZE];
} VCamRing;

static VCamRing *ring = NULL;

void init_ring() {
    int fd = open(RING_PATH, O_RDWR | O_CREAT, 0666);
    if (fd < 0) return;
    ftruncate(fd, sizeof(VCamRing));
    ring = mmap(NULL, sizeof(VCamRing), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);
    close(fd);
    if (ring != MAP_FAILED) {
        ring->write_index = 0;
        ring->flags = 1;
        ring->width = 1920;
        ring->height = 1080;
    }
}

int read_exact(int fd, uint8_t *buf, size_t n) {
    size_t t = 0;
    while (t < n) {
        ssize_t r = read(fd, buf + t, n - t);
        if (r <= 0) return -1;
        t += r;
    }
    return 0;
}

int write_all(int fd, uint8_t *buf, size_t n) {
    size_t t = 0;
    while (t < n) {
        ssize_t w = write(fd, buf + t, n - t);
        if (w <= 0) return -1;
        t += w;
    }
    return 0;
}

void send_chunk(int fd, uint8_t csid, uint8_t type, uint32_t stream_id, uint8_t *data, uint32_t len) {
    uint8_t hdr[12];
    hdr[0] = csid;
    hdr[1] = 0; hdr[2] = 0; hdr[3] = 0;
    hdr[4] = (len >> 16) & 0xFF;
    hdr[5] = (len >> 8) & 0xFF;
    hdr[6] = len & 0xFF;
    hdr[7] = type;
    hdr[8] = stream_id & 0xFF;
    hdr[9] = (stream_id >> 8) & 0xFF;
    hdr[10] = (stream_id >> 16) & 0xFF;
    hdr[11] = (stream_id >> 24) & 0xFF;
    write_all(fd, hdr, 12);
    write_all(fd, data, len);
}

void *handle_client(void *arg) {
    int fd = *(int*)arg;
    free(arg);
    
    uint8_t c0c1[1537];
    if (read_exact(fd, c0c1, 1537) < 0) { close(fd); return NULL; }
    
    uint8_t s0s1s2[3073];
    s0s1s2[0] = 0x03;
    memset(s0s1s2 + 1, 0, 4);
    s0s1s2[5] = 0x09; s0s1s2[6] = 0x00; s0s1s2[7] = 0x7c; s0s1s2[8] = 0x02;
    memset(s0s1s2 + 9, 0xCC, 1528);
    memcpy(s0s1s2 + 1537, c0c1 + 1, 1536);
    if (write_all(fd, s0s1s2, 3073) < 0) { close(fd); return NULL; }
    
    uint8_t c2[1536];
    if (read_exact(fd, c2, 1536) < 0) { close(fd); return NULL; }
    
    uint8_t winack[] = {0x00, 0x4C, 0x4B, 0x40};
    send_chunk(fd, 0x02, 5, 0, winack, 4);
    
    uint8_t bw[] = {0x00, 0x4C, 0x4B, 0x40, 0x02};
    send_chunk(fd, 0x02, 6, 0, bw, 5);
    
    uint8_t chunksize[] = {0x00, 0x01, 0x00, 0x00};
    send_chunk(fd, 0x02, 1, 0, chunksize, 4);
    
    uint8_t buf[65536];
    uint32_t chunk_size = 128;
    int got_connect = 0, got_create = 0, got_publish = 0;
    
    while (1) {
        uint8_t basic;
        if (read_exact(fd, &basic, 1) < 0) break;
        
        uint8_t fmt = (basic >> 6) & 0x03;
        uint32_t csid = basic & 0x3F;
        if (csid == 0) { uint8_t b; read_exact(fd, &b, 1); csid = b + 64; }
        else if (csid == 1) { uint8_t b[2]; read_exact(fd, b, 2); csid = b[0] + 64 + (b[1]<<8); }
        
        uint32_t msg_len = 0;
        uint8_t msg_type = 0;
        
        if (fmt == 0) {
            uint8_t hdr[11];
            if (read_exact(fd, hdr, 11) < 0) break;
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
        
        uint32_t pos = 0, remaining = msg_len;
        while (remaining > 0) {
            uint32_t to_read = remaining > chunk_size ? chunk_size : remaining;
            if (read_exact(fd, buf + pos, to_read) < 0) goto done;
            pos += to_read;
            remaining -= to_read;
            if (remaining > 0) {
                uint8_t cont;
                if (read_exact(fd, &cont, 1) < 0) goto done;
            }
        }
        
        if (msg_type == 1 && msg_len >= 4) {
            chunk_size = (buf[0]<<24)|(buf[1]<<16)|(buf[2]<<8)|buf[3];
        }
        else if (msg_type == 20 && !got_connect && msg_len > 10) {
            got_connect = 1;
            uint8_t result[] = {
                0x02, 0x00, 0x07, '_', 'r', 'e', 's', 'u', 'l', 't',
                0x00, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x03,
                0x00, 0x06, 'f', 'm', 's', 'V', 'e', 'r',
                0x02, 0x00, 0x0E, 'F', 'M', 'S', '/', '3', ',', '5', ',', '7', ',', '7', '0', '0', '9',
                0x00, 0x0C, 'c', 'a', 'p', 'a', 'b', 'i', 'l', 'i', 't', 'i', 'e', 's',
                0x00, 0x40, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x00, 0x00, 0x09,
                0x03,
                0x00, 0x05, 'l', 'e', 'v', 'e', 'l',
                0x02, 0x00, 0x06, 's', 't', 'a', 't', 'u', 's',
                0x00, 0x04, 'c', 'o', 'd', 'e',
                0x02, 0x00, 0x1D, 'N', 'e', 't', 'C', 'o', 'n', 'n', 'e', 'c', 't', 'i', 'o', 'n', '.', 'C', 'o', 'n', 'n', 'e', 'c', 't', '.', 'S', 'u', 'c', 'c', 'e', 's', 's',
                0x00, 0x00, 0x09
            };
            send_chunk(fd, 0x03, 20, 0, result, sizeof(result));
        }
        else if (msg_type == 20 && got_connect && !got_create) {
            got_create = 1;
            uint8_t result[] = {
                0x02, 0x00, 0x07, '_', 'r', 'e', 's', 'u', 'l', 't',
                0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x05,
                0x00, 0x3F, 0xF0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
            };
            send_chunk(fd, 0x03, 20, 0, result, sizeof(result));
        }
        else if (msg_type == 20 && got_create && !got_publish) {
            got_publish = 1;
            uint8_t status[] = {
                0x02, 0x00, 0x08, 'o', 'n', 'S', 't', 'a', 't', 'u', 's',
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                0x05,
                0x03,
                0x00, 0x05, 'l', 'e', 'v', 'e', 'l',
                0x02, 0x00, 0x06, 's', 't', 'a', 't', 'u', 's',
                0x00, 0x04, 'c', 'o', 'd', 'e',
                0x02, 0x00, 0x17, 'N', 'e', 't', 'S', 't', 'r', 'e', 'a', 'm', '.', 'P', 'u', 'b', 'l', 'i', 's', 'h', '.', 'S', 't', 'a', 'r', 't',
                0x00, 0x00, 0x09
            };
            send_chunk(fd, 0x05, 20, 1, status, sizeof(status));
        }
        else if (msg_type == 9 && ring && ring != MAP_FAILED) {
            if (msg_len <= FRAME_SIZE) {
                memcpy(ring->data, buf, msg_len);
                ring->size = msg_len;
                ring->timestamp++;
                ring->write_index++;
            }
        }
    }
done:
    close(fd);
    return NULL;
}

int main() {
    init_ring();
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) return 1;
    
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
