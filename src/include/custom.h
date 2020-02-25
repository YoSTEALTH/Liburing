/*
 * Note: These structs are needed or else error is raised while building.
 */
struct __kernel_timespec {
    int64_t     tv_sec;
    long long   tv_nsec;
};

struct open_how {
    uint64_t    flags;
    uint64_t    mode;
    uint64_t    resolve;
};
