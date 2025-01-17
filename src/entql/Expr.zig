const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Mutex = std.Thread.Mutex;
const UnaryExpr = @import("./expr.zig");

const Expr = @This();

inner: ?*Inner,
alloc: Allocator,
mx: Mutex = Mutex{},

pub fn init(alloc: Allocator, x: anytype) !Expr {
    const inner_ptr = try alloc.create(Inner);
    errdefer alloc.destroy(inner_ptr);
    const inner = try Inner.init(alloc, x);
    inner_ptr.* = inner;

    return .{
        .inner = inner_ptr,
        .alloc = alloc,
    };
}

pub fn deinit(self: *Expr) void {
    self.mx.lock();
    defer self.mx.unlock();

    if (self.inner == null) {
        return;
    }

    self.inner.?.deinit();
    self.alloc.destroy(self.inner.?);
    self.inner = null;
}

pub fn toString(self: *const Expr, alloc: Allocator) Allocator.Error![]u8 {
    if (self.inner == null) {
        @panic("Expr.toString called after Expr was deinitialized.");
    }

    return self.inner.?.toString(alloc);
}

pub fn negate(self: *const Expr, alloc: Allocator) Allocator.Error!*UnaryExpr {
    if (self.inner == null) {
        @panic("Expr.negate was called after it was deinitialized.");
    }

    return self.inner.?.negate(alloc);
}

const Inner = struct {
    alloc: Allocator,

    ptr: *anyopaque,
    toStringImpl: *const fn (*anyopaque, Allocator) Allocator.Error![]u8,
    deinitImpl: *const fn (*anyopaque) void,
    negateImpl: ?*const fn (*anyopaque, Allocator) Allocator.Error!*UnaryExpr = null,

    pub fn init(allocator: Allocator, x: anytype) Allocator.Error!Inner {
        const T = @TypeOf(x);
        const ti = @typeInfo(T);

        if (ti != .Pointer) {
            @compileError("x must be a pointer.");
        }

        const ChildT = ti.Pointer.child;

        checkRequiredMethodImpls(ChildT);

        const GenericImpl = struct {
            fn toString(pointer: *anyopaque, a: Allocator) Allocator.Error![]u8 {
                const self: T = @ptrCast(@alignCast(pointer));
                return ChildT.toString(self, a);
            }

            fn deinit(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ChildT.deinit(self);
            }
        };

        var expr = .{
            .ptr = x,
            .toStringImpl = GenericImpl.toString,
            .deinitImpl = GenericImpl.deinit,
            .alloc = allocator,
        };

        if (hasOptionalNegateMethod(T)) {
            const GenericNegateImpl = struct {
                fn negate(pointer: *anyopaque, a: Allocator) Allocator.Error!*UnaryExpr {
                    const self: T = @ptrCast(@alignCast(pointer));
                    return ChildT.negate(self, a);
                }
            };

            expr.negateImpl = GenericNegateImpl.negate;
        }

        return expr;
    }

    pub fn toString(self: *Inner, a: Allocator) Allocator.Error![]u8 {
        return self.toStringImpl(self.ptr, a);
    }

    pub fn deinit(self: *Inner) void {
        self.deinitImpl(self.ptr);
    }

    pub fn negate(self: *Inner, a: Allocator) Allocator.Error!*UnaryExpr {
        if (self.negateImpl == null) {
            @compileError("Called negate on an Expr that isn't negateable.");
        }

        self.negateImpl.?(self.ptr, a);
    }
};

inline fn hasOptionalNegateMethod(comptime T: type) bool {
    if (!std.meta.hasMethod(T, "negate")) {
        return false;
    }

    const negateMethod = T.negate;
    const NegateMethodType = @TypeOf(negateMethod);
    const negate_ti = @typeInfo(NegateMethodType);

    assert(negate_ti == .Fn);

    const negate_args = negate_ti.Fn.params;
    if (negate_args.len != 2) {
        return false;
    }

    if (negate_args[0].type == null or negate_args[0].type.? != *T) {
        return false;
    }

    if (negate_args[1].type == null or negate_args[1].type.? != Allocator) {
        return false;
    }

    if (negate_ti.Fn.return_type == null or negate_ti.Fn.return_type.? != Allocator.Error!*UnaryExpr) {
        return false;
    }

    return true;
}

