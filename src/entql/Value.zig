const std = @import("std");

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const util = @import("util");
const EntAllocator = util.EntAllocator;

const Expr = @import("./Expr.zig");

const Self = @This();

v: std.json.Value,
json: []const u8,
alloc: ?*EntAllocator,

pub fn init(alloc: *EntAllocator, v: anytype) !*Self {
    const json = std.json.stringifyAlloc(
        alloc.allocator(),
        v,
        .{},
    ) catch unreachable;

    const value = std.json.parseFromSliceLeaky(
        std.json.Value,
        alloc.allocator(),
        json,
        .{},
    ) catch |e| {
        switch (e) {
            error.OutOfMemory => unreachable,
            inline else => return e,
        }
    };

    const self = alloc.create(Self);
    self.* = .{
        .v = value,
        .json = json,
        .alloc = alloc,
    };

    return self;
}

pub fn toString(self: *const Self, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
    return alloc.dupe(u8, self.json);
}

pub fn expr(self: *Self) *Expr {
    std.debug.assert(self.alloc != null);

    const Impl = struct {
        pub fn toString(ptr: *anyopaque, alloc: std.mem.Allocator) std.mem.Allocator.Error![]const u8 {
            const v: *Self = @ptrCast(@alignCast(ptr));

            return Self.toString(v, alloc);
        }

        pub fn deinit(ptr: *anyopaque) void {
            const v: *Self = @ptrCast(@alignCast(ptr));

            return Self.deinit(v);
        }
    };

    // I am now the child, so I need to give my allocator to my parent.
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

pub fn deinit(self: *Self) void {
    if (self.alloc == null) {
        return;
    }

    self.alloc.?.deinit();
}

test "Value" {
    const v = try init(EntAllocator.init(std.testing.allocator, .{}), 42);
    defer v.deinit();

    const v_str = try v.toString(std.testing.allocator);
    defer std.testing.allocator.free(v_str);

    try std.testing.expectEqualStrings("42", v_str);
}
