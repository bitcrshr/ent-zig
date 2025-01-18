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

pub fn clone(self: *const P, alloc: Allocator) Allocator.Error!P {
    const impl: PImpl = switch (self.p) {
        inline .Unary => |unary| try unary.clone(alloc),
        inline .Binary => |binary| try binary.clone(alloc),
        inline .Nary => |nary| try nary.clone(alloc),
        inline .Call => |call| try call.clone(alloc),
    };

    return .{ .p = impl, .alloc = alloc };
}

pub fn initUnary(alloc: Allocator, op: Op, x: Expr) Allocator.Error!P {
    const unary = try alloc.create(Unary);
    errdefer alloc.destroy(unary);

    unary.* = .{ .op = op, .x = x };

    return .{
        .p = .{ .Unary = unary },
        .alloc = alloc,
    };
}

pub fn initBinary(alloc: Allocator, op: Op, x: Expr, y: Expr) Allocator.Error!P {
    const binary = try alloc.create(Binary);
    errdefer alloc.destroy(binary);

    binary.* = .{ .op = op, .x = x, .y = y };

    return .{
        .p = .{ .Binary = binary },
        .alloc = alloc,
    };
}

pub fn initNary(alloc: Allocator, op: Op, xs: anytype) Allocator.Error!P {
    const nary = try alloc.create(Nary);
    errdefer alloc.destroy(nary);

    comptime var exprs: [xs.len]Expr = undefined;
    comptime {
        const T = @TypeOf(xs);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected xs to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected xs to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        assert(xs.len == ti.Struct.fields.len);

        for (xs, 0..) |x, i| {
            const field = ti.Struct.fields[i];

            if (field.type != Expr) {
                @compileError("expected every element in xs to be a Expr, but found " ++ @typeName(field.type) ++ " instead.");
            }

            exprs[i] = x;
        }
    }

    nary.* = .{ .op = op, .xs = exprs };

    return .{ .p = .{ .Nary = nary } };
}

pub fn initCall(alloc: Allocator, func: Func, args: anytype) Allocator.Error!P {
    const call = try alloc.create(Call);
    errdefer alloc.destroy(call);

    comptime var exprs: [args.len]Expr = undefined;
    comptime {
        const T = @TypeOf(args);
        const ti = @typeInfo(T);

        if (ti != .Struct) {
            @compileError("expected args to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        if (!ti.Struct.is_tuple) {
            @compileError("expected args to be a tuple of Expr, but found " ++ @typeName(T) ++ " instead.");
        }

        assert(args.len == ti.Struct.fields.len);

        for (args, 0..) |x, i| {
            const field = ti.Struct.fields[i];

            if (field.type != Expr) {
                @compileError("expected every element in args to be a Expr, but found " ++ @typeName(field.type) ++ " instead.");
            }

            exprs[i] = x;
        }
    }

    call.* = .{ .func = func, .args = exprs };

    return .{ .p = .{ .Call = call } };
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
        inline .Unary => |unary| unary.deinit(),
        inline .Binary => |binary| binary.deinit(),
        inline .Nary => |nary| nary.deinit(),
        inline .Call => |call| call.deinit(),
    }
}
