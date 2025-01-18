const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Edge = @This();

name: []const u8,
alloc: Allocator,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(alloc: Allocator, name: []const u8) Allocator.Error!Edge {
    const name_clone = try alloc.dupe(u8, name);
    errdefer alloc.free(name_clone);

    return .{ .alloc = alloc, .name = name_clone };
}

test "Edge.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;
    _ = eq;

    var edge = try init(alloc, "foo");
    defer edge.deinit();

    try eqStr("foo", edge.name);
}

pub fn toString(self: *Edge, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Edge.toString after it was deinitialized");
    }

    return alloc.dupe(u8, self.name);
}

test "Edge.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    var edge = try init(alloc, "foo");
    defer edge.deinit();

    const expected = "foo";
    const got = try edge.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

pub fn deinit(self: *Edge) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    self.alloc.free(self.name);
    self.freed = true;
}

test "Edge.deinit" {
    const alloc = std.testing.allocator;

    var edge = try init(alloc, "foo");

    const f = struct {
        pub fn f(u: *Edge) void {
            var xos = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                std.posix.getrandom(std.mem.asBytes(&seed)) catch @panic("failed to get random seed");
                break :blk seed;
            });
            const rng = xos.random();

            const ms = rng.uintLessThan(u64, 5000);

            std.time.sleep(std.time.ns_per_ms * ms);
            u.deinit();
        }
    };

    for (0..10) |_| {
        const t = try std.Thread.spawn(.{}, f.f, .{&edge});
        t.detach();
    }

    edge.deinit();
}

pub fn clone(self: *Edge, alloc: Allocator) Allocator.Error!*Edge {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Edge.clone after it was deinitialized");
    }

    const e = try alloc.create(Edge);
    errdefer alloc.destroy(e);

    const name = try alloc.dupe(u8, self.name);
    errdefer alloc.free(name);

    e.* = .{ .alloc = alloc, .name = name };

    return e;
}

test "Edge.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;
    _ = eq;

    var edge = try init(alloc, "foo");
    defer edge.deinit();

    var edge2 = try edge.clone(alloc);
    defer alloc.destroy(edge2);
    defer edge2.deinit();

    try strEq(edge.name, edge2.name);
}
