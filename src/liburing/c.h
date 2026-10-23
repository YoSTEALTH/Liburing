/* The C headers Liburing's Zig code uses, translated by `b.addTranslateC` in `build.zig`
 * (Zig 0.17 removed `@cImport`). Imported in Zig as `@import("c")`. */
#define _GNU_SOURCE
#include <liburing.h>
#include <sys/un.h>      /* sockaddr_un */
#include <netinet/in.h>  /* sockaddr_in, sockaddr_in6, ... */
#include <arpa/inet.h>   /* inet_ntop */
#include <linux/futex.h>
