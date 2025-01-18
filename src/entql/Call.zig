const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");
const P = @import("./P.zig");

const Call = @This();

func: Func,
args: []Expr,
alloc: Allocator,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(alloc: Allocator, func: Func, exprs: anytype) Allocator.Error!Call {
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

    const args = try alloc.alloc(Expr, exprs.len);
    errdefer alloc.free(args);

    inline for (exprs, 0..) |x, i| {
        args[i] = x;
    }

    return .{ .func = func, .args = args, .alloc = alloc };
}

test "Call.init" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var call = try init(alloc, .EqualFold, .{ x, y, z });
    defer call.deinit();

    try eq(.EqualFold, call.func);
    try eq(3, call.args.len);
    try eqStr("foo", call.args[0].expr.Field.name);
    try eqStr("bar", call.args[1].expr.Edge.name);
    try eqStr("[3,6,9]", call.args[2].expr.Value.v);
}

pub fn toString(self: *Call, alloc: Allocator) Allocator.Error![]u8 {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Call.toString after it was deinitialized");
    }

    const func_str = self.func.toString();

    var al = std.ArrayList(u8).init(alloc);
    errdefer al.deinit();

    try al.appendSlice(func_str);
    try al.append('(');

    for (self.args, 0..) |x, i| {
        if (i > 0) {
            try al.appendSlice(", ");
        }

        const x_str = try x.toString(alloc);
        defer alloc.free(x_str);

        try al.appendSlice(x_str);
    }

    try al.append(')');

    return al.toOwnedSlice();
}

test "Call.toString" {
    const alloc = std.testing.allocator;
    const eq = std.testing.expectEqualStrings;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var call = try init(alloc, .EqualFold, .{ x, y, z });
    defer call.deinit();

    const expected = "equal_fold(foo, bar, [3,6,9])";
    const got = try call.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);
}

pub fn deinit(self: *Call) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        return;
    }

    for (self.args) |x| {
        x.deinit();
    }

    self.alloc.free(self.args);
    self.freed = true;
}

test "Call.deinit" {
    const alloc = std.testing.allocator;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var call = try init(alloc, .HasEdge, .{ x, y, z });
    defer call.deinit();

    const f = struct {
        pub fn f(u: *Call) void {
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
        const t = try std.Thread.spawn(.{}, f.f, .{&call});
        t.detach();
    }

    call.deinit();
}

pub fn clone(self: *Call, alloc: Allocator) Allocator.Error!*Call {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.freed) {
        @panic("called Call.clone after it was deinitialized");
    }

    const c = try alloc.create(Call);
    errdefer alloc.destroy(c);

    var arg_clones = try alloc.alloc(Expr, self.args.len);
    errdefer alloc.free(arg_clones);

    for (self.args, 0..) |x, i| {
        arg_clones[i] = try x.clone(alloc);
        errdefer alloc.destroy(arg_clones[i]);
    }

    c.* = .{
        .func = self.func,
        .args = arg_clones,
        .alloc = alloc,
    };

    return c;
}

test "Call.clone" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;
    const eq = std.testing.expectEqual;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 3, 6, 9 });
    errdefer z.deinit();

    var call = try init(alloc, .HasPrefix, .{ x, y, z });
    defer call.deinit();

    var call2 = try call.clone(alloc);
    defer alloc.destroy(call2);
    defer call2.deinit();

    try eq(call.func, call2.func);
    try eq(3, call2.args.len);
    try eq(std.meta.activeTag(call.args[0].expr), std.meta.activeTag(call2.args[0].expr));
    try eq(std.meta.activeTag(call.args[1].expr), std.meta.activeTag(call2.args[1].expr));
    try eq(std.meta.activeTag(call.args[2].expr), std.meta.activeTag(call2.args[2].expr));
    try strEq(call.args[0].expr.Field.name, call2.args[0].expr.Field.name);
    try strEq(call.args[1].expr.Edge.name, call2.args[1].expr.Edge.name);
    try strEq(call.args[2].expr.Value.v, call2.args[2].expr.Value.v);
}

pub fn negate(self: *Call, alloc: Allocator) Allocator.Error!P {
    const call = try self.clone(alloc);
    errdefer alloc.destroy(call);
    errdefer call.deinit();

    const expr = Expr{
        .alloc = alloc,
        .expr = .{
            .P = .{
                .alloc = alloc,
                .p = .{
                    .Call = call,
                },
            },
        },
    };

    const negated = try P.initUnary(alloc, .Not, expr);

    return negated;
}

test "Call.negate" {
    const alloc = std.testing.allocator;
    const strEq = std.testing.expectEqualStrings;

    const x = try Expr.initField(alloc, "foo");
    errdefer x.deinit();
    const y = try Expr.initEdge(alloc, "bar");
    errdefer y.deinit();
    const z = try Expr.initValue(alloc, [_]i32{ 1, 2, 3, 4 });
    errdefer z.deinit();

    var call = try init(alloc, .Contains, .{ x, y, z });
    defer call.deinit();

    var negated = try call.negate(alloc);
    defer negated.deinit();

    const expected = "!(contains(foo, bar, [1,2,3,4]))";
    const got = try negated.toString(alloc);
    defer alloc.free(got);

    try strEq(expected, got);
}
