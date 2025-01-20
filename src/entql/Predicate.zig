const std = @import("std");

const util = @import("util");

const Expr = @import("./Expr.zig");

const Binary = @import("./Binary.zig");

const Self = @This();

/// The type-erased pointer to the predicate implementation.
ptr: *anyopaque,

vt: *const VTable,

alloc: ?*util.EntAllocator,

pub const VTable = struct {
    toString: *const fn (*anyopaque, std.mem.Allocator) std.mem.Allocator.Error![]const u8,
    negate: *const fn (*anyopaque, *util.EntAllocator) *Self,
    deinit: *const fn (*anyopaque) void,
    expr: *const fn (*anyopaque, *util.EntAllocator) *Expr,
};

pub fn toString(self: *Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return self.vt.toString(self.ptr, alloc);
}

pub fn negate(self: *Self) *Self {
    std.debug.assert(self.alloc != null);

    const negated = self.vt.negate(self.ptr, self.alloc.?);
    self.alloc = null;

    return negated;
}

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        return;
    }

    self.alloc.?.deinit();
}

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);
    const exp = self.vt.expr(self.ptr, self.alloc.?);
    self.alloc = null;

    return exp;
}

pub fn @"and"(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().@"and"(other.expr());
    }

    if (T == *Expr) {
        return self.expr().@"and"(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn @"or"(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().@"or"(other.expr());
    }

    if (T == *Expr) {
        return self.expr().@"or"(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn eq(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().eq(other.expr());
    }

    if (T == *Expr) {
        return self.expr().eq(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn neq(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().neq(other.expr());
    }

    if (T == *Expr) {
        return self.expr().neq(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn gt(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().gt(other.expr());
    }

    if (T == *Expr) {
        return self.expr().gt(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn gte(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().gte(other.expr());
    }

    if (T == *Expr) {
        return self.expr().gte(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn lt(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().lt(other.expr());
    }

    if (T == *Expr) {
        return self.expr().lt(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}

pub fn lte(self: *Self, other: anytype) *Self {
    const T = @TypeOf(other);
    if (T == *Self) {
        return self.expr().lte(other.expr());
    }

    if (T == *Expr) {
        return self.expr().lte(other);
    }

    @compileError("Expected `other` to be *Expr or *Predicate, but got " ++ @typeName(T));
}
