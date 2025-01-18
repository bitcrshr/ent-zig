const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Value = @This();

v: []const u8,
alloc: Allocator,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn init(alloc: Allocator, v: anytype) Allocator.Error!Value {
    const x_str = try std.json.stringifyAlloc(alloc, v, .{});

    return .{ .v = x_str, .alloc = alloc };
}

pub fn toString(self: *const Value, alloc: Allocator) Allocator.Error![]u8 {
    return alloc.dupe(u8, self.v);
}

pub fn deinit(self: *Value) void {
    if (self.freed) {
        return;
    }

    self.mx.lock();
    self.alloc.free(self.v);
    self.freed = true;
    self.mx.unlock();
}

pub fn clone(self: *const Value, alloc: Allocator) Allocator.Error!*Value {
    const val = try alloc.create(Value);
    errdefer alloc.destroy(val);

    const v = try self.toString(alloc);
    errdefer alloc.free(v);

    val.* = .{ .v = v };

    return val;
}

test "Value" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eq = testing.expectEqualStrings;

    var v_str = try Value.init(alloc, "foo");
    defer v_str.deinit();

    var expected: []const u8 = "\"foo\"";
    var got: []const u8 = try v_str.toString(alloc);
    errdefer alloc.free(got);

    try eq(expected, got);

    alloc.free(got);

    var v_int = try Value.init(alloc, 420);
    defer v_int.deinit();

    expected = "420";
    got = try v_int.toString(alloc);

    try eq(expected, got);

    alloc.free(got);

    var v_float = try Value.init(alloc, 420.69);
    defer v_float.deinit();

    expected = "4.2069e2";
    got = try v_float.toString(alloc);

    try eq(expected, got);

    alloc.free(got);

    var v_null = try Value.init(alloc, null);
    defer v_null.deinit();

    expected = "null";
    got = try v_null.toString(alloc);

    try eq(expected, got);

    alloc.free(got);

    var v_bool = try Value.init(alloc, true);
    defer v_bool.deinit();

    expected = "true";
    got = try v_bool.toString(alloc);

    try eq(expected, got);

    alloc.free(got);

    var v_arr = try Value.init(
        alloc,
        .{ 42, 6.9, true, "yoyoyo" },
    );
    defer v_arr.deinit();

    expected =
        \\[42,6.9e0,true,"yoyoyo"]
    ;
    got = try v_arr.toString(alloc);

    try eq(expected, got);

    alloc.free(got);

    var v_obj = try Value.init(
        alloc,
        .{ .string = "heya", .int = 42, .float = 12.34, .null = null, .bool = true },
    );
    defer v_obj.deinit();

    expected =
        \\{"string":"heya","int":42,"float":1.234e1,"null":null,"bool":true}
    ;
    got = try v_obj.toString(alloc);

    try eq(expected, got);

    alloc.free(got);
}
