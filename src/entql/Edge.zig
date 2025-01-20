const std = @import("std");

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const util = @import("util");
const EntAllocator = util.EntAllocator;

const Expr = @import("./Expr.zig");
const Predicate = @import("./Predicate.zig");

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

pub fn exists(self: *Self) *Predicate {
    const call = Call.init(.HasEdge, .{self.expr()});

    return call.pred();
}

pub inline fn existsWith(self: *Self, ps: anytype) *Predicate {
    comptime {
        const T = @TypeOf(ps);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected ps to be a tuple of *Predicate, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected ps to be a tuple of *Predicate, but found " ++ @typeName(T) ++ " instead.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != *Predicate) {
                @compileError("expected every element in ps to be a *Predicate, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    const types = [_]type{*Expr} ** (ps.len + 1);

    const Tuple = std.meta.Tuple(types[0..]);
    var tpl: Tuple = undefined;

    tpl[0] = self.expr();

    inline for (ps, 0..) |p, i| {
        tpl[i + 1] = p.expr();
    }

    const call = Call.init(.HasEdge, tpl);

    return call.pred();
}
