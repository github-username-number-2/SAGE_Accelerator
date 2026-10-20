#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include "../kernel-module/picoevb-rdma-ioctl.h"

int main(int argc, char **argv)
{
        int fd, ret;
        struct picoevb_rdma_adder adder;

        if (argc != 3) {
                fprintf(stderr, "usage: %s A B\n", argv[0]);
                return 1;
        }

        adder.a = strtoul(argv[1], NULL, 0);
        adder.b = strtoul(argv[2], NULL, 0);
        adder.result = 0;

        fd = open("/dev/picoevb", O_RDWR);
        if (fd < 0) {
                perror("open");
                return 1;
        }

        ret = ioctl(fd, PICOEVB_IOC_ADDER, &adder);
        if (ret != 0) {
                perror("ioctl PICOEVB_IOC_ADDER");
                close(fd);
                return 1;
        }

        printf("%u + %u = %u\n", adder.a, adder.b, adder.result);
        printf("0x%08x + 0x%08x = 0x%08x\n",
               adder.a, adder.b, adder.result);

        close(fd);
        return 0;
}
