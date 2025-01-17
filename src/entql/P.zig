const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

/// Expr represents an entql expr.
pub const Expr = union(enum) {
    P: P,
    Field: *Field,
    Edge: *Edge,
    Value: *Value,

    // TODO! init fns should return Expr with heap-allocated values.
    // that means I'll have to refactor so that Expr itself can have
    // an allocator and a mutex. Same for P.
    //
    // Also! Should probably do an ARC for everything

    fn initP(p: P) Expr {
        return .{ .p = p };
    }

    fn initField(name: []const u8) Expr {
        return .{ .Field = &.{ .name = name } };
    }

    fn initEdge(name: []const u8) Expr {
        return .{ .Edge = &.{ .name = name } };
    }

    fn initValue(alloc: Allocator, x: anytype) Allocator.Error!Expr {
        return .{ .Value = try Value.init(alloc, x) };
    }

    pub fn toString(self: Expr, alloc: Allocator) Allocator.Error![]u8 {
        return switch (self) {
            inline .P => |p| p.toString(alloc),
            inline .Field => |field| field.toString(alloc),
            inline .Edge => |edge| edge.toString(alloc),
            inline .Value => |value| value.toString(alloc),
        };
    }

    pub fn deinit(self: Expr) void {
        switch (self) {
            inline .P => |p| p.deinit(),
            inline .Field => |field| field.deinit(),
            inline .Edge => |edge| edge.deinit(),
            inline .Value => |value| value.deinit(),
        }
    }
};

test "Expr" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eq = testing.expectEqualStrings;

    var field = Field{ .name = "bar" };
    var unary = Unary{ .op = Op.Not, .x = &Expr{ .Field = &field } };

    const p = P{ .Unary = &unary };
    const e = Expr{ .P = p };
    const e_str = try e.toString(alloc);
    defer alloc.free(e_str);

    try eq(e_str, "!(bar)");

    for (0..10) |_| {
        (try std.Thread.spawn(.{}, Expr.deinit, .{e})).detach();
    }
}

pub const P = union(enum) {
    Unary: *Unary,
    Binary: *Binary,
    Nary: *Nary,
    Call: *Call,

    pub fn initUnary(op: Op, x: *const Expr) P {
        return .{ .Unary = &.{ .op = op, .x = x } };
    }

    pub fn initBinary(op: Op, x: *const Expr, y: *const Expr) P {
        return .{ .Binary = &.{ .op = op, .x = x, .y = y } };
    }

    pub fn initNary(op: Op, xs: anytype) P {
        comptime {
            var exprs: [xs.len]*const Expr = undefined;

            for (xs, 0..) |x, i| {
                exprs[i] = x;
            }

            return .{ .Nary = &.{ .op = op, .xs = exprs } };
        }
    }

    pub fn initCall(func: Func, args: anytype) P {
        comptime {
            var exprs: [args.len]*const Expr = undefined;

            for (args, 0..) |x, i| {
                exprs[i] = x;
            }

            return .{ .Call = &.{ .func = func, .args = exprs } };
        }
    }

    pub fn toString(self: P, alloc: Allocator) Allocator.Error![]u8 {
        return switch (self) {
            inline .Unary => |unary| unary.toString(alloc),
            inline .Binary => |binary| binary.toString(alloc),
            inline .Nary => |nary| nary.toString(alloc),
            inline .Call => |call| call.toString(alloc),
        };
    }

    pub fn deinit(self: P) void {
        switch (self) {
            inline .Unary => |unary| unary.deinit(),
            inline .Binary => |binary| binary.deinit(),
            inline .Nary => |nary| nary.deinit(),
            inline .Call => |call| call.deinit(),
        }
    }
};

const Unary = struct {
    op: Op,
    x: *const Expr,
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
};

const Binary = struct {
    op: Op,
    x: *const Expr,
    y: *const Expr,
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
};

const Nary = struct {
    op: Op,
    xs: []const *const Expr,
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
};

const Call = struct {
    func: Func,
    args: []const *const Expr,
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
};

const Field = struct {
    name: []const u8,

    pub fn toString(self: *const Field, alloc: Allocator) Allocator.Error![]u8 {
        return alloc.dupe(u8, self.name);
    }

    pub fn deinit(self: *Field) void {
        _ = self;
    }
};

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

const Edge = struct {
    name: []const u8,

    pub fn toString(self: *const Edge, alloc: Allocator) Allocator.Error![]u8 {
        return alloc.dupe(u8, self.name);
    }

    pub fn deinit(self: *Edge) void {
        _ = self;
    }
};

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

const Value = struct {
    v: []const u8,
    alloc: Allocator,
    mx: Mutex = Mutex{},
    freed: bool = false,

    pub fn init(alloc: Allocator, x: anytype) Allocator.Error!Value {
        const x_str = try std.json.stringifyAlloc(alloc, x, .{});

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
};

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
