const std = @import("std");

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");
const Predicate = @import("./Predicate.zig");

const util = @import("util");
const EntAllocator = util.EntAllocator;

const Self = @This();

op: Op,
x: *Expr,
y: *Expr,
alloc: ?*EntAllocator,

pub fn init(op: Op, x: *Expr, y: *Expr) *Self {
    std.debug.assert(x.alloc != null);
    std.debug.assert(y.alloc != null);
    std.debug.assert(x.alloc.? == y.alloc.?);

    const alloc = x.alloc.?;
    x.alloc = null;
    y.alloc = null;
    const self = alloc.create(Self);

    self.* = .{
        .op = op,
        .x = x,
        .y = y,
        .alloc = alloc,
    };

    return self;
}

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        return;
    }

    self.alloc.?.deinit();
}

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const b: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(b, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const b: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(b);
        }
    };

    const parent_expr = self.alloc.?.create(Expr);
    parent_expr.* = .{
        .ptr = self,
        .alloc = self.alloc,
        .vt = &.{
            .toString = Impl.toString,
            .deinit = Impl.deinit,
        },
    };
    self.alloc = null;

    return parent_expr;
}

pub fn pred(self: *Self) *Predicate {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const b: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(b, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const b: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(b);
        }

        pub fn negate(ptr: *anyopaque, alloc: *EntAllocator) *Predicate {
            const b: *Self = @ptrCast(@alignCast(ptr));

            b.alloc = alloc;

            return Self.negate(b);
        }

        pub fn expr(ptr: *anyopaque, alloc: *EntAllocator) *Expr {
            const b: *Self = @ptrCast(@alignCast(ptr));

            b.alloc = alloc;

            return Self.expr(b);
        }
    };

    const parent_pred = self.alloc.?.create(Predicate);
    parent_pred.* = .{
        .ptr = self,
        .alloc = self.alloc,
        .vt = &.{
            .toString = Impl.toString,
            .deinit = Impl.deinit,
            .negate = Impl.negate,
            .expr = Impl.expr,
        },
    };
    self.alloc = null;

    return parent_pred;
}

pub fn toString(self: *const Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    const op_str = self.op.toString();

    const x_str = try self.x.toString(alloc);
    defer alloc.free(x_str);

    const y_str = try self.y.toString(alloc);
    defer alloc.free(y_str);

    const buf = try alloc.alloc(
        u8,
        x_str.len + " ".len + op_str.len + " ".len + y_str.len,
    );

    return std.fmt.bufPrint(buf, "{s} {s} {s}", .{ x_str, op_str, y_str }) catch unreachable;
}

pub fn negate(self: *Self) *Predicate {
    const Unary = @import("./Unary.zig");

    const self_expr = self.expr();
    const negated = Unary.init(.Not, self_expr);

    return negated.pred();
}

test "Binary" {
    const Edge = @import("./Edge.zig");
    const Field = @import("./Field.zig");

    const alloc = EntAllocator.init(std.testing.allocator, .{});

    const edge = Edge.init(alloc, "foo");

    const field = Field.init(alloc, "bar");

    var binary = init(.NotIn, edge.expr(), field.expr());

    var expected: []const u8 = "foo not in bar";
    var got = try binary.toString(std.testing.allocator);

    try std.testing.expectEqualStrings(expected, got);

    std.testing.allocator.free(got);

    var negated = binary.negate();
    defer negated.deinit();

    expected = "!(foo not in bar)";
    got = try negated.toString(std.testing.allocator);
    defer std.testing.allocator.free(got);

    try std.testing.expectEqualStrings(expected, got);
}
