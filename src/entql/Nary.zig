//! A Nary represents an n-ary expression. All methods are thread-safe.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Nary = @This();

op: Op,
xs: []Expr,
alloc: Allocator,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(alloc: Allocator, op: Op, exprs: anytype) Allocator.Error!Nary {
    comptime {
        const T = @TypeOf(exprs);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected exprs to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected exprs to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != Expr) {
                @compileError("expected every element in exprs to be a Expr, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    const xs = try alloc.alloc(Expr, exprs.len);
    errdefer alloc.free(xs);

    inline for (exprs, 0..) |x, i| {
        xs[i] = x;
    }

    return .{ .op = op, .xs = xs, .alloc = alloc };
}

test "Nary.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var nary = try init(alloc, .Or, .{ x, y, z });
    defer nary.deinit();

    try eq(.Or, nary.op);
    try eq(3, nary.xs.len);
    try eqStr("foo", nary.xs[0].expr.Field.name);
    try eqStr("bar", nary.xs[1].expr.Edge.name);
    try eqStr("[3,6,9]", nary.xs[2].expr.Value.v);
}

/// `Nary.toString` gives the string representation of itself. Caller owns the
/// memory of the returned string. Will cause a panic if called after `Nary.deinit()`.
pub fn toString(self: *Nary, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Nary.toString after it was deinitialized");
    }

    const op_str = self.op.toString();

    var al = std.ArrayList(u8).init(alloc);
    errdefer al.deinit();

    try al.append('(');

    for (self.xs, 0..) |x, i| {
        if (i > 0) {
            try al.append(' ');
            try al.appendSlice(op_str);
            try al.append(' ');
        }

        const x_str = try x.toString(alloc);
        defer alloc.free(x_str);

        try al.appendSlice(x_str);
    }

    try al.append(')');

    return al.toOwnedSlice();
}

test "Nary.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var nary = try init(alloc, .And, .{ x, y, z });
    defer nary.deinit();

    const expected = "(foo && bar && [3,6,9])";
    const got = try nary.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

// `Nary.deinit` frees all the memory it owns (including any children's memory).
// It is safe to call in multiple threads and/or multiple times. Does not free the
// memory the `Nary` itself occupies.
pub fn deinit(self: *Nary) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    for (self.xs) |x| {
        x.deinit();
    }

    self.alloc.free(self.xs);
    self.freed = true;
}

test "Nary.deinit" {
    const alloc = std.testing.allocator;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var nary = try init(alloc, .And, .{ x, y, z });
    defer nary.deinit();

    const f = struct {
        pub fn f(u: *Nary) void {
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
        const t = try std.Thread.spawn(.{}, f.f, .{&nary});
        t.detach();
    }

    nary.deinit();
}

// `Nary.clone` creates a copy of iteself using `alloc`. Caller is responsible
// for freeing the memory of the clone.
pub fn clone(self: *Nary, alloc: Allocator) Allocator.Error!*Nary {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Nary.clone after it was deinitialized");
    }

    const n = try alloc.create(Nary);
    errdefer alloc.destroy(n);

    var x_clones = try alloc.alloc(Expr, self.xs.len);
    errdefer alloc.free(x_clones);

    for (self.xs, 0..) |x, i| {
        x_clones[i] = try x.clone(alloc);
        errdefer alloc.destroy(x_clones[i]);
    }

    n.* = .{
        .op = self.op,
        .xs = x_clones,
        .alloc = alloc,
    };

    return n;
}

test "Nary.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var nary = try init(alloc, .And, .{ x, y, z });
    defer nary.deinit();

    var nary2 = try nary.clone(alloc);
    defer alloc.destroy(nary2);
    defer nary2.deinit();

    try eq(nary.op, nary2.op);
    try eq(3, nary2.xs.len);
    try eq(std.meta.activeTag(nary.xs[0].expr), std.meta.activeTag(nary2.xs[0].expr));
    try eq(std.meta.activeTag(nary.xs[1].expr), std.meta.activeTag(nary2.xs[1].expr));
    try eq(std.meta.activeTag(nary.xs[2].expr), std.meta.activeTag(nary2.xs[2].expr));
    try strEq(nary.xs[0].expr.Field.name, nary2.xs[0].expr.Field.name);
    try strEq(nary.xs[1].expr.Edge.name, nary2.xs[1].expr.Edge.name);
    try strEq(nary.xs[2].expr.Value.v, nary2.xs[2].expr.Value.v);
}
