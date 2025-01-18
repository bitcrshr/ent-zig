const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Binary = @This();

op: Op,
x: Expr,
y: Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn toString(self: *const Binary, alloc: Allocator) Allocator.Error![]u8 {
    const op_str = self.op.toString();
    const x_str = try self.x.toString(alloc);
    defer alloc.free(x_str);
    const y_str = try self.y.toString(alloc);
    defer alloc.free(y_str);

    const buf = try alloc.alloc(u8, 2 + op_str.len + x_str.len + y_str.len);

    _ = std.fmt.bufPrint(buf, "{s} {s} {s}", .{ x_str, op_str, y_str }) catch unreachable;

    return buf;
}

pub fn deinit(self: *Binary) void {
    if (self.freed) {
        return;
    }

    self.mx.lock();
    self.x.deinit();
    self.y.deinit();
    self.freed = true;
    self.mx.unlock();
}

pub fn clone(self: *const Binary, alloc: Allocator) Allocator.Error!*Binary {
    const b = try alloc.create(Binary);
    errdefer alloc.destroy(b);

    const x = try self.x.clone();
    errdefer alloc.destroy(x);

    const y = try self.y.clone();
    errdefer alloc.destroy(y);

    b.* = .{ .op = self.op, .x = x, .y = y };

    return b;
}
