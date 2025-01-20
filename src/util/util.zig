pub const EntAllocator = @import("./EntAllocator.zig");
pub const mem = @import("./mem/mem.zig");

// pub fn CustomStruct(comptime fields: []std.builtin.Type.StructField) type {
//     return @Type(.{ .Struct = .{
//         .layout = std.builtin.Type.ContainerLayout.auto,
//         .fields = fields[0..],
//         .decls = &[_]std.builtin.Type.Declaration{},
//         .is_tuple = false,
//     } });
// }

// test "customStruct" {
//     const fields = [_]std.builtin.Type.StructField{.{
//         .name = "foo",
//         .type = i32,
//         .is_comptime = false,
//         .default_value = null,
//         .alignment = 0,
//     }};

//     const t = CustomStruct(@constCast(&fields));

//     const foo = t{ .foo = 2 };

// }
