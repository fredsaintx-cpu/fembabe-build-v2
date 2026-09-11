#ifndef RING_BUFFER_H
#define RING_BUFFER_H

#include <stdint.h>
#include <stdatomic.h>

#define RING_BUFFER_PATH "/var/mobile/Library/Caches/com.fembabe.vcam.ring.bin"
#define DARWIN_NOTIFY_FRAME "com.vcam.frame.ready"

#define VCAM_WIDTH  1920
#define VCAM_HEIGHT 1080
#define FRAME_SIZE  (VCAM_WIDTH * VCAM_HEIGHT * 4) // BGRA 32-bit

typedef struct {
    uint32_t width;
    uint32_t height;
    uint64_t timestamp;
    uint32_t size;
    uint8_t pixel_data[FRAME_SIZE];
} VCamFrame;

typedef struct {
    atomic_uint write_index;
    atomic_uint read_index;
    atomic_uint flags;
    VCamFrame frame;
} VCamRingBuffer;

#endif
