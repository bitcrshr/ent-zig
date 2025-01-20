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
xs: []*Expr,
alloc: ?*EntAllocator,

pub fn init(op: Op, xs: anytype) *Self {
    comptime {
        const T = @TypeOf(xs);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected xs to be a tuple of *Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected xs to be a tuple of *Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        if (ti.Struct.fields.len == 0) {
            @compileError("Nary requires at least one *Expr to be passed in.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != *Expr) {
                @compileError("expected every element in xs to be a *Expr, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    std.debug.assert(xs[0].alloc != null);

    var alloc: *EntAllocator = xs[0].alloc.?;
    inline for (xs) |x| {
        std.debug.assert(x.alloc == alloc);

        x.alloc = null;
    }

    const exprs = alloc.alloc(*Expr, xs.len);

    inline for (xs, 0..) |x, i| {
        exprs[i] = x;
    }

    const self = alloc.create(Self);
    self.* = .{ .op = op, .xs = exprs, .alloc = alloc };

    return self;
}

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        return;
    }

    self.alloc.?.deinit();
}

pub fn negate(self: *Self) *Predicate {
    const Unary = @import("./Unary.zig");

    const self_expr = self.expr();
    const negated = Unary.init(.Not, self_expr);

    return negated.pred();
}

pub fn toString(self: *Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
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

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const n: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(n, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const n: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(n);
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
            const n: *Self = @ptrCast(@alignCast(ptr));

            return n.toString(alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const n: *Self = @ptrCast(@alignCast(ptr));

            return n.deinit();
        }

        pub fn negate(ptr: *anyopaque, alloc: *EntAllocator) *Predicate {
            const n: *Self = @ptrCast(@alignCast(ptr));

            n.alloc = alloc;

            return n.negate();
        }

        pub fn expr(ptr: *anyopaque, alloc: *EntAllocator) *Expr {
            const n: *Self = @ptrCast(@alignCast(ptr));

            n.alloc = alloc;

            return n.expr();
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

test "Nary" {
    const Edge = @import("./Edge.zig");
    const Field = @import("./Field.zig");
    const Value = @import("./Value.zig");

    const alloc = EntAllocator.init(std.testing.allocator, .{});

    const edge = Edge.init(alloc, "foo").expr();
    const field = Field.init(alloc, "bar").expr();
    const value = (try Value.init(alloc, "baz")).expr();

    const nary = init(.Or, .{ edge, field, value });

    var expected: []const u8 = "(foo || bar || \"baz\")";
    var got = try nary.toString(std.testing.allocator);

    try std.testing.expectEqualStrings(expected, got);

    std.testing.allocator.free(got);

    const negated = nary.negate();
    defer negated.deinit();

    expected = "!((foo || bar || \"baz\"))";
    got = try negated.toString(std.testing.allocator);
    defer std.testing.allocator.free(got);

    try std.testing.expectEqualStrings(expected, got);
}
