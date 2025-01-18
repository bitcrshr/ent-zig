pub const entql = @import("./entql/entql.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
