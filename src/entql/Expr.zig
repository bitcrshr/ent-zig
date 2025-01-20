const std = @import("std");
const assert = std.debug.assert;

const enums = @import("./enums.zig");
const util = @import("util");

const Op = enums.Op;
const Func = enums.Func;

const Binary = @import("./Binary.zig");

const Predicate = @import("./Predicate.zig");

const Self = @This();

ptr: *anyopaque,
vt: *const VTable,

/// Only has an alloc when it is the parent. When it is the child,
/// the parent will take the allocator.
alloc: ?*util.EntAllocator,

const VTable = struct {
    toString: *const fn (*anyopaque, std.mem.Allocator) std.mem.Allocator.Error![]const u8,
    deinit: *const fn (*anyopaque) void,
};

/// Returns the string representation of this Expr, using the provided `Allocator`.
pub fn toString(self: Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return self.vt.toString(self.ptr, alloc);
}

/// Frees all associated memory owned by this Expr (and its children).
pub fn deinit(self: Self) void {
    if (self.alloc == null) {
        // I am a child, my parent is responsible for releasing my memory.
        return;
    }

    // I am the parent, and I am responsible for releasing my memory and that
    // of my children.
    self.vt.deinit(self.ptr);
}

pub fn @"and"(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.And, self, other);

    return binary.pred();
}

pub fn @"or"(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Or, self, other);

    return binary.pred();
}

pub fn eq(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Eq, self, other);

    return binary.pred();
}

pub fn neq(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Neq, self, other);

    return binary.pred();
}

pub fn gt(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Gt, self, other);

    return binary.pred();
}

pub fn gte(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Gte, self, other);

    return binary.pred();
}

pub fn lt(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Lt, self, other);

    return binary.pred();
}

pub fn lte(self: *Self, other: *Self) *Predicate {
    const binary = Binary.init(.Lte, self, other);

    return binary.pred();
}
