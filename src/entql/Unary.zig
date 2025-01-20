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

/// Only has an alloc when it is the parent. When it is the child,
/// the parent will take the allocator.
alloc: ?*EntAllocator,

pub fn init(op: Op, x: *Expr) *Self {
    std.debug.assert(x.alloc != null);

    // I am now the parent, so I will thake the child's allocator.
    const alloc = x.alloc.?;
    x.alloc = null;

    const self = alloc.create(Self);
    self.* = .{ .op = op, .x = x, .alloc = alloc };

    return self;
}

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        // I am a child, my parent is responsible for releasing my memory.
        return;
    }

    // I am the parent, and I am responsible for releasing my memory and that
    // of my children.
    self.alloc.?.deinit();
}

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const u: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(u, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const u: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(u);
        }
    };

    // I am now the child, so I need to give my allocator to my parent.
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
    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const u: *Self = @ptrCast(@alignCast(ptr));

            return u.toString(alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const u: *Self = @ptrCast(@alignCast(ptr));

            return u.deinit();
        }

        pub fn negate(ptr: *anyopaque, alloc: *EntAllocator) *Predicate {
            const u: *Self = @ptrCast(@alignCast(ptr));

            u.alloc = alloc;

            return u.negate();
        }

        pub fn expr(ptr: *anyopaque, alloc: *EntAllocator) *Expr {
            const u: *Self = @ptrCast(@alignCast(ptr));

            u.alloc = alloc;

            return u.expr();
        }
    };

    // I am now the child, so I need to give my allocator to my parent.
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

    const buf = try alloc.alloc(u8, op_str.len + "(".len + x_str.len + ")".len);
    errdefer alloc.free(buf);

    return std.fmt.bufPrint(buf, "{s}({s})", .{ op_str, x_str }) catch unreachable;
}

pub fn negate(self: *Self) *Predicate {
    // I give my alloc to the Expr
    const self_expr = self.expr();

    // self_expr gives its alloc to a new Unary
    const negated = init(.Not, self_expr);

    // negated gives its alloc to the Predicate
    return negated.pred();
}

test "Unary" {
    const Value = @import("./Value.zig");

    const alloc = EntAllocator.init(std.testing.allocator, .{});

    const v = try Value.init(alloc, 42);

    var unary = init(.Not, v.expr());
    defer unary.deinit();

    const expected = "!(42)";
    const got = try unary.toString(std.testing.allocator);
    defer std.testing.allocator.free(got);

    try std.testing.expectEqualStrings(expected, got);
}
