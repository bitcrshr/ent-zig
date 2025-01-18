const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Call = @This();

func: Func,
args: []Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn toString(self: *const Call, alloc: Allocator) Allocator.Error![]u8 {
    const func_str = self.func.toString();

    var al = std.ArrayList(u8).init(alloc);
    errdefer al.deinit();

    try al.appendSlice(func_str);
    try al.append('(');

    for (self.args, 0..) |x, i| {
        if (i > 0) {
            try al.appendSlice(", ");
        }

        const x_str = try x.toString(alloc);
        defer alloc.free(x_str);

        try al.appendSlice(x_str);
    }

    try al.append(')');

    return al.toOwnedSlice();
}

pub fn deinit(self: *Call) void {
    if (self.freed) {
        return;
    }

    self.mx.lock();
    for (self.args) |x| {
        x.deinit();
    }
    self.freed = true;
    self.mx.unlock();
}

pub fn clone(self: *const Call, alloc: Allocator) Allocator.Error!*Call {
    const c = try alloc.create(Call);
    errdefer alloc.destroy(c);

    var arg_clones: [self.args.len]Expr = undefined;

    for (self.args, 0..) |x, i| {
        arg_clones[i] = try x.clone();
        errdefer alloc.destroy(arg_clones[i]);
    }

    c.* = .{ .func = self.func, .args = arg_clones };

    return c;
}
