"""Build the API reference pages (`api/*.md`) from `src/liburing/liburing.pyi` (mkdocs-gen-files).

Every public name of the stub goes to exactly one page, picked by `page_of()`; constants are listed by prefix.
"""

import ast
import re
from pathlib import Path
import mkdocs_gen_files

STUB = Path("src/liburing/liburing.pyi")

PAGES = {  # slug: (title, description)
    "ring": ("Ring and setup", "Create, configure and tear down a `Ring`; probe what the kernel supports."),
    "submission": ("Submission queue", "Get a submission entry (`SQE` / `Sqe`), set its fields and submit it."),
    "completion": ("Completion queue", "Wait for, peek at and consume completion entries (`CQE` / `Cqe`)."),
    "prep-file": ("Prep: files", "Read, write, open, close, stat, rename and the other file-system operations."),
    "prep-net": ("Prep: sockets", "Accept, connect, send, receive, bind, listen and the other socket operations."),
    "prep-other": ("Prep: other", "Poll, timeout, cancel, futex, `msg_ring`, `nop`, `uring_cmd`, epoll, ..."),
    "register": ("Register and buffers", "Register files, buffers, rings and restrictions; provided buffer rings."),
    "network": ("Network helpers", "Socket addresses, message headers and socket options."),
    "types": ("Types, enums and errors", "Structures, enums and exceptions the functions take and return."),
    "constants": ("Constants", "`IORING_*`, `IOSQE_*`, `O_*`, `SO_*`, ... grouped by prefix."),
}

PREP_FILE = {
    "splice",
    "tee",
    "readv",
    "read_fixed",
    "readv_fixed",
    "writev",
    "write_fixed",
    "writev_fixed",
    "fsync",
    "files_update",
    "fallocate",
    "open",
    "open_direct",
    "close",
    "close_direct",
    "read",
    "read_multishot",
    "write",
    "statx",
    "fadvise",
    "madvise",
    "fadvise64",
    "madvise64",
    "openat2",
    "openat2_direct",
    "unlink",
    "rename",
    "sync_file_range",
    "mkdir",
    "symlink",
    "link",
    "getxattr",
    "setxattr",
    "fgetxattr",
    "fsetxattr",
    "fixed_fd_install",
    "ftruncate",
    "pipe",
    "pipe_direct",
    "cmd_discard",
}
PREP_NET = {
    "recvmsg",
    "recvmsg_multishot",
    "sendmsg",
    "accept",
    "accept_direct",
    "multishot_accept",
    "multishot_accept_direct",
    "connect",
    "bind",
    "listen",
    "send",
    "send_bundle",
    "send_set_addr",
    "sendto",
    "send_zc",
    "send_zc_fixed",
    "sendmsg_zc",
    "sendmsg_zc_fixed",
    "recv",
    "recv_multishot",
    "shutdown",
    "socket",
    "socket_direct",
    "cmd_sock",
    "cmd_getsockname",
}

RING_FUNCS = re.compile(
    r"^(io_uring_(queue_|setup|enter|ring_dontfork|resize_rings|enable_rings|close_ring_fd|set_iowait|memory_|mlock_"
    r"|clone_|get_probe|free_probe|opcode_supported|register$)|liburing_version_|probe$)"
)
SUBMIT_FUNCS = re.compile(r"^(io_uring_(get_sqe|sqe_|submit|sq_|sqring_|get_events)|put_sqe$)")
CQ_FUNCS = re.compile(r"^io_uring_(cqe_|cq_|wait_|peek_)")
REGISTER_FUNCS = re.compile(r"^io_uring_(register|unregister|buf_|setup_buf_ring|free_buf_ring)")
NETWORK_FUNCS = re.compile(r"^(io_uring_recvmsg_|setsockopt$|getsockopt$|getsockname$)")

RING_CLASSES = {"Ring", "Param", "Probe"}
SUBMIT_CLASSES = {"SQE", "Sqe"}
CQ_CLASSES = {"CQE", "Cqe", "CqeBatch", "CqeBatchIter", "CqeIter"}
REGISTER_CLASSES = {
    "RegWait", "Restriction", "BufReg", "SyncCancelReg", "Napi", "Query", "ZcrxCtrl", "ZcrxIfqReg", "ClockRegister",
    "Bpf", "MemRegionReg", "BufRing", "FileIndex", "FileIndexIter",
}  # fmt: skip
NETWORK_CLASSES = {"Sockaddr", "Msghdr", "Cmsghdr", "RecvmsgOut"}


def page_of(kind: str, name: str) -> str:
    if kind == "class":
        for page, names in (
            ("ring", RING_CLASSES),
            ("submission", SUBMIT_CLASSES),
            ("completion", CQ_CLASSES),
            ("register", REGISTER_CLASSES),
            ("network", NETWORK_CLASSES),
        ):
            if name in names:
                return page
        return "types"
    if name.startswith("io_uring_prep_"):
        op = name.removeprefix("io_uring_prep_")
        if op in PREP_FILE:
            return "prep-file"
        return "prep-net" if op in PREP_NET else "prep-other"
    for page, rx in (
        ("register", REGISTER_FUNCS),
        ("completion", CQ_FUNCS),
        ("submission", SUBMIT_FUNCS),
        ("network", NETWORK_FUNCS),
        ("ring", RING_FUNCS),
    ):
        if rx.search(name):
            return page
    return "types"  # trap_error, timespec, ...


def main() -> None:
    members: dict[str, list[str]] = {slug: [] for slug in PAGES}
    constants: dict[str, list[str]] = {}
    for node in ast.parse(STUB.read_text()).body:
        if isinstance(node, ast.ClassDef | ast.FunctionDef):
            kind = "class" if isinstance(node, ast.ClassDef) else "def"
            members[page_of(kind, node.name)].append(node.name)
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            name = node.target.id
            if name != "__version__":
                constants.setdefault(name.split("_")[0], []).append(name)

    index = ["# API reference", "", "Generated from the type stubs (`liburing.pyi`), which Setu builds from the",
            "`///` docs in the Zig source.", "", "| Page | Contents | Entries |", "| --- | --- | --- |"]  # fmt: skip
    for slug, (title, text) in PAGES.items():
        count = sum(map(len, constants.values())) if slug == "constants" else len(members[slug])
        index.append(f"| [{title}]({slug}.md) | {text} | {count} |")
    with mkdocs_gen_files.open("api/index.md", "w") as out:
        out.write("\n".join(index) + "\n")

    for slug, (title, text) in PAGES.items():
        lines = [f"# {title}", "", text, ""]
        if slug == "constants":
            for prefix in sorted(constants):
                names = constants[prefix]
                lines += [f"## {prefix}_*" if len(names) > 1 else f"## {names[0]}", ""]
                lines += [" ".join(f"`{n}`" for n in names), ""]
        else:
            lines += [f"::: liburing.liburing.{name}\n" for name in members[slug]]
        with mkdocs_gen_files.open(f"api/{slug}.md", "w") as out:
            out.write("\n".join(lines))


main()
