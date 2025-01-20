const std = @import("std");

pub fn Rc(comptime T: type) type {
    return struct {
        strong_count: usize = 0,
        weak_count: usize = 0,

        /// The underlying data should only be freed once *both* `strong_count` and
        /// `weak_count` reach 0.
        data: ?*T,
        alloc: std.mem.Allocator,

        pub fn init(data: T, alloc: std.mem.Allocator) std.mem.Allocator.Error!*Rc(T) {
            const ptr = try alloc.create(T);
            errdefer alloc.destroy(ptr);
            ptr.* = data;

            const self = try alloc.create(Rc(T));
            self.* = .{ .data = ptr, .alloc = alloc };

            return self;
        }

        pub fn deinit(self: *Rc(T)) void {
            self.strong_count = 0;
            self.weak_count = 0;

            self.dec();

            self.alloc.destroy(self);
        }

        /// Increments `strong_count`
        pub fn inc(self: *Rc(T)) void {
            self.strong_count += 1;
        }

        /// Decrements `strong_count`, freeing the underlying data
        /// if both `strong_count` and `weak_count` are now zero.
        pub fn dec(self: *Rc(T)) void {
            if (self.strong_count > 0) {
                self.strong_count -= 1;
            }

            if (self.strong_count == 0 and self.weak_count == 0) {
                self.alloc.destroy(self.data);
                self.data = null;
            }
        }

        /// Increments `weak_count` and returns a `Weak(T)`
        pub fn weak(self: *Rc(T)) Weak(T) {
            self.weak_count += 1;

            return Weak(T).init(self);
        }
    };
}

/// Weak references allow access to the underlying pointer without assuming ownership of it.
/// Obtaining a weak reference does not increase the reference count.
pub fn Weak(comptime T: type) type {
    return struct {
        rc: ?*Rc(T),

        pub fn init(rc: *Rc(T)) Weak(T) {
            return Weak(T){ .rc = rc };
        }

        /// Attempts to upgrade this `Weak(T)` into a `Rc(T)`. If the underlying `Rc(T)`
        pub fn upgrade(self: *Weak(T)) ?*Rc(T) {
            if (self.rc != null and self.rc.?.strong_count > 0) {
                self.rc.?.strong_count += 1;

                return self.rc.?;
            }

            return null;
        }

        /// Decrements the underlying `Rc(T)`'s `weak_count`. If the underlying `Rc(T)`'s
        /// `strong_count` and `weak_count` are both 0, `Rc(T)`'s data will be freed.
        pub fn dec(self: *Weak(T)) void {
            if (self.rc) |rc| {
                if (rc.weak_count > 0) {
                    rc.weak_count -= 1;
                }

                if (rc.strong_count == 0 and rc.weak_count == 0) {
                    rc.alloc.destroy(rc.data);
                    self.rc = null;
                }
            }
        }
    };
}
