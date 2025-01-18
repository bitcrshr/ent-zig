const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Field = @This();

name: []const u8,
alloc: Allocator,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(alloc: Allocator, name: []const u8) Allocator.Error!Field {
    const name_clone = try alloc.dupe(u8, name);
    errdefer alloc.free(name_clone);

    return .{ .alloc = alloc, .name = name_clone };
}

test "Field.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;
    _ = eq;

    var field = try init(alloc, "foo");
    defer field.deinit();

    try eqStr("foo", field.name);
}

pub fn toString(self: *Field, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Field.toString after it was deinitialized");
    }

    return alloc.dupe(u8, self.name);
}

test "Field.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    var field = try init(alloc, "foo");
    defer field.deinit();

    const expected = "foo";
    const got = try field.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

pub fn deinit(self: *Field) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    self.alloc.free(self.name);
    self.freed = true;
}

test "Field.deinit" {
    const alloc = std.testing.allocator;

    var field = try init(alloc, "foo");

    const f = struct {
        pub fn f(u: *Field) void {
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
        const t = try std.Thread.spawn(.{}, f.f, .{&field});
        t.detach();
    }

    field.deinit();
}

pub fn clone(self: *Field, alloc: Allocator) Allocator.Error!*Field {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Field.clone after it was deinitialized");
    }

    const f = try alloc.create(Field);
    errdefer alloc.destroy(f);

    const name = try alloc.dupe(u8, self.name);
    errdefer alloc.free(name);

    f.* = .{ .alloc = alloc, .name = name };

    return f;
}

test "Field.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;
    _ = eq;

    var field = try init(alloc, "foo");
    defer field.deinit();

    var field2 = try field.clone(alloc);
    defer alloc.destroy(field2);
    defer field2.deinit();

    try strEq(field.name, field2.name);
}
