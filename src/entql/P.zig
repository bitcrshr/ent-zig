const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const assert = std.debug.assert;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Unary = @import("./Unary.zig");
const Binary = @import("./Binary.zig");
const Nary = @import("./Nary.zig");
const Call = @import("./Call.zig");
const Field = @import("./Field.zig");
const Edge = @import("./Edge.zig");
const Value = @import("./Value.zig");

const P = @This();

const PImpl = union(enum) {
    Unary: *Unary,
    Binary: *Binary,
    Nary: *Nary,
    Call: *Call,
};

p: PImpl,
alloc: Allocator,

pub fn toExpr(self: P, alloc: Allocator) Allocator.Error!Expr {
    switch (self.p) {
        inline .Unary => |unary| {
            const u = try unary.clone(alloc);
            self.deinit();

            return Expr{
                .expr = .{
                    .P = .{
                        .p = .{ .Unary = u },
                        .alloc = alloc,
                    },
                },
                .alloc = alloc,
            };
        },

        inline .Binary => |binary| {
            const b = try binary.clone(alloc);
            self.deinit();

            return Expr{
                .expr = .{
                    .P = .{
                        .p = .{ .Binary = b },
                        .alloc = alloc,
                    },
                },
                .alloc = alloc,
            };
        },

        inline .Nary => |nary| {
            const n = try nary.clone(alloc);
            self.deinit();

            return Expr{
                .expr = .{
                    .P = .{
                        .p = .{ .Nary = n },
                        .alloc = alloc,
                    },
                },
                .alloc = alloc,
            };
        },

        inline .Call => |call| {
            const c = try call.clone(alloc);
            self.deinit();

            return Expr{
                .expr = .{
                    .P = .{
                        .p = .{ .Call = c },
                        .alloc = alloc,
                    },
                },
                .alloc = alloc,
            };
        },
    }
}

test "P.toExpr" {
    const alloc = std.testing.allocator;
    const eqStr = std.testing.expectEqualStrings;

    const unary = try initUnary(alloc, .Not, try Expr.initValue(alloc, null));
    errdefer unary.deinit();
    const unaryExpr = try unary.toExpr(alloc);
    defer unaryExpr.deinit();

    const expected = "!(null)";
    const got = try unaryExpr.toString(alloc);
    defer alloc.free(got);

    try eqStr(expected, got);
}

pub fn clone(self: *const P, alloc: Allocator) Allocator.Error!P {
    const impl: PImpl = switch (self.p) {
        inline .Unary => |unary| .{ .Unary = try unary.clone(alloc) },
        inline .Binary => |binary| .{ .Binary = try binary.clone(alloc) },
        inline .Nary => |nary| .{ .Nary = try nary.clone(alloc) },
        inline .Call => |call| .{ .Call = try call.clone(alloc) },
    };

    return .{ .p = impl, .alloc = alloc };
}

pub fn initUnary(alloc: Allocator, op: Op, x: Expr) Allocator.Error!P {
    const unary = try alloc.create(Unary);
    errdefer alloc.destroy(unary);

    unary.* = Unary.init(op, x);

    return .{
        .p = .{ .Unary = unary },
        .alloc = alloc,
    };
}

pub fn initBinary(alloc: Allocator, op: Op, x: Expr, y: Expr) Allocator.Error!P {
    const binary = try alloc.create(Binary);
    errdefer alloc.destroy(binary);

    binary.* = Binary.init(op, x, y);

    return .{
        .p = .{ .Binary = binary },
        .alloc = alloc,
    };
}

pub fn initNary(alloc: Allocator, op: Op, exprs: anytype) Allocator.Error!P {
    const nary = try alloc.create(Nary);
    errdefer alloc.destroy(nary);

    nary.* = try Nary.init(alloc, op, exprs);

    return .{ .p = .{ .Nary = nary } };
}

pub fn initCall(alloc: Allocator, func: Func, exprs: anytype) Allocator.Error!P {
    const call = try alloc.create(Call);
    errdefer alloc.destroy(call);

    call.* = try Call.init(alloc, func, exprs);

    return .{ .p = .{ .Call = call }, .alloc = alloc };
}

pub fn toString(self: P, alloc: Allocator) Allocator.Error![]u8 {
    return switch (self.p) {
        inline .Unary => |unary| unary.toString(alloc),
        inline .Binary => |binary| binary.toString(alloc),
        inline .Nary => |nary| nary.toString(alloc),
        inline .Call => |call| call.toString(alloc),
    };
}

pub fn deinit(self: *const P) void {
    switch (self.p) {
        inline .Unary => |unary| {
            unary.deinit();
            self.alloc.destroy(unary);
        },

        inline .Binary => |binary| {
            binary.deinit();
            self.alloc.destroy(binary);
        },

        inline .Nary => |nary| {
            nary.deinit();
            self.alloc.destroy(nary);
        },

        inline .Call => |call| {
            call.deinit();
            self.alloc.destroy(call);
        },
    }
}

pub fn negate(self: P, alloc: Allocator) Allocator.Error!P {
    return switch (self.p) {
        inline .Unary => |unary| unary.negate(alloc),
        inline .Binary => |binary| binary.negate(alloc),
        inline .Nary => |nary| nary.negate(alloc),
        inline .Call => |call| call.negate(alloc),
    };
}
