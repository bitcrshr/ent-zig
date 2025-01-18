const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Unary = @This();

op: Op,
x: Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(op: Op, x: Expr) Unary {
    return .{ .op = op, .x = x };
}

test "Unary.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    var unary = init(.Not, try Expr.initField(alloc, "foo"));
    defer unary.deinit();

    try eq(.Not, unary.op);
    try eqStr("foo", unary.x.expr.Field.name);
}

pub fn toString(self: *Unary, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Unary.toString after it was deinitialized");
    }

    const op_str = self.op.toString();
    const x_str = try self.x.toString(alloc);
    defer alloc.free(x_str);

    const buf = try alloc.alloc(u8, 2 + op_str.len + x_str.len);
    errdefer buf.deinit();

    _ = std.fmt.bufPrint(buf, "{s}({s})", .{ op_str, x_str }) catch unreachable;

    return buf;
}

test "Unary.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    var unary = init(Op.Not, try Expr.initField(alloc, "foo"));
    defer unary.deinit();

    const expected = "!(foo)";
    const got = try unary.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

pub fn deinit(self: *Unary) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    self.x.deinit();
    self.freed = true;
}

test "Unary.deinit" {
    const alloc = std.testing.allocator;

    var unary = init(Op.Not, try Expr.initField(alloc, "foo"));

    const f = struct {
        pub fn f(u: *Unary) void {
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
        const t = try std.Thread.spawn(.{}, f.f, .{&unary});
        t.detach();
    }

    unary.deinit();
}

pub fn clone(self: *Unary, alloc: Allocator) Allocator.Error!*Unary {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Unary.clone after it was deinitialized");
    }

    const u = try alloc.create(Unary);
    errdefer alloc.destroy(u);

    const x = try self.x.clone(alloc);
    errdefer alloc.destroy(x);

    u.* = .{ .x = x, .op = self.op };

    return u;
}

test "Unary.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    var unary = init(Op.Not, try Expr.initField(alloc, "foo"));
    defer unary.deinit();

    var unary2 = try unary.clone(alloc);
    defer alloc.destroy(unary2);
    defer unary2.deinit();

    try eq(unary.op, unary2.op);
    try eq(std.meta.activeTag(unary.x.expr), std.meta.activeTag(unary2.x.expr));
    try strEq(unary.x.expr.Field.name, unary2.x.expr.Field.name);
}
