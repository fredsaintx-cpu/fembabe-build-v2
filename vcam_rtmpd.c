/*
 * vcam_rtmpd - Clean RTMP daemon for iOS virtual camera
 * Receives RTMP stream from OBS, writes frames to ring buffer
 * No DRM, no roothide dependency, works on Dopamine
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/mman.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>

#define RTMP_PORT 1935
#define RING_BUFFER_PATH "/tmp/vcam_rtmp_ring.bin"
#define RING_BUFFER_SIZE (4 * 1024 * 1024)  // 4MB ring buffer
#define MAX_FRAME_SIZE (256 * 1024)          // 256KB max frame

// Ring buffer header
typedef struct {
    uint32_t magic;           // 0x56434D52 = "VCMR"
    uint32_t write_pos;       // Current write position
    uint32_t frame_count;     // Total frames written
    uint32_t width;           // Video width
    uint32_t height;          // Video height
    uint32_t fps;             // Frames per second
    uint32_t last_frame_size; // Size of last frame
    uint32_t flags;           // Status flags
} RingHeader;

static volatile int running = 1;
static int ring_fd = -1;
static void *ring_buffer = MAP_FAILED;

// Initialize ring buffer
int init_ring_buffer(void) {
    ring_fd = open(RING_BUFFER_PATH, O_RDWR | O_CREAT, 0666);
    if (ring_fd < 0) {
        perror("[vcam_rtmpd] open ring buffer");
        return -1;
    }
    
    if (ftruncate(ring_fd, RING_BUFFER_SIZE) < 0) {
        perror("[vcam_rtmpd] ftruncate");
        close(ring_fd);
        return -1;
    }
    
    ring_buffer = mmap(NULL, RING_BUFFER_SIZE, PROT_READ | PROT_WRITE, 
                       MAP_SHARED, ring_fd, 0);
    if (ring_buffer == MAP_FAILED) {
        perror("[vcam_rtmpd] mmap");
        close(ring_fd);
        return -1;
    }
    
    // Initialize header
    RingHeader *hdr = (RingHeader *)ring_buffer;
    hdr->magic = 0x56434D52;  // "VCMR"
    hdr->write_pos = sizeof(RingHeader);
    hdr->frame_count = 0;
    hdr->width = 1920;
    hdr->height = 1080;
    hdr->fps = 30;
    hdr->flags = 1;  // Active
    
    printf("[vcam_rtmpd] Ring buffer initialized at %s\n", RING_BUFFER_PATH);
    return 0;
}

// Write frame to ring buffer
void write_frame(const uint8_t *data, uint32_t size) {
    if (ring_buffer == MAP_FAILED || size > MAX_FRAME_SIZE) return;
    
    RingHeader *hdr = (RingHeader *)ring_buffer;
    uint32_t data_start = sizeof(RingHeader);
    uint32_t data_size = RING_BUFFER_SIZE - data_start;
    
    // Wrap around if needed
    uint32_t pos = hdr->write_pos;
    if (pos < data_start) pos = data_start;
    if (pos + size + 4 > RING_BUFFER_SIZE) {
        pos = data_start;
    }
    
    // Write frame size + data
    uint8_t *buf = (uint8_t *)ring_buffer;
    memcpy(buf + pos, &size, 4);
    memcpy(buf + pos + 4, data, size);
    
    hdr->write_pos = pos + 4 + size;
    hdr->last_frame_size = size;
    hdr->frame_count++;
}

// Read exactly n bytes
int read_exact(int fd, uint8_t *buf, size_t n) {
    size_t total = 0;
    while (total < n) {
        ssize_t r = read(fd, buf + total, n - total);
        if (r <= 0) return -1;
        total += r;
    }
    return 0;
}

// RTMP C0+C1 handshake
int rtmp_handshake(int client_fd) {
    uint8_t c0c1[1537], s0s1s2[3073];
    
    // Read C0+C1
    if (read_exact(client_fd, c0c1, 1537) < 0) {
        printf("[vcam_rtmpd] Handshake C0C1 failed\n");
        return -1;
    }
    
    if (c0c1[0] != 0x03) {
        printf("[vcam_rtmpd] Invalid RTMP version: %d\n", c0c1[0]);
        return -1;
    }
    
    // Build S0+S1+S2
    s0s1s2[0] = 0x03;  // S0
    memset(s0s1s2 + 1, 0, 1536);  // S1 (zeros ok for simple impl)
    memcpy(s0s1s2 + 1537, c0c1 + 1, 1536);  // S2 = C1
    
    if (write(client_fd, s0s1s2, 3073) != 3073) {
        printf("[vcam_rtmpd] Handshake S0S1S2 write failed\n");
        return -1;
    }
    
    // Read C2
    uint8_t c2[1536];
    if (read_exact(client_fd, c2, 1536) < 0) {
        printf("[vcam_rtmpd] Handshake C2 failed\n");
        return -1;
    }
    
    printf("[vcam_rtmpd] Handshake complete\n");
    return 0;
}

// Read RTMP chunk header
int read_chunk_header(int fd, uint8_t *fmt, uint32_t *cs_id, 
                      uint32_t *timestamp, uint32_t *msg_len,
                      uint8_t *msg_type, uint32_t *msg_stream_id) {
    uint8_t basic;
    if (read_exact(fd, &basic, 1) < 0) return -1;
    
    *fmt = (basic >> 6) & 0x03;
    *cs_id = basic & 0x3F;
    
    if (*cs_id == 0) {
        uint8_t b;
        if (read_exact(fd, &b, 1) < 0) return -1;
        *cs_id = b + 64;
    } else if (*cs_id == 1) {
        uint8_t b[2];
        if (read_exact(fd, b, 2) < 0) return -1;
        *cs_id = b[0] + 64 + (b[1] << 8);
    }
    
    // Message header based on fmt
    if (*fmt == 0) {
        uint8_t hdr[11];
        if (read_exact(fd, hdr, 11) < 0) return -1;
        *timestamp = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2];
        *msg_len = (hdr[3] << 16) | (hdr[4] << 8) | hdr[5];
        *msg_type = hdr[6];
        *msg_stream_id = hdr[7] | (hdr[8] << 8) | (hdr[9] << 16) | (hdr[10] << 24);
    } else if (*fmt == 1) {
        uint8_t hdr[7];
        if (read_exact(fd, hdr, 7) < 0) return -1;
        *timestamp = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2];
        *msg_len = (hdr[3] << 16) | (hdr[4] << 8) | hdr[5];
        *msg_type = hdr[6];
    } else if (*fmt == 2) {
        uint8_t hdr[3];
        if (read_exact(fd, hdr, 3) < 0) return -1;
        *timestamp = (hdr[0] << 16) | (hdr[1] << 8) | hdr[2];
    }
    // fmt == 3: no header
    
    return 0;
}

// Handle RTMP client
void *handle_client(void *arg) {
    int client_fd = *(int *)arg;
    free(arg);
    
    printf("[vcam_rtmpd] Client connected\n");
    
    if (rtmp_handshake(client_fd) < 0) {
        close(client_fd);
        return NULL;
    }
    
    uint8_t *msg_buf = malloc(MAX_FRAME_SIZE);
    uint32_t chunk_size = 128;  // Default RTMP chunk size
    
    // Per-stream state
    uint32_t last_timestamp = 0, last_msg_len = 0;
    uint8_t last_msg_type = 0;
    uint32_t last_msg_stream_id = 0;
    uint32_t bytes_read = 0;
    
    while (running) {
        uint8_t fmt;
        uint32_t cs_id, timestamp, msg_len;
        uint8_t msg_type;
        uint32_t msg_stream_id;
        
        if (read_chunk_header(client_fd, &fmt, &cs_id, 
                              &timestamp, &msg_len, &msg_type, &msg_stream_id) < 0) {
            break;
        }
        
        // Use previous values for fmt > 0
        if (fmt > 0) {
            timestamp = last_timestamp;
            if (fmt > 1) {
                msg_len = last_msg_len;
                msg_type = last_msg_type;
            }
            if (fmt > 2) {
                msg_stream_id = last_msg_stream_id;
            }
        }
        
        // Save for next chunk
        last_timestamp = timestamp;
        last_msg_len = msg_len;
        last_msg_type = msg_type;
        last_msg_stream_id = msg_stream_id;
        
        if (msg_len > MAX_FRAME_SIZE) {
            printf("[vcam_rtmpd] Message too large: %u\n", msg_len);
            break;
        }
        
        // Read chunk data
        uint32_t to_read = msg_len - bytes_read;
        if (to_read > chunk_size) to_read = chunk_size;
        
        if (read_exact(client_fd, msg_buf + bytes_read, to_read) < 0) {
            break;
        }
        bytes_read += to_read;
        
        // Complete message?
        if (bytes_read >= msg_len) {
            // Handle message
            if (msg_type == 1 && msg_len >= 4) {
                // Set Chunk Size
                chunk_size = (msg_buf[0] << 24) | (msg_buf[1] << 16) | 
                             (msg_buf[2] << 8) | msg_buf[3];
                printf("[vcam_rtmpd] Chunk size: %u\n", chunk_size);
            } else if (msg_type == 9) {
                // Video data - write to ring buffer
                write_frame(msg_buf, msg_len);
            } else if (msg_type == 20 || msg_type == 17) {
                // AMF command - send simple response
                // For connect/createStream/publish, just acknowledge
                uint8_t result[] = {0x02, 0x00, 0x07, '_', 'r', 'e', 's', 'u', 'l', 't',
                                    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                    0x05};  // Null
                // Basic chunk header + result
                uint8_t response[32];
                response[0] = 0x03;  // fmt=0, cs_id=3
                response[1] = 0; response[2] = 0; response[3] = 0;  // timestamp
                response[4] = 0; response[5] = 0; response[6] = sizeof(result);  // length
                response[7] = 20;  // AMF0 command
                response[8] = 0; response[9] = 0; response[10] = 0; response[11] = 0;
                memcpy(response + 12, result, sizeof(result));
                write(client_fd, response, 12 + sizeof(result));
            }
            
            bytes_read = 0;
        }
    }
    
    free(msg_buf);
    close(client_fd);
    printf("[vcam_rtmpd] Client disconnected\n");
    return NULL;
}

int main(int argc, char *argv[]) {
    printf("[vcam_rtmpd] Starting - FemBabe RTMP daemon v1.0\n");
    
    // Initialize ring buffer
    if (init_ring_buffer() < 0) {
        return 1;
    }
    
    // Create server socket
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("[vcam_rtmpd] socket");
        return 1;
    }
    
    int opt = 1;
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(RTMP_PORT);
    
    if (bind(server_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("[vcam_rtmpd] bind");
        close(server_fd);
        return 1;
    }
    
    if (listen(server_fd, 5) < 0) {
        perror("[vcam_rtmpd] listen");
        close(server_fd);
        return 1;
    }
    
    printf("[vcam_rtmpd] Listening on port %d\n", RTMP_PORT);
    
    while (running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        int client_fd = accept(server_fd, (struct sockaddr *)&client_addr, &client_len);
        if (client_fd < 0) {
            if (errno == EINTR) continue;
            perror("[vcam_rtmpd] accept");
            break;
        }
        
        printf("[vcam_rtmpd] Connection from %s:%d\n", 
               inet_ntoa(client_addr.sin_addr), ntohs(client_addr.sin_port));
        
        int *fd_ptr = malloc(sizeof(int));
        *fd_ptr = client_fd;
        
        pthread_t thread;
        if (pthread_create(&thread, NULL, handle_client, fd_ptr) != 0) {
            close(client_fd);
            free(fd_ptr);
        } else {
            pthread_detach(thread);
        }
    }
    
    close(server_fd);
    if (ring_buffer != MAP_FAILED) {
        munmap(ring_buffer, RING_BUFFER_SIZE);
    }
    if (ring_fd >= 0) {
        close(ring_fd);
    }
    
    return 0;
}
