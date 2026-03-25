pub const c = @cImport({
    @cDefine("_GNU_SOURCE", {});
    @cInclude("liburing.h");
    @cInclude("sys/un.h"); //sockaddr_un
    @cInclude("netinet/in.h"); //sockaddr_in, sockaddr_in6, ...
    @cInclude("linux/futex.h");
});
