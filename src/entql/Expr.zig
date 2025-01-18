const std = @import("std");
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;

const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const P = @import("./P.zig");

const Unary = @import("./Unary.zig");
const Binary = @import("./Binary.zig");
const Nary = @import("./Nary.zig");
const Call = @import("./Call.zig");
const Field = @import("./Field.zig");
const Edge = @import("./Edge.zig");
const Value = @import("./Value.zig");

const Expr = @This();

const ExprImpl = union(enum) {
    P: P,
    Field: *Field,
    Edge: *Edge,
    Value: *Value,
};

expr: ExprImpl,
alloc: Allocator,

pub fn clone(self: Expr, alloc: Allocator) Allocator.Error!Expr {
    const impl: ExprImpl = switch (self.expr) {
        inline .P => |p| .{ .P = try p.clone(alloc) },
        inline .Field => |field| .{ .Field = try field.clone(alloc) },
        inline .Edge => |edge| .{ .Edge = try edge.clone(alloc) },
        inline .Value => |value| .{ .Value = try value.clone(alloc) },
    };

    return .{ .expr = impl, .alloc = alloc };
}

pub fn initField(alloc: Allocator, name: []const u8) Allocator.Error!Expr {
    const field = try alloc.create(Field);
    errdefer alloc.destroy(field);

    field.* = try Field.init(alloc, name);

    return .{
        .expr = .{ .Field = field },
        .alloc = alloc,
    };
}

pub fn initEdge(alloc: Allocator, name: []const u8) Allocator.Error!Expr {
    const edge = try alloc.create(Edge);
    errdefer alloc.destroy(edge);

    edge.* = try Edge.init(alloc, name);

    return .{
        .expr = .{ .Edge = edge },
        .alloc = alloc,
    };
}

pub fn initValue(alloc: Allocator, v: anytype) Allocator.Error!Expr {
    const value = try alloc.create(Value);
    errdefer alloc.destroy(value);

    value.* = try Value.init(alloc, v);

    return .{
        .expr = .{ .Value = value },
        .alloc = alloc,
    };
}

pub fn toString(self: Expr, alloc: Allocator) Allocator.Error![]u8 {
    return switch (self.expr) {
        inline .P => |p| p.toString(alloc),
        inline .Field => |field| field.toString(alloc),
        inline .Edge => |edge| edge.toString(alloc),
        inline .Value => |value| value.toString(alloc),
    };
}

pub fn deinit(self: Expr) void {
    switch (self.expr) {
        inline .P => |p| {
            var pm = p;
            pm.deinit();
        },

        inline .Field => |field| {
            var fm = field;
            fm.deinit();
            self.alloc.destroy(field);
        },

        inline .Edge => |edge| {
            var em = edge;
            em.deinit();
            self.alloc.destroy(edge);
        },

        inline .Value => |value| {
            var vm = value;
            vm.deinit();
            self.alloc.destroy(value);
        },
    }
}
