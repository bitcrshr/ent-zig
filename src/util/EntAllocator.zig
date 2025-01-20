const std = @import("std");

pub const ErrorHandler = *const fn (std.mem.Allocator.Error) noreturn;

arena: std.heap.ArenaAllocator,
err_handler: ErrorHandler,

const Self = @This();

pub fn init(backing_alloc: std.mem.Allocator, opts: struct { err_handler: ?ErrorHandler = null }) *Self {
    const handler = opts.err_handler orelse (struct {
        fn handle(_: std.mem.Allocator.Error) noreturn {
            @panic("allocator reported OutOfMemory");
        }
    }).handle;

    var arena = std.heap.ArenaAllocator.init(backing_alloc);
    const self = arena.allocator().create(Self) catch @panic("ran out of memory while trying to create a *EntAllocator.");

    self.* = .{
        .arena = arena,
        .err_handler = handler,
    };

    return self;
}

pub fn allocator(self: *Self) std.mem.Allocator {
    const Impl = struct {
        pub fn rawAlloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
            const s: *Self = @ptrCast(@alignCast(ctx));
            const ret = s.arena.allocator().rawAlloc(len, ptr_align, ret_addr);
            if (ret) |r| return r;

            s.handleError(std.mem.Allocator.Error.OutOfMemory);
        }

        pub fn rawFree(ptr: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
            const s: *Self = @ptrCast(@alignCast(ptr));

            s.arena.allocator().rawFree(buf, buf_align, ret_addr);
        }

        pub fn rawResize(ptr: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
            const s: *Self = @ptrCast(@alignCast(ptr));

            return s.arena.allocator().rawResize(buf, buf_align, new_len, ret_addr);
        }
    };

    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = Impl.rawAlloc,
            .free = Impl.rawFree,
            .resize = Impl.rawResize,
        },
    };
}

pub fn deinit(self: *Self) void {
    self.arena.deinit();
}

pub fn create(self: *Self, comptime T: type) *T {
    return self.arena.allocator().create(T) catch |e| self.handleError(e);
}

pub fn destroy(self: *Self, ptr: anytype) void {
    self.arena.allocator().destroy(ptr);
}

pub fn alloc(self: *Self, comptime T: type, n: usize) []T {
    return self.arena.allocator().alloc(T, n) catch |e| self.handleError(e);
}

pub fn free(self: *Self, memory: anytype) void {
    self.arena.allocator().free(memory);
}

pub fn dupe(self: *Self, comptime T: type, m: []const T) []T {
    return self.arena.allocator().dupe(T, m) catch |e| self.handleError(e);
}

pub fn resize(self: *Self, old_mem: anytype, new_n: usize) bool {
    return self.arena.allocator().resize(old_mem, new_n);
}

pub fn handleError(self: Self, e: std.mem.Allocator.Error) noreturn {
    self.arena.deinit();

    self.err_handler(e);
}
