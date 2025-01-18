const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Binary = @This();

op: Op,
x: Expr,
y: Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(op: Op, x: Expr, y: Expr) Binary {
    return .{ .op = op, .x = x, .y = y };
}

test "Binary.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();

    var binary = init(.Not, x, y);
    defer binary.deinit();

    try eq(.Not, binary.op);
    try eqStr("foo", binary.x.expr.Field.name);
    try eqStr("bar", binary.y.expr.Edge.name);
}

pub fn toString(self: *Binary, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Binary.toString after it was deinitialized");
    }

    const op_str = self.op.toString();
    const x_str = try self.x.toString(alloc);
    defer alloc.free(x_str);
    const y_str = try self.y.toString(alloc);
    defer alloc.free(y_str);

    const buf = try alloc.alloc(u8, 2 + op_str.len + x_str.len + y_str.len);

    _ = std.fmt.bufPrint(buf, "{s} {s} {s}", .{ x_str, op_str, y_str }) catch unreachable;

    return buf;
}

test "Binary.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();

    var binary = init(.And, x, y);
    defer binary.deinit();

    const expected = "foo && bar";
    const got = try binary.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

pub fn deinit(self: *Binary) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    self.x.deinit();
    self.y.deinit();
    self.freed = true;
}

test "Binary.deinit" {
    const alloc = std.testing.allocator;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();

    var binary = init(.Not, x, y);

    const f = struct {
        pub fn f(u: *Binary) void {
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
        const t = try std.Thread.spawn(.{}, f.f, .{&binary});
        t.detach();
    }

    binary.deinit();
}

pub fn clone(self: *Binary, alloc: Allocator) Allocator.Error!*Binary {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Binary.clone after it was deinitialized");
    }

    const b = try alloc.create(Binary);
    errdefer alloc.destroy(b);

    const x = try self.x.clone(alloc);
    errdefer x.deinit();

    const y = try self.y.clone(alloc);
    errdefer y.deinit();

    b.* = .{ .op = self.op, .x = x, .y = y };

    return b;
}

test "Binary.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();

    var binary = init(.Not, x, y);
    defer binary.deinit();

    var binary2 = try binary.clone(alloc);
    defer alloc.destroy(binary2);
    defer binary2.deinit();

    try eq(binary.op, binary2.op);
    try eq(std.meta.activeTag(binary.x.expr), std.meta.activeTag(binary2.x.expr));
    try eq(std.meta.activeTag(binary.y.expr), std.meta.activeTag(binary2.y.expr));
    try strEq(binary.x.expr.Field.name, binary2.x.expr.Field.name);
    try strEq(binary.y.expr.Edge.name, binary2.y.expr.Edge.name);
}
