#include <stdlib.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 4) return 64;
    if (setenv("DYLD_INSERT_LIBRARIES", argv[2], 1) != 0) return 65;
    if (setenv("CLASSIC_MINES_NETWORK_PROBE_LOG", argv[3], 1) != 0) return 66;
    execl(argv[1], argv[1], NULL);
    return 67;
}
