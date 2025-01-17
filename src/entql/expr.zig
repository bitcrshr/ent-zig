const std = @import("std");
const Allocator = std.mem.Allocator;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const Expr = @import("./expr");

pub const UnaryExpr = struct {
    op: Op,
    x: Expr,

    pub fn toString(self: *UnaryExpr, alloc: Allocator) Allocator.Error![]u8 {
        const op_str = self.op.toString();
        const x_str = try self.x.toString(alloc);
        defer x_str.deinit();

        const buf = try alloc.alloc(u8, 2 + x_str.len + op_str.len);
        errdefer alloc.free(buf);

        std.fmt.bufPrint(buf, "{s}({s})", op_str, x_str) catch unreachable;

        return buf;
    }

    pub fn deinit(self: *UnaryExpr) void {
        self.x.deinit();
    }
};
