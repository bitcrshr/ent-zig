const std = @import("std");

const Foo = struct {
    mx: *std.Thread.Mutex,

    pub fn init() Foo {
        var mx = std.Thread.Mutex{};

        return Foo{ .mx = &mx };
    }

    pub fn badBehavior(self: *Foo) void {
        std.debug.print("Foo About to lock mutex on thread: {any}\n", .{std.Thread.getCurrentId()});
        self.mx.lock();

        var bar = Bar.init();
        @constCast(&bar).badBehavior();

        std.debug.print("Foo About to unlock mutex on thread: {any}, was orginally locked by: {any}\n", .{ std.Thread.getCurrentId(), self.mx.impl.locking_thread.load(.unordered) });
        self.mx.unlock();
    }
};

const Bar = struct {
    mx: *std.Thread.Mutex,

    pub fn init() Bar {
        var mx = std.Thread.Mutex{};

        return Bar{ .mx = &mx };
    }

    pub fn badBehavior(self: *Bar) void {
        std.debug.print("Bar About to lock mutex on thread: {any}\n", .{std.Thread.getCurrentId()});
        self.mx.lock();

        var baz = Baz.init();
        @constCast(&baz).badBehavior();

        std.debug.print("Bar About to unlock mutex on thread: {any}, was orginally locked by: {any}\n", .{ std.Thread.getCurrentId(), self.mx.impl.locking_thread.load(.unordered) });
        self.mx.unlock();
    }
};

const Baz = struct {
    mx: *std.Thread.Mutex,

    pub fn init() Baz {
        var mx = std.Thread.Mutex{};

        return Baz{ .mx = &mx };
    }

    pub fn badBehavior(self: *Baz) void {
        std.debug.print("Baz About to lock mutex on thread: {any}\n", .{std.Thread.getCurrentId()});
        self.mx.lock();

        std.debug.print("Baz About to unlock mutex on thread: {any}, was orginally locked by: {any}\n", .{ std.Thread.getCurrentId(), self.mx.impl.locking_thread.load(.unordered) });
        self.mx.unlock();
    }
};
test "foo" {
    var foo = Foo.init();

    foo.badBehavior();
}
