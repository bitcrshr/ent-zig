const std = @import("std");
const Allocator = std.mem.Allocator;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Field = @This();

name: []const u8,

pub fn toString(self: *const Field, alloc: Allocator) Allocator.Error![]u8 {
    return alloc.dupe(u8, self.name);
}

pub fn deinit(self: *Field) void {
    _ = self;
}

pub fn clone(self: *const Field, alloc: Allocator) Allocator.Error!*Field {
    const f = try alloc.create(Field);
    errdefer alloc.destroy(f);

    const name = try self.toString(alloc);
    errdefer alloc.free(name);

    f.* = .{ .name = name };

    return f;
}

test "Field" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eq = testing.expectEqualStrings;

    const field = Field{ .name = "hey" };
    const field_str = try field.toString(alloc);
    defer alloc.free(field_str);

    const expected = "hey";

    try eq(expected, field_str);
}
