const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./Expr.zig");

const Nary = @This();

op: Op,
xs: []Expr,
mx: Mutex = Mutex{},
freed: bool = false,

pub fn toString(self: *const Nary, alloc: Allocator) Allocator.Error![]u8 {
    const op_str = self.op.toString();

    var al = std.ArrayList(u8).init(alloc);
    errdefer al.deinit();

    try al.append('(');

    for (self.xs, 0..) |x, i| {
        if (i > 0) {
            try al.append(' ');
            try al.appendSlice(op_str);
            try al.append(' ');
        }

        const x_str = try x.toString(alloc);
        defer alloc.free(x_str);

        try al.appendSlice(x_str);
    }

    try al.append(')');

    return al.toOwnedSlice();
}

pub fn deinit(self: *Nary) void {
    if (self.freed) {
        return;
    }

    self.mx.lock();
    for (self.xs) |x| {
        x.deinit();
    }
    self.freed = true;
    self.mx.unlock();
}

pub fn clone(self: *const Nary, alloc: Allocator) Allocator.Error!*Nary {
    const n = try alloc.create(Nary);
    errdefer alloc.destroy(n);

    var x_clones: [self.xs.len]Expr = undefined;

    for (self.xs, 0..) |x, i| {
        x_clones[i] = try x.clone();
        errdefer alloc.destroy(x_clones[i]);
    }

    n.* = .{ .op = self.op, .xs = x_clones };

    return n;
}
