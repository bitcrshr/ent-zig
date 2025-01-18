const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Unary = @This();

op: Op,
x: Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn toString(self: *const Unary, alloc: Allocator) Allocator.Error![]u8 {
    const op_str = self.op.toString();
    const x_str = try self.x.toString(alloc);
    defer alloc.free(x_str);

    const buf = try alloc.alloc(u8, 2 + op_str.len + x_str.len);
    errdefer buf.deinit();

    _ = std.fmt.bufPrint(buf, "{s}({s})", .{ op_str, x_str }) catch unreachable;

    return buf;
}

pub fn deinit(self: *Unary) void {
    if (self.freed) {
        return;
    }

    self.mx.lock();
    self.x.deinit();
    self.freed = true;
    self.mx.unlock();
}

pub fn clone(self: *const Unary, alloc: Allocator) Allocator.Error!*Unary {
    const u = try alloc.create(Unary);
    errdefer alloc.destroy(u);

    const x = try self.x.clone();
    errdefer alloc.destroy(x);

    u.* = .{ .x = x, .op = self.op };

    return u;
}
