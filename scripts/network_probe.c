#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

static void record_call(const char *name) {
    const char *path = getenv("CLASSIC_MINES_NETWORK_PROBE_LOG");
    if (!path) return;
    int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0600);
    if (fd < 0) return;
    write(fd, name, strlen(name));
    write(fd, "\n", 1);
    close(fd);
}

static int probe_socket(int domain, int type, int protocol) {
    (void)domain;
    (void)type;
    (void)protocol;
    record_call("socket");
    errno = EPERM;
    return -1;
}

static int probe_connect(int socket, const struct sockaddr *address, socklen_t length) {
    (void)socket;
    (void)address;
    (void)length;
    record_call("connect");
    errno = EPERM;
    return -1;
}

static int probe_getaddrinfo(
    const char *hostname,
    const char *service,
    const struct addrinfo *hints,
    struct addrinfo **result
) {
    (void)hostname;
    (void)service;
    (void)hints;
    (void)result;
    record_call("getaddrinfo");
    return EAI_FAIL;
}

static ssize_t probe_sendto(
    int socket,
    const void *buffer,
    size_t length,
    int flags,
    const struct sockaddr *destination,
    socklen_t addressLength
) {
    (void)socket;
    (void)buffer;
    (void)length;
    (void)flags;
    (void)destination;
    (void)addressLength;
    record_call("sendto");
    errno = EPERM;
    return -1;
}

#define INTERPOSE(replacement, replacee) \
    __attribute__((used)) static struct { const void *replacement; const void *replacee; } \
    interpose_##replacee __attribute__((section("__DATA,__interpose"))) = { \
        (const void *)(uintptr_t)&replacement, (const void *)(uintptr_t)&replacee \
    }

INTERPOSE(probe_socket, socket);
INTERPOSE(probe_connect, connect);
INTERPOSE(probe_getaddrinfo, getaddrinfo);
INTERPOSE(probe_sendto, sendto);
