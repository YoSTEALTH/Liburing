//! Liburing - io_uring ring
const c = @import("c");
const e = @import("error.zig");
const setu = @import("setu");
const std = @import("std");
const writableView = @import("class.zig").writableView;
const keep = @import("class.zig").keep;
const threadId = @import("class.zig").threadId;
const BufRingType = @import("register.zig").BufRingType;
const SqeType = @import("sqe.zig").SqeType;

const py = setu.py;
const Object = setu.c.Object;
pub const RingType = setu.Class(Ring, @embedFile("ring.zig"));

/// I/O URing
///
/// Example
///     >>> ring = Ring()
///     >>> io_uring_queue_init(8, ring)
///     0
///     >>> io_uring_queue_exit(ring)
///
/// Note
///     - One ring per thread: a `Ring` belongs to the thread that initialized it (`io_uring_queue_init*`),
///     using it (or a `CQE` / `SQE` from it) from another thread raises `RuntimeError`. Threads talk to
///     each other's rings with `io_uring_prep_msg_ring`. A `Cqe` or `CqeBatch` belongs to the thread of its
///     first wait or peek, an `Sqe` template to the thread of its first prep or `put_sqe` (another thread:
///     `RuntimeError`): make one per thread.
///     - The waits (`io_uring_wait_cqe*`, `io_uring_submit_and_wait*`) let other threads run while the
///     kernel sleeps.
///     - `user_data` can be any 64-bit value, `0` and duplicates included: at the submit the ring keeps it in
///     a table of in-flight requests and gives the kernel the entry's index (an `SQE` read after the
///     submit shows that index). `cqe.user_data` gives your value back, until the completion is consumed
///     (`io_uring_cqe_seen`, `io_uring_cq_advance`). Cancels, timeout and poll removes / updates and
///     `io_uring_register_sync_cancel` take your value too: the first in-flight request with it, also with
///     `IORING_ASYNC_CANCEL_ALL` (each request has its own entry; to cancel a group use
///     `IORING_ASYNC_CANCEL_FD | IORING_ASYNC_CANCEL_ALL`, or one cancel per request).
///     - A message from `io_uring_prep_msg_ring*` reports the sender's `data` as `user_data`: it is sent
///     with bit 63 set (no request's entry has it), so `data` must be below `2**63`. A message from code that is
///     not Liburing (`data` without bit 63) would read as one of the ring's requests.
///     - `IOSQE_CQE_SKIP_SUCCESS` (no completion on success): fine in a link chain (`IOSQE_IO_LINK` /
///     `IOSQE_IO_HARDLINK`), whose end's completion releases what the skipped requests hold, but not on the
///     chain's last request (the last SQE of a submit ends a chain): `ValueError` at the submit, nothing sent.
///     Alone, a request with it may hold nothing (no buffer, path, ...: `ValueError`) and a failed one
///     reports `user_data` `0`.
pub const Ring = struct {
    _io_uring: c.io_uring = std.mem.zeroes(c.io_uring), // lives inside the Python object
    _thread: usize = 0, // `threadId()` of the thread that initialized it: the only one that may use it
    /// Set up (`io_uring_queue_init*` / `io_uring_queue_mmap` worked) until `io_uring_queue_exit`. `ring_fd` can
    /// not tell: `0` is a valid fd (stdin closed), `-1` a ring reachable only through its registered fd.
    _ready: bool = false,
    /// `Ring(auto_submit=True)`: a full submission queue is submitted to make room (`autoSubmit`).
    _auto_submit: bool = false,
    /// Bumped by every `io_uring_queue_init*` (`ownByCaller`): an entry (`SQE`, `CQE`, `Cqe`, ...) records it when
    /// made, so one from before an exit and a new init can not reach the old, unmapped memory (`checkGen`).
    _gen: u32 = 0,
    /// The `buf` of `io_uring_queue_init_mem`, locked until `io_uring_queue_exit`.
    _mem: ?py.WritableBuffer = null,
    /// In-flight requests: the kernel's `user_data` of a request is its index here (`submitPtr`), the entry
    /// holds the user's. Indexes below `reserved` are never handed out.
    _table: std.ArrayList(Entry) = .empty,
    /// What each entry's request holds (`Entry.held`), apart from the entries: a `Hold` is ~100 bytes (its
    /// `Py_buffer`) and most requests hold nothing, so the table stays small. As long as `_table`.
    _holds: std.ArrayList(Hold) = .empty,
    _free: u32 = 0, // first free index (a free entry's `user_data` is the next one), `0`: none
    _live: u32 = 0, // live entries: requests in flight
    /// What each SQ slot's prepared request holds until the submit moves it into its entry (`hold`):
    /// `sq.ring_entries` of them, allocated at the first prep that holds something.
    _pending: ?[*]Hold = null,
    _pending_len: u32 = 0,
    /// The buffers of `io_uring_register_buffers` / `_update_tag`: the kernel pins them until
    /// `io_uring_unregister_buffers` or the exit, so they stay locked until then (`releaseRegistered`).
    _registered: std.ArrayList(*Vec) = .empty,
    /// The `BufRing`s `io_uring_setup_buf_ring` made (owned): kept until `io_uring_free_buf_ring` /
    /// `_unregister_buf_ring` or the exit, with the buffers added to them.
    _buf_rings: std.ArrayList(*Object) = .empty,
    /// Areas given by `io_uring_prep_provide_buffers`: the kernel uses them until consumed or removed, which
    /// the ring can not tell, so they stay locked until the exit (one view per area: a part of one already
    /// held takes nothing more).
    _provided: std.ArrayList(setu.c.Buffer) = .empty,
    /// Memory registered by `io_uring_register_buf_ring` (`BufReg.ring`), `_region` and `_ifq`: the kernel uses
    /// it until `io_uring_unregister_buf_ring` (the `bgid`'s) or the exit, so it stays locked until then.
    _memory: std.ArrayList(Memory) = .empty,

    /// What a request's kernel `user_data` stands for, from the submit until its last completion is consumed.
    pub const Entry = struct {
        user_data: u64 = 0, // the user's value; while free: the next free index
        live: bool = false,
        /// Released but kept off the free list: absorbs a completion that may still come (`bury`).
        zombie: bool = false,
        /// Chains with an `IOSQE_CQE_SKIP_SUCCESS` request track their members, which may post no completion:
        /// a skipped one on success, and every one after a skipped `IOSQE_IO_LINK` one that failed (the
        /// kernel cancels them without completions). Not tracked: `end` 0.
        skips: bool = false, // has `IOSQE_CQE_SKIP_SUCCESS`
        breaks: bool = false, // ... and `IOSQE_IO_LINK` (not `HARDLINK`): its failure silences the rest
        end: u32 = 0, // a member: its chain's end
        prev: u32 = 0, // a member: the one before it in the chain (`0`: the first)
        next: u32 = 0, // a member: the one after it (`0`: the last before `end`); the end: its first member
        held: bool = false, // `_holds` at its index has what the kernel reads or writes until the completion
    };

    const link_flags = c.IOSQE_IO_LINK | c.IOSQE_IO_HARDLINK;

    /// A locked view of registered memory (`_memory`); `bgid` for a buffer ring's (released by its unregister).
    pub const Memory = struct {
        view: setu.c.Buffer,
        bgid: ?i32 = null,
    };

    /// What one request keeps alive (and locked) until its completion: a buffer the kernel reads or writes
    /// (its own view: the object can not resize or go away) and an object (a tuple of them for several:
    /// paths, `Sockaddr`, `Msghdr`, `Timespec`, the template `put_sqe` copied, ...).
    pub const Hold = struct {
        view: ?setu.c.Buffer = null,
        obj: ?*Object = null, // owned
        /// A `put_sqe` copy of an `Sqe` template's entry: the template (owned), counted in its `_inflight`
        /// until this is released, so a re-prep meanwhile retires what it held instead of releasing it.
        template: ?*Object = null,
        vec: ?*Vec = null, // a vectored request's buffers (`io_uring_prep_readv` / `writev`), owned

        /// GC: visits the objects it holds (`Ring.__traverse__`).
        pub fn traverse(self: *const Hold, v: *setu.Visit) setu.Visit.Error!void {
            if (self.view) |view| try v.add(view.obj);
            try v.add(self.obj);
            try v.add(self.template);
            if (self.vec) |vec| try vec.traverse(v);
        }

        /// Whether it holds nothing.
        pub fn isEmpty(self: *const Hold) bool {
            return self.view == null and self.obj == null and self.template == null and self.vec == null;
        }

        /// Drops what it holds (may run Python code: an object's last reference).
        pub inline fn release(self: *Hold) void {
            if (self.isEmpty()) return; // most requests hold nothing: no copy of the ~100 bytes
            var old = self.*;
            self.* = .{};
            old.consume();
        }

        /// `release` of a hold already taken out of its place (`takeHold`: a copy of its own): no second
        /// copy.
        pub inline fn consume(self: *Hold) void {
            if (self.isEmpty()) return;
            self.consumeHeld();
        }

        fn consumeHeld(self: *Hold) void {
            if (self.view) |*v| setu.c.PyBuffer_Release(v);
            py.decref(self.obj);
            if (self.vec) |v| v.destroy();
            if (self.template) |t| {
                SqeType.data(t).copyDone();
                py.decref(t);
            }
        }
    };

    /// Buffers for vectored I/O: the `struct iovec` array and a locked view of each buffer (it can not resize or
    /// go away), held until the kernel is done with them: a request's completion (`Hold.vec`), a registration
    /// (`Ring._registered`), a `Msghdr`'s lifetime.
    pub const Vec = struct {
        views: []setu.c.Buffer,
        iov: []c.iovec,
        readonly: bool = false, // a view is not writable (a `bytes`): the kernel may not write into it
        /// Owners: a registration shared by `io_uring_clone_buffers` is held by both rings (`share`). Atomic:
        /// a `Ring.__del__` (garbage collection) can drop its reference on any thread.
        refs: std.atomic.Value(u32) = .init(1),

        /// From a buffer sequence argument (`py.Sequence(py.Buffer)` / `(py.WritableBuffer)` items): each taken
        /// (a view of its own, past the call). 1 to `IOV_MAX` of them, else `ValueError` naming `what`.
        pub fn fromBuffers(items: anytype, comptime what: []const u8) py.Error!*Vec {
            const self = try alloc(items.len, what);
            var done: usize = 0;
            errdefer {
                for (self.views[0..done]) |*v| setu.c.PyBuffer_Release(v);
                self.free();
            }
            for (items, 0..) |item, i| {
                self.views[i] = (try item.take()).view;
                done += 1;
                // cast: a size
                self.iov[i] = .{ .iov_base = self.views[i].buf, .iov_len = @intCast(self.views[i].len) };
            }
            return self;
        }

        /// From any objects with the buffer protocol: writable views where they can be (`readonly` when one is
        /// not), for a `Msghdr` that sends or receives.
        pub fn fromObjects(items: []const *Object, comptime what: []const u8) py.Error!*Vec {
            const self = try alloc(items.len, what);
            var done: usize = 0;
            errdefer {
                for (self.views[0..done]) |*v| setu.c.PyBuffer_Release(v);
                self.free();
            }
            for (items, 0..) |o, i| {
                self.readonly = !try writableView(o, &self.views[i]) or self.readonly;
                done += 1;
                // cast: a size
                self.iov[i] = .{ .iov_base = self.views[i].buf, .iov_len = @intCast(self.views[i].len) };
            }
            return self;
        }

        fn alloc(n: usize, comptime what: []const u8) py.Error!*Vec {
            if (n == 0) return py.raiseValueError("`" ++ what ++ "` is empty", .{});
            if (n > std.posix.IOV_MAX)
                return py.raiseValueError(
                    "`" ++ what ++ "`: {d} buffers, more than `IOV_MAX` ({d})",
                    .{ n, std.posix.IOV_MAX },
                );
            const gpa = std.heap.c_allocator;
            const self = gpa.create(Vec) catch return e.raiseMemoryError("Out of Memory!");
            const views = gpa.alloc(setu.c.Buffer, n) catch {
                // coverage-off: out of memory only
                gpa.destroy(self);
                return e.raiseMemoryError("Out of Memory!");
                // coverage-on
            };
            const iov = gpa.alloc(c.iovec, n) catch {
                // coverage-off: out of memory only
                gpa.free(views);
                gpa.destroy(self);
                return e.raiseMemoryError("Out of Memory!");
                // coverage-on
            };
            self.* = .{ .views = views, .iov = iov };
            return self;
        }

        fn free(self: *Vec) void {
            const gpa = std.heap.c_allocator;
            gpa.free(self.views);
            gpa.free(self.iov);
            gpa.destroy(self);
        }

        /// GC: visits its buffers' objects, unless another owner shares it (`share`: they are not the caller's
        /// alone).
        pub fn traverse(self: *const Vec, v: *setu.Visit) setu.Visit.Error!void {
            if (self.refs.load(.monotonic) != 1) return;
            for (self.views) |view| try v.add(view.obj);
        }

        /// One more owner (`destroy` once each).
        pub fn share(self: *Vec) *Vec {
            _ = self.refs.fetchAdd(1, .monotonic);
            return self;
        }

        /// Drops an owner; the last one releases every view and frees it.
        pub fn destroy(self: *Vec) void {
            if (self.refs.fetchSub(1, .acq_rel) != 1) return;
            for (self.views) |*v| setu.c.PyBuffer_Release(v);
            self.free();
        }
    };

    /// Kernel `user_data` `0` (a request with `IOSQE_CQE_SKIP_SUCCESS`: no entry) and `1` (kept for Liburing's
    /// own use) are never an entry's index.
    const reserved = 2;
    /// Set in the kernel `user_data` of a message (`io_uring_prep_msg_ring*`: the sender's `data` | this), never
    /// in an entry's index (a `u32`): a completion with it is a message, not one of the ring's requests.
    pub const message_bit: u64 = 1 << 63;
    /// What a cancel (or another request naming one) gets when no in-flight request has its `user_data`:
    /// no entry has it, so the kernel answers `-ENOENT`.
    pub const no_match = std.math.maxInt(u64);

    /// Create an uninitialized `Ring`: `io_uring_queue_init*` sets it up.
    ///
    /// Type
    ///     auto_submit: bool | None
    pub fn __new__(self: *Ring, auto_submit: ?bool) void {
        self._auto_submit = auto_submit orelse false;
    }

    /// `True`: taking an entry from a full submission queue (a prep on `Sqe(ring)`, `io_uring_get_sqe`,
    /// `put_sqe`) first submits what is queued, as `io_uring_submit`, and takes the freed slot; except when the
    /// last queued request links to the next one (`IOSQE_IO_LINK` / `IOSQE_IO_HARDLINK`): a submit would end its
    /// chain there, so that call finds the queue full as with `False`. `False` (the default): the prep returns
    /// `False` (`io_uring_get_sqe`: `None`), you submit and try again.
    pub fn get_auto_submit(self: *const Ring) bool {
        return self._auto_submit;
    }

    /// Sets `auto_submit`.
    pub fn set_auto_submit(self: *Ring, value: bool) void {
        self._auto_submit = value;
    }

    /// A full submission queue with `auto_submit`: submits what is queued (as `io_uring_submit`:
    /// table entries, skip checks), so the caller can take the freed slots. `false` (nothing done) without the
    /// option, with nothing unsent, or when the last unsent request links to the next one. Out of line: only
    /// a full queue gets here.
    pub noinline fn autoSubmit(self: *Ring) py.Error!bool {
        if (!self._auto_submit) return false;
        var it = self.unsent(&self._io_uring);
        var last: ?*c.io_uring_sqe = null;
        while (it.next()) |u| last = u.sqe;
        const sqe = last orelse return false; // all sent: the kernel has not consumed them yet (`SQPOLL`)
        if (sqe.flags & link_flags != 0) return false; // mid chain
        _ = try py.checkErrno(c.io_uring_submit(try self.submitPtr()));
        return true;
    }

    /// GC: the objects the ring keeps alive (what requests hold, registered and provided buffers, `BufRing`s,
    /// registered memory), so a cycle through one (a buffer that refers back to its ring) can be collected. A
    /// `Vec` shared with another ring (`io_uring_clone_buffers`) is not visited: its references are not this
    /// ring's alone (reporting one twice would let the GC free what is still in use).
    pub fn __traverse__(self: *const Ring, v: *setu.Visit) setu.Visit.Error!void {
        if (self._mem) |m| try v.add(m.view.obj);
        for (self._holds.items) |*hold| try hold.traverse(v);
        if (self._pending) |pending| for (pending[0..self._pending_len]) |*hold| try hold.traverse(v);
        for (self._registered.items) |vec| try vec.traverse(v);
        for (self._buf_rings.items) |o| try v.add(o);
        for (self._provided.items) |*view| try v.add(view.obj);
        for (self._memory.items) |*m| try v.add(m.view.obj);
    }

    /// GC breaking a cycle (and dealloc, before `__del__`): never a hold whose request may still be in flight,
    /// so the ring exits first (`shutdown`: cancels and waits for its requests, leaks what does not complete).
    pub fn __clear__(self: *Ring) void {
        self.shutdown();
    }

    /// A `Ring` collected without `io_uring_queue_exit`: close it here, or its fd and mappings leak.
    pub fn __del__(self: *Ring) void {
        self.shutdown();
    }

    /// Exits the ring (if it is initialized) and releases everything it holds; again: nothing to do.
    fn shutdown(self: *Ring) void {
        if (self._ready) {
            self.drainRequests();
            c.io_uring_queue_exit(&self._io_uring);
            self._ready = false;
        }
        if (self._mem) |m| m.deinit();
        self._mem = null;
        self.clearTable();
        self.releaseKernelBuffers();
    }

    /// Before the ring exits: requests still in flight could write into memory their entries hold, so cancel
    /// them all (`IORING_ASYNC_CANCEL_ANY | ALL`, synchronous) and consume their completions. What does not
    /// complete (an error, or no completion within a second) is never released: leaked, not freed under the
    /// kernel. Requests prepared but not submitted release theirs.
    pub fn drainRequests(self: *Ring) void {
        if (self._pending) |pending| for (pending[0..self._pending_len]) |*hold| hold.release();
        if (self._live == 0 or !self._ready) return;
        const ring = &self._io_uring;
        var reg = std.mem.zeroes(c.io_uring_sync_cancel_reg);
        reg.flags = c.IORING_ASYNC_CANCEL_ANY | c.IORING_ASYNC_CANCEL_ALL;
        reg.fd = -1;
        reg.timeout = .{ .tv_sec = 1, .tv_nsec = 0 };
        _ = c.io_uring_register_sync_cancel(ring, &reg); // `-ENOENT` once only completed ones are left
        var ts: c.__kernel_timespec = .{ .tv_sec = 1, .tv_nsec = 0 };
        while (self._live != 0) {
            var cqe: ?*c.io_uring_cqe = null;
            if (c.io_uring_wait_cqe_timeout(ring, &cqe, &ts) != 0) break;
            self.releaseCqe(cqe.?);
            c.io_uring_cqe_seen(ring, cqe);
        }
        // coverage-off: a request that does not complete within a second of its cancel
        if (self._live != 0) for (self._holds.items) |*hold| {
            hold.* = .{}; // still in flight: leaked
        };
        // coverage-on
    }

    /// Releases the registered buffers (after `io_uring_unregister_buffers`, or the exit).
    pub fn releaseRegistered(self: *Ring) void {
        var list = self._registered;
        self._registered = .empty;
        for (list.items) |v| v.destroy();
        list.deinit(std.heap.c_allocator);
    }

    /// After the exit: drops the `BufRing`s and the provided areas (the kernel is done with all of them).
    pub fn releaseKernelBuffers(self: *Ring) void {
        self.releaseRegistered();
        var rings = self._buf_rings;
        self._buf_rings = .empty;
        for (rings.items) |o| py.decref(o);
        rings.deinit(std.heap.c_allocator);
        var provided = self._provided;
        self._provided = .empty;
        for (provided.items) |*v| setu.c.PyBuffer_Release(v);
        provided.deinit(std.heap.c_allocator);
        var memory = self._memory;
        self._memory = .empty;
        for (memory.items) |*m| setu.c.PyBuffer_Release(&m.view);
        memory.deinit(std.heap.c_allocator);
    }

    /// Room for `n` more `keepMemory`, before a register: after it, keeping can not fail.
    pub fn reserveMemory(self: *Ring, n: usize) py.Error!void {
        self._memory.ensureUnusedCapacity(std.heap.c_allocator, n) catch return e.raiseMemoryError("Out of Memory!");
    }

    /// Keeps `view` (owned from here; `null`: nothing) of memory the kernel registered until the unregister of
    /// `bgid` (a buffer ring's) or the exit. Needs `reserveMemory` first.
    pub fn keepMemory(self: *Ring, view: ?setu.c.Buffer, bgid: ?i32) void {
        if (view) |v| self._memory.appendAssumeCapacity(.{ .view = v, .bgid = bgid });
    }

    /// Keeps the `BufRing` `obj` (a new reference taken) until `dropBufRing` or the exit.
    pub fn keepBufRing(self: *Ring, obj: *Object) py.Error!void {
        self._buf_rings.append(std.heap.c_allocator, keep(obj)) catch {
            // coverage-off: out of memory only
            py.decref(obj);
            return e.raiseMemoryError("Out of Memory!");
            // coverage-on
        };
    }

    /// The kernel let go of the buffer ring of group `bgid`: drops its `BufRing` (and so its buffers' views,
    /// unless Python still holds it) or its `BufReg.ring` memory.
    pub fn dropBufRing(self: *Ring, bgid: i32) void {
        for (self._memory.items, 0..) |*m, i| if (m.bgid == bgid) {
            setu.c.PyBuffer_Release(&m.view);
            _ = self._memory.swapRemove(i);
            break;
        };
        for (self._buf_rings.items, 0..) |o, i| if (BufRingType.data(o)._bgid == bgid) {
            _ = self._buf_rings.swapRemove(i);
            py.decref(o);
            return;
        };
    }

    /// Keeps `view` (owned from here) of an area given to the kernel by `io_uring_prep_provide_buffers` until
    /// the exit; released at once if an area already held contains it.
    pub fn keepProvided(self: *Ring, view: setu.c.Buffer) py.Error!void {
        var v = view;
        const start = @intFromPtr(v.buf);
        const end = start + @as(usize, @intCast(v.len)); // cast: a size
        for (self._provided.items) |held| {
            const h_start = @intFromPtr(held.buf);
            if (start >= h_start and end <= h_start + @as(usize, @intCast(held.len))) { // cast: a size
                setu.c.PyBuffer_Release(&v);
                return;
            }
        }
        self._provided.append(std.heap.c_allocator, v) catch {
            // coverage-off: out of memory only
            setu.c.PyBuffer_Release(&v);
            return e.raiseMemoryError("Out of Memory!");
            // coverage-on
        };
    }

    /// Room for `src`'s registrations, before a clone: `shareRegistered` after it then can not fail.
    pub fn reserveShared(self: *Ring, src: *const Ring) py.Error!void {
        self._registered.ensureUnusedCapacity(std.heap.c_allocator, src._registered.items.len) catch
            // coverage-off: out of memory only
            return e.raiseMemoryError("Out of Memory!");
        // coverage-on
    }

    /// After `io_uring_clone_buffers` from `src`: the kernel uses `src`'s registered buffers for this ring too,
    /// until this ring's `io_uring_unregister_buffers` or exit, so it holds them as well (all of them, also
    /// for a partial clone, as `_update_tag` keeps replaced ones). Needs `reserveShared` first.
    pub fn shareRegistered(self: *Ring, src: *const Ring) void {
        const n = src._registered.items.len; // `src` may be `self`: only the ones it had
        for (0..n) |i| self._registered.appendAssumeCapacity(src._registered.items[i].share());
    }

    /// Keeps `vec` (registered with the kernel) until `releaseRegistered`; on `MemoryError` it is released.
    pub fn keepRegistered(self: *Ring, vec: *Vec) py.Error!void {
        self._registered.append(std.heap.c_allocator, vec) catch {
            // coverage-off: out of memory only
            vec.destroy();
            return e.raiseMemoryError("Out of Memory!");
            // coverage-on
        };
    }

    /// Forgets every entry (after `drain` and the exit: nothing is in flight) and every pending hold.
    pub fn clearTable(self: *Ring) void {
        for (self._holds.items) |*hold| hold.release();
        self._holds.deinit(std.heap.c_allocator);
        self._holds = .empty;
        self._table.deinit(std.heap.c_allocator);
        self._table = .empty;
        self._free = 0;
        self._live = 0;
        if (self._pending) |pending| {
            for (pending[0..self._pending_len]) |*hold| hold.release();
            std.heap.c_allocator.free(pending[0..self._pending_len]);
        }
        self._pending = null;
        self._pending_len = 0;
    }

    /// The pending hold of the SQ slot `sqe` points into (allocating them at the first use).
    pub inline fn pendingFor(self: *Ring, sqe: *const c.io_uring_sqe) py.Error!*Hold {
        try self.ensurePending();
        return self.pendingSlot(sqe);
    }

    /// Allocates the pending holds (`sq.ring_entries`), once.
    pub inline fn ensurePending(self: *Ring) py.Error!void {
        if (self._pending != null) return;
        return self.allocPending();
    }

    noinline fn allocPending(self: *Ring) py.Error!void {
        const n = self._io_uring.sq.ring_entries;
        const holds = std.heap.c_allocator.alloc(Hold, n) catch return e.raiseMemoryError("Out of Memory!");
        @memset(holds, .{});
        self._pending = holds.ptr;
        self._pending_len = n;
    }

    /// `pendingFor` after `ensurePending`.
    pub inline fn pendingSlot(self: *Ring, sqe: *const c.io_uring_sqe) *Hold {
        const ring = &self._io_uring;
        const base: [*]c.io_uring_sqe = ring.sq.sqes;
        const shift: u5 = @intCast(c.io_uring_sqe_shift(ring)); // cast: 0 or 1
        const slot = ((@intFromPtr(sqe) - @intFromPtr(base)) / @sizeOf(c.io_uring_sqe)) >> shift;
        return &self._pending.?[slot];
    }

    /// The `io_uring` for a submit: `checkedPtr`, then every SQE not handed to the kernel yet
    /// (`sqe_head .. sqe_tail`) gets an entry, its `user_data` moved there and replaced by the entry's index.
    /// Then requests that name another request by `user_data` (cancel, poll / timeout remove and update) get
    /// its index instead. All or nothing: a `MemoryError` changes no SQE.
    ///
    /// Note
    ///     - `IOSQE_CQE_SKIP_SUCCESS` (no completion on success): in a link chain (`IOSQE_IO_LINK` /
    ///       `IOSQE_IO_HARDLINK`) the request gets an entry that the chain's end releases (a request starts
    ///       only after the one before it finished, so the end's completion means it is done; if it fails,
    ///       its own completion releases it). Alone it gets no entry: kernel `user_data` `0`, and it may hold
    ///       nothing. `checkSkips` refuses the rest.
    ///     - What each slot's prep holds (`_pending`) moves into the request's entry.
    pub fn submitPtr(self: *Ring) py.Error!*c.io_uring {
        const ring = try self.checkedPtr();
        const sq = &ring.sq;
        if (sq.sqe_tail == sq.sqe_head) return ring;
        try self.checkSkips(ring);
        const gpa = std.heap.c_allocator;
        const first = self._table.items.len == 0;
        const need = (sq.sqe_tail -% sq.sqe_head) + @as(u32, if (first) reserved else 0);
        // the room is checked here: `ensureUnusedCapacity` is a call (~23 instructions) even when there is room
        if (self._table.capacity - self._table.items.len < need)
            self._table.ensureUnusedCapacity(gpa, need) catch return e.raiseMemoryError("Out of Memory!");
        if (self._holds.capacity - self._holds.items.len < need)
            self._holds.ensureUnusedCapacity(gpa, need) catch return e.raiseMemoryError("Out of Memory!");
        if (first) {
            self._table.appendNTimesAssumeCapacity(.{}, reserved);
            self._holds.appendNTimesAssumeCapacity(.{}, reserved);
        }
        var it = self.unsent(ring);
        var first_member: u32 = 0; // the chain so far (a list through `prev` / `next`)
        var last_member: u32 = 0;
        var any_skips = false;
        var in_chain = false; // the request before this one links to it
        while (it.next()) |u| {
            const flags = u.sqe.flags;
            const links = flags & link_flags != 0;
            const skips = flags & c.IOSQE_CQE_SKIP_SUCCESS != 0;
            defer in_chain = links;
            if (skips and !links and !in_chain) { // alone: no entry (`checkSkips`: it holds nothing)
                u.sqe.user_data = 0;
                continue;
            }
            const index: u32 = @intCast(self.take(u.sqe.user_data)); // cast: an index
            u.sqe.user_data = index;
            const items = self._table.items;
            if (self._pending) |pending| if (!pending[u.slot].isEmpty()) {
                self._holds.items[index] = pending[u.slot];
                pending[u.slot] = .{};
                items[index].held = true;
            };
            if (links and !it.atEnd()) { // a member (a submit ends a chain too)
                items[index].skips = skips;
                items[index].breaks = skips and flags & c.IOSQE_IO_HARDLINK == 0;
                items[index].prev = last_member;
                if (last_member != 0) items[last_member].next = index else first_member = index;
                last_member = index;
                any_skips = any_skips or skips;
            } else if (first_member != 0) { // the end of a chain
                var m = first_member;
                if (any_skips) {
                    items[index].next = first_member;
                    while (m != 0) : (m = items[m].next) items[m].end = index;
                } else while (m != 0) { // every member posts a completion: nothing to track
                    const after = items[m].next;
                    items[m].prev = 0;
                    items[m].next = 0;
                    items[m].skips = false;
                    items[m].breaks = false;
                    m = after;
                }
                first_member = 0;
                last_member = 0;
                any_skips = false;
            }
        }
        it = self.unsent(ring);
        while (it.next()) |u| self.translate(u.sqe);
        return ring;
    }

    /// `ValueError` (nothing changed, nothing submitted) for an `IOSQE_CQE_SKIP_SUCCESS` request that may post
    /// no completion at all where one is needed: a chain's last request (its completion releases the chain;
    /// the last SQE of a submit ends a chain), or one alone that holds something (nothing would release it).
    fn checkSkips(self: *Ring, ring: *c.io_uring) py.Error!void {
        var it = self.unsent(ring);
        var in_chain = false;
        while (it.next()) |u| {
            const links = u.sqe.flags & link_flags != 0;
            defer in_chain = links;
            if (u.sqe.flags & c.IOSQE_CQE_SKIP_SUCCESS == 0) continue;
            if ((in_chain and !links) or (links and it.atEnd())) return raiseSkipLast(u);
            if (!in_chain and !links) if (self._pending) |pending| {
                if (!pending[u.slot].isEmpty()) return raiseSkipHolds(u);
            };
        }
    }

    noinline fn raiseSkipHolds(u: Unsent.Item) py.Error {
        return py.raiseValueError(
            "`IOSQE_CQE_SKIP_SUCCESS` on a request that holds a buffer or object (user_data {d}): it may post no " ++
                "completion to release them; drop the flag, or link it (`IOSQE_IO_LINK`) to a request that completes",
            .{u.sqe.user_data},
        );
    }

    noinline fn raiseSkipLast(u: Unsent.Item) py.Error {
        return py.raiseValueError(
            "`IOSQE_CQE_SKIP_SUCCESS` on the last request of a link chain (user_data {d}; the last SQE of a submit " ++
                "ends a chain): its completion is what tells the chain is done; drop the flag on it",
            .{u.sqe.user_data},
        );
    }

    /// The SQEs from `sqe_head` to `sqe_tail`: one slot each, two for a 128-byte one in a
    /// `IORING_SETUP_SQE_MIXED` ring (its second half is not an SQE).
    const Unsent = struct {
        sq: *c.io_uring_sq,
        head: u32,
        shift: u5,
        mixed: bool,

        /// An SQE and its slot (the index of `_pending`).
        const Item = struct { sqe: *c.io_uring_sqe, slot: u32 };

        fn next(self: *Unsent) ?Item {
            if (self.head == self.sq.sqe_tail) return null;
            const sqes: [*]c.io_uring_sqe = self.sq.sqes;
            const slot = self.head & self.sq.ring_mask;
            const sqe = &sqes[slot << self.shift];
            const big = self.mixed and (sqe.opcode == c.IORING_OP_NOP128 or sqe.opcode == c.IORING_OP_URING_CMD128);
            self.head +%= if (big) 2 else 1;
            return .{ .sqe = sqe, .slot = slot };
        }

        /// Whether the SQE `next` just gave is the last one.
        fn atEnd(self: *const Unsent) bool {
            return self.head == self.sq.sqe_tail;
        }
    };

    fn unsent(_: *Ring, ring: *c.io_uring) Unsent {
        return .{
            .sq = &ring.sq,
            .head = ring.sq.sqe_head,
            .shift = @intCast(c.io_uring_sqe_shift(ring)), // cast: 0 or 1
            .mixed = ring.flags & c.IORING_SETUP_SQE_MIXED != 0,
        };
    }

    /// A new entry holding `user_data`, its index (capacity reserved by `submitPtr`).
    inline fn take(self: *Ring, user_data: u64) u64 {
        const items = self._table.items;
        self._live += 1;
        if (self._free != 0) {
            const index = self._free;
            self._free = @intCast(items[index].user_data); // cast: a free entry holds an index
            items[index] = .{ .user_data = user_data, .live = true };
            return index;
        }
        self._table.appendAssumeCapacity(.{ .user_data = user_data, .live = true });
        self._holds.appendAssumeCapacity(.{});
        return self._table.items.len - 1;
    }

    /// The live entry the kernel `user_data` `index` names, if any.
    inline fn live(self: *const Ring, index: u64) ?*Entry {
        if (index < reserved or index >= self._table.items.len) return null;
        const entry = &self._table.items[@intCast(index)]; // cast: checked
        return if (entry.live) entry else null;
    }

    /// The user's `user_data` for a completion's kernel `user_data`: an entry's, or a message's `data`
    /// (`message_bit` dropped). One that is neither (`0`: a request with `IOSQE_CQE_SKIP_SUCCESS` that is alone)
    /// as it is.
    pub inline fn userData(self: *const Ring, kernel: u64) u64 {
        if (self.live(kernel)) |entry| return entry.user_data;
        return kernel & ~message_bit;
    }

    /// The kernel `user_data` (an entry's index) of the first in-flight request with the user's `user_data`,
    /// other than `except`; `no_match` if none.
    pub fn findUserData(self: *const Ring, user_data: u64, except: u64) u64 {
        for (self._table.items[@min(reserved, self._table.items.len)..], reserved..) |entry, index| {
            if (entry.live and entry.user_data == user_data and index != except) return index;
        }
        return no_match;
    }

    /// Whether a cancel with `flags` matches on `user_data` (`addr`): the default, unless it keys on the
    /// file, any request or the opcode without `IORING_ASYNC_CANCEL_USERDATA`.
    pub fn cancelsByUserData(flags: u32) bool {
        const other = c.IORING_ASYNC_CANCEL_FD | c.IORING_ASYNC_CANCEL_ANY | c.IORING_ASYNC_CANCEL_OP;
        return flags & other == 0 or flags & c.IORING_ASYNC_CANCEL_USERDATA != 0;
    }

    /// `sqe` (just given its entry) names another request by the user's `user_data`: give it that request's.
    fn translate(self: *Ring, sqe: *c.io_uring_sqe) void {
        const addr = &sqe.unnamed_1.addr;
        switch (sqe.opcode) {
            c.IORING_OP_ASYNC_CANCEL => if (cancelsByUserData(sqe.unnamed_2.cancel_flags)) {
                addr.* = self.findUserData(addr.*, sqe.user_data);
            },
            c.IORING_OP_TIMEOUT_REMOVE => addr.* = self.findUserData(addr.*, sqe.user_data), // remove and update
            c.IORING_OP_POLL_REMOVE => { // remove, and update (`len`: `IORING_POLL_UPDATE_*`)
                addr.* = self.findUserData(addr.*, sqe.user_data);
                if (sqe.len & c.IORING_POLL_UPDATE_USER_DATA != 0) {
                    const off = &sqe.unnamed_0.off; // the poll's new `user_data`: kept in its entry
                    if (self.live(addr.*)) |entry| entry.user_data = off.*;
                    off.* = addr.*;
                }
            },
            else => {},
        }
    }

    /// A completion is consumed: its entry is freed with what it holds, unless more completions follow
    /// (`IORING_CQE_F_MORE`), or the completion is a skip marker (`IORING_CQE_F_SKIP`).
    ///
    /// Note
    ///     - A tracked chain (`Entry.end`): a member's completion takes it out of the list; the end's frees what
    ///       is left (skipped members that succeeded: no completion). A skipped `IOSQE_IO_LINK` member that posts
    ///       failed, and the kernel cancels the rest without completions: the whole chain is released (none of
    ///       the rest ever ran). If its result is `-ECANCELED` the rest may still post (an earlier member
    ///       failed): they are buried instead of freed.
    pub inline fn releaseCqe(self: *Ring, cqe: *const c.io_uring_cqe) void {
        if (cqe.flags & (c.IORING_CQE_F_MORE | c.IORING_CQE_F_SKIP) != 0) return;
        const kernel = cqe.user_data;
        if (kernel < reserved or kernel >= self._table.items.len) return;
        const index: u32 = @intCast(kernel); // cast: checked
        const entry = &self._table.items[index];
        if (entry.live and entry.end == 0 and entry.next == 0) { // a request on its own: the usual case
            var hold = self.freeEntry(index);
            hold.consume(); // after the table is updated: may run Python code (which may use the ring)
            return;
        }
        self.releaseCqeTracked(cqe, index);
    }

    /// `releaseCqe` past the usual case: a zombie, a chain member or a chain's end.
    noinline fn releaseCqeTracked(self: *Ring, cqe: *const c.io_uring_cqe, index: u32) void {
        const entry = &self._table.items[index];
        if (!entry.live) {
            if (entry.zombie) self.freeZombie(index);
            return;
        }
        if (entry.end != 0) {
            const end = entry.end;
            if (entry.breaks) return self.releaseChain(end, index, cqe.res == -c.ECANCELED);
            self.unlinkMember(index, end);
            var hold = self.freeEntry(index);
            hold.consume(); // after the table is updated: may run Python code (which may use the ring)
            return;
        }
        const members = entry.next; // the end of a tracked chain: its members still listed
        var hold = self.freeEntry(index);
        hold.consume();
        var m = members;
        while (m != 0) {
            const member = self.live(m) orelse break;
            if (member.end != index) break; // released meanwhile (by Python code a release ran)
            const after = member.next;
            // skipped and succeeded: done; any other still listed posts later (consumed out of order)
            hold = if (member.skips) self.freeEntry(m) else self.bury(m);
            hold.consume();
            m = after;
        }
    }

    /// A tracked chain whose skipped `IOSQE_IO_LINK` member `failed` posted: releases every member and `end`.
    /// Those before `failed` completed; those after it (and `end`) were cancelled, so never ran: freed, or
    /// buried when they may still post (`uncertain`). A non-skipped one before `failed` that is still listed
    /// has a completion not consumed yet: buried.
    fn releaseChain(self: *Ring, end: u32, failed: u32, uncertain: bool) void {
        const items = self._table.items;
        var m = items[end].next;
        var after_failed = false;
        while (m != 0) {
            const member = self.live(m) orelse break;
            if (member.end != end) break;
            const next = member.next;
            const free = m == failed or (if (after_failed) !uncertain else member.skips);
            if (m == failed) after_failed = true;
            var hold = if (free) self.freeEntry(m) else self.bury(m);
            hold.consume();
            m = next;
        }
        if (self.live(end) != null) {
            var hold = if (uncertain) self.bury(end) else self.freeEntry(end);
            hold.consume();
        }
    }

    /// Frees the live entry `index`, giving what it held (to release).
    inline fn freeEntry(self: *Ring, index: u32) Hold {
        const entry = &self._table.items[index];
        const hold = self.takeHold(index);
        entry.* = .{ .user_data = self._free };
        self._free = index;
        self._live -= 1;
        return hold;
    }

    /// Like `freeEntry`, but the index stays off the free list until a completion for it comes (`freeZombie`):
    /// one that may still post can not name a new request. One that never posts costs an entry (no hold).
    fn bury(self: *Ring, index: u32) Hold {
        const entry = &self._table.items[index];
        const hold = self.takeHold(index);
        entry.* = .{ .zombie = true };
        self._live -= 1;
        return hold;
    }

    /// What the entry `index` held (empty if nothing), taken out of `_holds`.
    inline fn takeHold(self: *Ring, index: u32) Hold {
        if (!self._table.items[index].held) return .{};
        const hold = self._holds.items[index];
        self._holds.items[index] = .{};
        return hold;
    }

    fn freeZombie(self: *Ring, index: u32) void {
        self._table.items[index] = .{ .user_data = self._free };
        self._free = index;
    }

    /// Takes the member `index` out of its chain's list (`end`'s).
    fn unlinkMember(self: *Ring, index: u32, end: u32) void {
        const items = self._table.items;
        const prev = items[index].prev;
        const next = items[index].next;
        if (prev != 0) items[prev].next = next else if (self.live(end)) |owner| owner.next = next;
        if (next != 0) items[next].prev = prev;
    }

    /// `io_uring_cq_advance(ring, nr)`: releases the `nr` completion slots from the head (at most the
    /// ready ones), two for a 32-byte completion in a `IORING_SETUP_CQE_MIXED` ring.
    pub fn releaseCompleted(self: *Ring, ring: *c.io_uring, nr: u32) void {
        if (self._table.items.len == 0) return;
        const cq = &ring.cq;
        const n = @min(nr, c.io_uring_cq_ready(ring));
        const head = cq.khead.*;
        const shift: u5 = @intCast(c.io_uring_cqe_shift(ring)); // cast: 0 or 1
        const mixed = ring.flags & c.IORING_SETUP_CQE_MIXED != 0;
        const cqes: [*]c.io_uring_cqe = cq.cqes;
        var i: u32 = 0;
        while (i < n) {
            const cqe = &cqes[((head +% i) & cq.ring_mask) << shift];
            self.releaseCqe(cqe);
            i += if (mixed and cqe.flags & c.IORING_CQE_F_32 != 0) 2 else 1;
        }
    }

    /// The `io_uring` for C, or `RuntimeError` if the ring is not initialised (or already exited):
    /// liburing would read unmapped memory.
    pub inline fn checkedPtr(self: *Ring) py.Error!*c.io_uring {
        return checkRing(&self._io_uring);
    }

    /// `ring` (inside a `Ring`), or `RuntimeError` as `checkedPtr` does: for entries, which keep
    /// the pointer next to their owner to skip the `Ring` lookup.
    pub inline fn checkRing(ring: *c.io_uring) py.Error!*c.io_uring {
        const self: *Ring = @fieldParentPtr("_io_uring", ring);
        if (!self._ready) return raiseNotInitialized();
        if (self._thread != threadId()) return raiseOtherThread();
        return ring;
    }

    /// `checkRing`, then `RuntimeError` if `gen` (an entry's, recorded when it was made) is not the ring's: the
    /// ring exited and was initialized again since, so the entry points into the old, unmapped memory.
    pub inline fn checkGen(ring: *c.io_uring, gen: u32) py.Error!*c.io_uring {
        _ = try checkRing(ring);
        if (ringOf(ring)._gen != gen) return raiseStale();
        return ring;
    }

    noinline fn raiseStale() py.Error {
        return py.raiseRuntimeError(
            "entry from before its `Ring` was initialized again (`io_uring_queue_exit` + `io_uring_queue_init`): " ++
                "its memory is gone, get a new one",
            .{},
        );
    }

    /// Marks the calling thread as the owner and starts a new generation (`checkGen`), before an
    /// `io_uring_queue_init*`.
    pub fn ownByCaller(self: *Ring) void {
        self._thread = threadId();
        self._gen +%= 1;
    }

    /// `RuntimeError` if the calling thread is not the owner (`ring` initialized).
    pub fn checkThread(self: *const Ring) py.Error!void {
        if (self._thread != threadId()) return raiseOtherThread();
    }

    noinline fn raiseOtherThread() py.Error {
        return py.raiseRuntimeError(
            "`Ring` belongs to the thread that initialized it (`io_uring_queue_init`): use one ring per thread",
            .{},
        );
    }

    /// Out of line: keeps its message formatting off the hot paths that inline `checkRing`.
    noinline fn raiseNotInitialized() py.Error {
        return py.raiseRuntimeError(
            "`Ring` is not initialized (`io_uring_queue_init`) or already exited (`io_uring_queue_exit`)",
            .{},
        );
    }

    /// `IORING_SETUP_*` flags the ring was set up with.
    pub fn get_flags(self: *const Ring) u32 {
        return self._io_uring.flags;
    }

    /// The ring's file descriptor; `-1` when it has none: not set up (before `io_uring_queue_init*`, after a
    /// failed one, after `io_uring_queue_exit`) or after `io_uring_close_ring_fd`, which leaves only the
    /// registered one (`enter_ring_fd`).
    pub fn get_ring_fd(self: *const Ring) i32 {
        return if (self._ready) self._io_uring.ring_fd else -1;
    }

    /// `IORING_FEAT_*` flags the kernel reported at setup: what this kernel can do (the version each came in).
    ///
    /// Flags
    ///     IORING_FEAT_SINGLE_MMAP      # 5.4: the SQ and CQ rings share one mapping.
    ///     IORING_FEAT_NODROP           # 5.5: a full CQ overflows into the kernel instead of dropping completions.
    ///     IORING_FEAT_SUBMIT_STABLE    # 5.5: what a request points at may change once the SQE was submitted.
    ///     IORING_FEAT_RW_CUR_POS       # 5.6: offset -1 on reads and writes uses (and moves) the file position.
    ///     IORING_FEAT_CUR_PERSONALITY  # 5.6: requests run with the credentials of the submitting thread.
    ///     IORING_FEAT_FAST_POLL        # 5.7: a request waiting for data or space polls, no worker thread blocks.
    ///     IORING_FEAT_POLL_32BITS      # 5.9: io_uring_prep_poll_add takes the full epoll mask (EPOLLEXCLUSIVE).
    ///     IORING_FEAT_SQPOLL_NONFIXED  # 5.11: IORING_SETUP_SQPOLL works with unregistered files.
    ///     IORING_FEAT_EXT_ARG          # 5.11: io_uring_enter takes a timeout with the signal mask.
    ///     IORING_FEAT_NATIVE_WORKERS   # 5.12: the async workers are threads of the process.
    ///     IORING_FEAT_RSRC_TAGS        # 5.13: registered files and buffers update in place, with tags.
    ///     IORING_FEAT_CQE_SKIP         # 5.17: IOSQE_CQE_SKIP_SUCCESS.
    ///     IORING_FEAT_LINKED_FILE      # 5.17: a linked request picks its file when it starts (direct descriptors).
    ///     IORING_FEAT_REG_REG_RING     # 6.3: io_uring_register through a registered ring fd.
    ///     IORING_FEAT_RECVSEND_BUNDLE  # 6.10: IORING_RECVSEND_BUNDLE, provided buffers for sends.
    ///     IORING_FEAT_MIN_TIMEOUT      # 6.12: the *_min_timeout waits.
    ///     IORING_FEAT_RW_ATTR          # Read / write attributes in the SQE (IORING_RW_ATTR_FLAG_PI); no prep yet.
    ///     IORING_FEAT_NO_IOWAIT        # 6.15: io_uring_set_iowait.
    ///
    /// Note
    ///     - A call that needs a feature the ring lacks raises `UnsupportedError`.
    pub fn get_features(self: *const Ring) u32 {
        return self._io_uring.features;
    }

    /// liburing's internal flags (`IORING_INT_FLAG_*`).
    pub fn get_int_flags(self: *const Ring) u8 {
        return self._io_uring.int_flags;
    }

    /// The file descriptor used for `io_uring_enter` (differs from `ring_fd` with a registered ring fd); `-1` when
    /// the ring is not set up.
    pub fn get_enter_ring_fd(self: *const Ring) i32 {
        return if (self._ready) self._io_uring.enter_ring_fd else -1;
    }
};

/// The `Ring` an `io_uring` lives in.
pub inline fn ringOf(ring: *c.io_uring) *Ring {
    return @fieldParentPtr("_io_uring", ring);
}
