const std = @import("std");
const Type = std.builtin.Type;

// yay
pub fn getVarargs(comptime E: type, comptime args: anytype) [args.len]E {
    comptime {
        const argsType = @TypeOf(args);
        const argsTypeInfo = @typeInfo(argsType);

        switch (argsTypeInfo) {
            .Struct => |s| {
                if (!s.is_tuple) {
                    @compileError("Expected varargs to be a tuple.");
                }

                if (s.fields.len == 0) {
                    return [0]E{};
                }

                var varargs: [args.len]E = undefined;
                for (s.fields, 0..) |field, i| {
                    switch (@typeInfo(field.type)) {
                        @typeInfo(E) => {
                            varargs[i] = @field(args, field.name);
                        },

                        else => @compileError("Field type mismatch. Expected " ++ @typeName(E) ++ " but got " ++ @typeName(field.type)),
                    }
                }
                return varargs;
            },
            else => |other| @compileError("Expected a tuple type but got " ++ @typeName(@Type(other)) ++ " instead."),
        }
    }
}

test "getVarargs" {
    const a = comptime getVarargs([]const u8, .{ "foo", "bar", "baz" });

    try std.testing.expectEqual(a, [_][]const u8{ "foo", "bar", "baz" });

    const ints = .{ @as(i32, 1), @as(i32, 2), @as(i32, 3) };
    const b = comptime getVarargs(i32, ints);

    try std.testing.expectEqual(b, [_]i32{ 1, 2, 3 });

    const c = comptime getVarargs(bool, .{});

    try std.testing.expectEqual(c, [_]bool{});

    const testStruct = struct {
        name: []const u8,
    };

    const testStructs = .{ testStruct{ .name = "one" }, testStruct{ .name = "two" } };

    const d = comptime getVarargs(testStruct, .{ testStruct{ .name = "one" }, testStruct{ .name = "two" } });

    try std.testing.expectEqual(d, testStructs);

    const testStructPtrs = .{ &testStruct{ .name = "one" }, &testStruct{ .name = "two" } };
    const e = comptime getVarargs(*const testStruct, testStructPtrs);

    try std.testing.expectEqual(e, testStructPtrs);

    const testStructOpts: struct { ?testStruct, ?testStruct, ?testStruct } = .{ testStruct{ .name = "one" }, testStruct{ .name = "two" }, null };

    const f = comptime getVarargs(?testStruct, testStructOpts);

    try std.testing.expectEqual(f, testStructOpts);

    const testStructOptPtrs: struct { ?*testStruct, ?*testStruct, ?*testStruct } = .{ @constCast(&testStruct{ .name = "one" }), @constCast(&testStruct{ .name = "two" }), null };

    const g = comptime getVarargs(?*testStruct, testStructOptPtrs);

    try std.testing.expectEqual(g, testStructOptPtrs);
}
