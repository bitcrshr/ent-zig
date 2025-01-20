const std = @import("std");

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const util = @import("util");
const EntAllocator = util.EntAllocator;

const Expr = @import("./Expr.zig");
const Predicate = @import("./Predicate.zig");

const Value = @import("./Value.zig");
const Binary = @import("./Binary.zig");
const Call = @import("./Call.zig");

const Self = @This();

name: []const u8,
alloc: ?*EntAllocator,

pub fn init(alloc: *EntAllocator, name: []const u8) *Self {
    const dupe = alloc.dupe(u8, name);

    const self = alloc.create(Self);
    self.* = .{ .name = dupe, .alloc = alloc };

    return self;
}

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        return;
    }

    self.alloc.?.deinit();
}

pub fn toString(self: *const Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    const name = try alloc.dupe(u8, self.name);

    return name;
}

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const f: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(f, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const v: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(v);
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

pub fn eq(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    std.debug.assert(val.alloc != null);
    const binary = Binary.init(.Eq, self.expr(), val.expr());
    std.debug.assert(binary.alloc != null);
    std.debug.assert(val.alloc == null);

    const pred = binary.pred();

    std.debug.assert(pred.alloc != null);
    std.debug.assert(binary.alloc == null);
    std.debug.assert(val.alloc == null);

    return pred;
}

pub fn neq(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    const binary = Binary.init(.Neq, self.expr(), val.expr());

    return binary.pred();
}

pub fn gt(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    const binary = Binary.init(.Gt, self.expr(), val.expr());

    return binary.pred();
}

pub fn gte(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    const binary = Binary.init(.Gte, self.expr(), val.expr());

    return binary.pred();
}

pub fn lt(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    const binary = Binary.init(.Lt, self.expr(), val.expr());

    return binary.pred();
}

pub fn lte(self: *Self, v: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;
    const binary = Binary.init(.Lte, self.expr(), val.expr());

    return binary.pred();
}

pub fn contains(self: *Self, substr: []const u8) *Predicate {
    std.debug.assert(self.alloc != null);
    const v = Value.init(self.alloc.?, substr) catch unreachable;

    const call = Call.init(.Contains, .{ self.expr(), v.expr() });

    return call.pred();
}

pub fn containsFold(self: *Self, substr: []const u8) *Predicate {
    std.debug.assert(self.alloc != null);
    const v = Value.init(self.alloc.?, substr) catch unreachable;

    const call = Call.init(.ContainsFold, .{ self.expr(), v.expr() });

    return call.pred();
}

pub fn equalFold(self: *Self, v: []const u8) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, v) catch unreachable;

    const call = Call.init(.EqualFold, .{ self.expr(), val.expr() });

    return call.pred();
}

pub fn hasPrefix(self: *Self, prefix: []const u8) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, prefix) catch unreachable;

    const call = Call.init(.HasPrefix, .{ self.expr(), val.expr() });

    return call.pred();
}

pub fn hasSuffix(self: *Self, suffix: []const u8) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, suffix) catch unreachable;

    const call = Call.init(.HasSuffix, .{ self.expr(), val.expr() });

    return call.pred();
}

pub fn in(self: *Self, vs: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, vs) catch unreachable.?;

    const binary = Binary.init(.In, self.expr(), val.expr());

    return binary.pred();
}

pub fn notIn(self: *Self, vs: anytype) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, vs) catch unreachable.?;

    const binary = Binary.init(.NotIn, self.expr(), val.expr());

    return binary.pred();
}

pub fn isNull(self: *Self) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, null) catch unreachable;

    const binary = Binary.init(.Eq, self.expr(), val.expr());

    return binary.pred();
}

pub fn isNotNull(self: *Self) *Predicate {
    std.debug.assert(self.alloc != null);
    const val = Value.init(self.alloc.?, null) catch unreachable;

    const binary = Binary.init(.Neq, self.expr(), val.expr());

    return binary.pred();
}
