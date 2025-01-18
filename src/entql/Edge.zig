const std = @import("std");
const Allocator = std.mem.Allocator;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Edge = @This();

name: []const u8,

pub fn toString(self: *const Edge, alloc: Allocator) Allocator.Error![]u8 {
    return alloc.dupe(u8, self.name);
}

pub fn deinit(self: *Edge) void {
    _ = self;
}

pub fn clone(self: *const Edge, alloc: Allocator) Allocator.Error!*Edge {
    const e = try alloc.create(Edge);
    errdefer alloc.destroy(e);

    const name = try self.toString(alloc);
    errdefer alloc.free(name);

    e.* = .{ .name = name };

    return e;
}

test "Edge" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eq = testing.expectEqualStrings;

    const field = Edge{ .name = "hey" };
    const field_str = try field.toString(alloc);
    defer alloc.free(field_str);

    const expected = "hey";

    try eq(expected, field_str);
}
