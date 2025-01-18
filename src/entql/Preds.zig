const std = @import("std");
const Allocator = std.mem.Allocator;

const Unary = @import("./Unary.zig");
const Binary = @import("./Binary.zig");
const Nary = @import("./Nary.zig");
const Call = @import("./Call.zig");
const Field = @import("./Field.zig");
const Edge = @import("./Edge.zig");
const Value = @import("./Value.zig");
const Expr = @import("./Expr.zig");
const P = @import("./P.zig");

const Pred = @This();

arena: *std.heap.ArenaAllocator,
alloc: Allocator,

pub fn init(alloc: Allocator) Allocator.Error!Pred {
    const arena = try alloc.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(alloc);

    return .{ .arena = arena, .alloc = arena.allocator() };
}

pub fn deinit(self: Pred) void {
    const alloc = self.arena.child_allocator;
    self.arena.deinit();
    alloc.destroy(self.arena);
}

pub fn not(self: Pred, x: P) Allocator.Error!P {
    return switch (x.p) {
        inline .Unary => |u| u.negate(self.alloc),
        inline .Binary => |b| b.negate(self.alloc),
        inline .Nary => |n| n.negate(self.alloc),
        inline .Call => |c| c.negate(self.alloc),
    };
}

pub fn @"and"(self: Pred, x: P, y: P, z: anytype) Allocator.Error!P {
    comptime {
        const T = @TypeOf(z);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected z to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected z to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != P) {
                @compileError("expected every element in z to be a P, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    return switch (z.len) {
        inline 0 => P.initBinary(self.alloc, .And, try x.toExpr(self.alloc), try y.toExpr(self.alloc)),
        inline else => {
            var ps = try self.alloc.alloc(P, z.len + 2);
            errdefer self.alloc.free(ps);

            ps[0] = x;
            ps[1] = y;

            inline for (z, 0..) |p, i| {
                ps[i + 2] = try p.toExpr(self.alloc);
            }

            return P.initNary(self.alloc, .And, std.meta.Tuple(ps));
        },
    };
}

pub fn @"or"(self: Pred, x: P, y: P, z: anytype) Allocator.Error!P {
    comptime {
        const T = @TypeOf(z);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected z to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected z to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != P) {
                @compileError("expected every element in z to be a P, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    return switch (z.len) {
        inline 0 => P.initBinary(self.alloc, .Or, try x.toExpr(self.alloc), try y.toExpr(self.alloc)),
        inline else => {
            var ps = try self.alloc.alloc(P, z.len + 2);
            errdefer self.alloc.free(ps);

            ps[0] = x;
            ps[1] = y;

            inline for (z, 0..) |p, i| {
                ps[i + 2] = try p.toExpr(self.alloc);
            }

            return P.initNary(self.alloc, .Or, std.meta.Tuple(ps));
        },
    };
}

pub fn eq(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Eq, x, y);
}

pub fn fieldEq(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Eq, field, value);
}

pub fn neq(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Eq, x, y);
}

pub fn fieldNeq(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Neq, field, value);
}

pub fn gt(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Gt, x, y);
}

pub fn fieldGt(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Gt, field, value);
}

pub fn gte(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Gte, x, y);
}

pub fn fieldGte(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Gte, field, value);
}

pub fn lt(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Lt, x, y);
}

pub fn fieldLt(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Lt, field, value);
}

pub fn lte(self: Pred, x: Expr, y: Expr) Allocator.Error!P {
    return P.initBinary(self.alloc, .Lte, x, y);
}

pub fn fieldLte(self: Pred, name: []const u8, v: anytype) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .Lte, field, value);
}

pub fn fieldContains(self: Pred, name: []const u8, substr: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, substr);
    errdefer value.deinit();

    return P.initCall(self.alloc, .Contains, .{ field, value });
}

pub fn fieldContainsFold(self: Pred, name: []const u8, substr: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, substr);
    errdefer value.deinit();

    return P.initCall(self.alloc, .ContainsFold, .{ field, value });
}

pub fn fieldEqualFold(self: Pred, name: []const u8, v: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, v);
    errdefer value.deinit();

    return P.initCall(self.alloc, .EqualFold, .{ field, value });
}

pub fn fieldHasPrefix(self: Pred, name: []const u8, prefix: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, prefix);
    errdefer value.deinit();

    return P.initCall(self.alloc, .HasPrefix, .{ field, value });
}

pub fn fieldHasSuffix(self: Pred, name: []const u8, suffix: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, suffix);
    errdefer value.deinit();

    return P.initCall(self.alloc, .HasSuffix, .{ field, value });
}

pub fn hasEdge(self: Pred, name: []const u8) Allocator.Error!P {
    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    return P.initCall(self.alloc, .HasEdge, .{field});
}

pub fn hasEdgeWith(self: Pred, name: []const u8, p: anytype) Allocator.Error!P {
    comptime {
        const T = @TypeOf(p);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected p to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected p to be a tuple of P, but found " ++ @typeName(T) ++ " instead.");
        }

        for (ti.Struct.fields) |field| {
            if (field.type != P) {
                @compileError("expected every element in p to be a P, but found " ++ @typeName(field.type) ++ " instead.");
            }
        }
    }

    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const len = @typeInfo(@TypeOf(p)).Struct.fields.len;
    const Tpl = std.meta.Tuple(&([len]type{Expr} ** (len + 1)));
    var exprs: Tpl = undefined;
    exprs[0] = field;

    inline for (p, 0..) |x, i| {
        exprs[i + 1] = try x.toExpr(self.alloc);
    }

    const call = try P.initCall(self.alloc, .HasEdge, exprs);

    return call;
}

pub fn fieldIn(self: Pred, name: []const u8, vs: anytype) Allocator.Error!P {
    comptime {
        const T = @TypeOf(vs);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected vs to be a tuple, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected vs to be a tuple, but found " ++ @typeName(T) ++ " instead.");
        }
    }

    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, vs);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .In, field, value);
}

pub fn fieldNotIn(self: Pred, name: []const u8, vs: anytype) Allocator.Error!P {
    comptime {
        const T = @TypeOf(vs);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected vs to be a tuple, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected vs to be a tuple, but found " ++ @typeName(T) ++ " instead.");
        }
    }

    const field = try Expr.initField(self.alloc, name);
    errdefer field.deinit();

    const value = try Expr.initValue(self.alloc, vs);
    errdefer value.deinit();

    return P.initBinary(self.alloc, .NotIn, field, value);
}

pub fn fieldNull(self: Pred, name: []const u8) Allocator.Error!P {
    return P.initBinary(
        self.alloc,
        .Eq,
        try Expr.initField(self.alloc, name),
        try Expr.initValue(self.alloc, null),
    );
}

pub fn fieldNotNull(self: Pred, name: []const u8) Allocator.Error!P {
    return P.initBinary(
        self.alloc,
        .Neq,
        try Expr.initField(self.alloc, name),
        try Expr.initValue(self.alloc, null),
    );
}