fn checkRequiredMethodImpls(comptime T: type) void {
    if (!std.meta.hasMethod(T, "toString")) {
        @compileError(@typeName(T) ++ " must implement a toString method with signature: fn (*Self, Allocator) std.Allocator.Error![]u8");
    }

    //
    // toString check
    //

    const toStringMethod = T.toString;
    const ToStringType = @TypeOf(toStringMethod);
    const to_string_ti = @typeInfo(ToStringType);

    assert(to_string_ti == .Fn);

    const to_string_args = to_string_ti.Fn.params;
    if (to_string_args.len != 2) {
        @compileError(@typeName(T) ++ "'s toString method must have signature: fn (*Self, Allocator) std.Allocator.Error![]u8\n\nFound " ++ @typeName(T.toString));
    }

    if (to_string_args[0].type != *T) {
        @compileError(@typeName(T) ++ "'s toString method must have signature: fn (*Self, Allocator) std.Allocator.Error![]u8\n\nFound " ++ @typeName(T.toString));
    }

    if (to_string_args[1].type != Allocator) {
        @compileError(@typeName(T) ++ "'s toString method must have signature: fn (*Self, Allocator) std.Allocator.Error![]u8\n\nFound " ++ @typeName(T.toString));
    }

    if (to_string_ti.Fn.return_type == null or to_string_ti.Fn.return_type != Allocator.Error![]u8) {
        @compileError(@typeName(T) ++ "'s toString method must have signature: fn (*Self, Allocator) std.Allocator.OutOfMemory![]u8\n\nFound " ++ @typeName(T.toString));
    }

    //
    // deinit check
    //

    if (!std.meta.hasMethod(T, "deinit")) {
        @compileError(@typeName(T) ++ " must implement a deinit method with signature: fn(*Self) void");
    }

    const deinitMethod = T.deinit;
    const DeinitType = @TypeOf(deinitMethod);
    const deinit_ti = @typeInfo(DeinitType);

    assert(deinit_ti == .Fn);

    const deinit_args = deinit_ti.Fn.params;
    if (deinit_args.len != 1) {
        @compileError(@typeName(T) ++ "'s deinit method must have signature: fn (*Self) void\n\nFound " ++ @typeName(T.deinit));
    }

    if (deinit_args[0].type != *T) {
        @compileError(@typeName(T) ++ "'s deinit method must have signature: fn (*Self) void\n\nFound " ++ @typeName(T.deinit));
    }
}

test "Expr" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eq = testing.expectEqualStrings;

    const Foo = struct {
        s: []const u8,

        const Self = @This();
        pub fn toString(self: *Self, all: Allocator) Allocator.Error![]u8 {
            const s_copy = try all.dupe(u8, self.s);

            return s_copy;
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }
    };

    var foo = Foo{ .s = "yoink" };

    var x = try init(alloc, &foo);
    const xp = &x;

    for (0..10) |_| {
        var thread = try std.Thread.spawn(.{}, deinit, .{xp});
        thread.detach();
    }

    var bar = Foo{ .s = "yeet" };
    const y = try alloc.create(Expr);
    defer alloc.destroy(y);
    y.* = try init(alloc, &bar);
    errdefer y.deinit();

    const expected = "yeet";
    const got = try y.toString(alloc);
    defer alloc.free(got);

    try eq(expected, got);

    for (0..10) |_| {
        var thread = try std.Thread.spawn(.{}, deinit, .{y});
        thread.detach();
    }

    var baz = Foo{ .s = "meep" };
    var z = try init(alloc, &baz);
    for (0..100) |_| {
        z.deinit();
    }

    var boo = Foo{ .s = "zorp" };
    var zz = try init(alloc, &boo);
    defer zz.deinit();

    _ = try zz.negate(alloc);
}
