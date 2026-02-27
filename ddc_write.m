// ddc_write.m — Raw DDC/CI VCP write for Apple Silicon
// Usage: ./ddc_write <vcp_code> <value>
// Example: ./ddc_write 0x04 1   (factory reset)
//
// Compile: clang -o ddc_write ddc_write.m -framework IOKit -framework CoreGraphics -framework Foundation

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <CoreGraphics/CoreGraphics.h>

typedef CFTypeRef IOAVService;
extern IOAVService IOAVServiceCreateWithService(CFAllocatorRef allocator, io_service_t service);
extern IOReturn IOAVServiceWriteI2C(IOAVService service, uint32_t chipAddress, uint32_t dataAddress, void *inputBuffer, uint32_t inputBufferSize);
extern IOReturn IOAVServiceReadI2C(IOAVService service, uint32_t chipAddress, uint32_t offset, void *outputBuffer, uint32_t outputBufferSize);

#define DDC_ADDRESS 0x37
#define DATA_ADDRESS 0x51

static IOAVService findDisplayService(void) {
    io_iterator_t iter;
    kern_return_t kr = IOServiceGetMatchingServices(
        kIOMainPortDefault,
        IOServiceNameMatching("DCPAVServiceProxy"),
        &iter
    );
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Error: Could not find display services\n");
        return NULL;
    }

    io_service_t service;
    IOAVService avService = NULL;
    while ((service = IOIteratorNext(iter)) != IO_OBJECT_NULL) {
        avService = IOAVServiceCreateWithService(kCFAllocatorDefault, service);
        IOObjectRelease(service);
        if (avService) break;
    }
    IOObjectRelease(iter);
    return avService;
}

static uint8_t checksum(uint8_t init, uint8_t *data, int start, int end) {
    uint8_t chk = init;
    for (int i = start; i <= end; i++) {
        chk ^= data[i];
    }
    return chk;
}

static int ddc_write(IOAVService service, uint8_t vcp, uint16_t value) {
    uint8_t packet[7];
    packet[0] = 0x84;           // length: 4 bytes follow (Set VCP)
    packet[1] = 0x03;           // Set VCP Feature opcode
    packet[2] = vcp;            // VCP code
    packet[3] = (value >> 8);   // value high byte
    packet[4] = value & 0xFF;   // value low byte
    packet[5] = checksum(DDC_ADDRESS << 1 ^ DATA_ADDRESS, packet, 0, 4);

    IOReturn ret = IOAVServiceWriteI2C(service, DDC_ADDRESS, DATA_ADDRESS, packet, 6);
    return ret == kIOReturnSuccess ? 0 : -1;
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <vcp_code> <value>\n", argv[0]);
        fprintf(stderr, "  vcp_code: hex (0x04) or decimal (4)\n");
        fprintf(stderr, "  value:    hex (0x01) or decimal (1)\n");
        fprintf(stderr, "\nExample: %s 0x04 1  (factory reset)\n", argv[0]);
        return 1;
    }

    unsigned long vcp = strtoul(argv[1], NULL, 0);
    unsigned long value = strtoul(argv[2], NULL, 0);

    if (vcp > 0xFF) {
        fprintf(stderr, "Error: VCP code must be 0x00-0xFF\n");
        return 1;
    }
    if (value > 0xFFFF) {
        fprintf(stderr, "Error: Value must be 0x0000-0xFFFF\n");
        return 1;
    }

    IOAVService service = findDisplayService();
    if (!service) {
        fprintf(stderr, "Error: No display found. Is it connected via USB-C/DisplayPort?\n");
        return 1;
    }

    printf("Sending VCP 0x%02lx = %lu to first detected display...\n", vcp, value);
    int result = ddc_write(service, (uint8_t)vcp, (uint16_t)value);

    if (result == 0) {
        printf("Success.\n");
    } else {
        fprintf(stderr, "Failed to write DDC command.\n");
    }

    CFRelease(service);
    return result;
}
