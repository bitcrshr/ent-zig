pub const Unary = @import("./Unary.zig");
pub const Binary = @import("./Binary.zig");
pub const Nary = @import("./Nary.zig");
pub const Call = @import("./Call.zig");
pub const Field = @import("./Field.zig");
pub const Edge = @import("./Edge.zig");
pub const Value = @import("./Value.zig");
pub const Expr = @import("./Expr.zig");
pub const P = @import("./P.zig");

const enums = @import("./enums.zig");

pub const Op = enums.Op;
pub const Func = enums.Func;

pub const Preds = @import("./Preds.zig");

test "entql predicates" {
    const std = @import("std");
    const testing = std.testing;
    const eqStr = testing.expectEqualStrings;

    testing.refAllDecls(@This());

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    var pr = try Preds.init(testing.allocator);
    defer pr.deinit();

    var p = try pr.@"and"(
        try pr.fieldEq("name", "a8m"),
        try pr.fieldIn("org", .{ "fb", "ent" }),
        .{},
    );

    try eqStr(
        try p.toString(alloc),
        \\name == "a8m" && org in ["fb","ent"]
        ,
    );

    p = try pr.@"or"(
        try pr.not(try pr.fieldEq("name", "mashraki")),
        try pr.fieldIn("org", .{ "fb", "ent" }),
        .{},
    );

    try eqStr(
        \\!(name == "mashraki") || org in ["fb","ent"]
    ,
        try p.toString(alloc),
    );

    p = try pr.hasEdgeWith(
        "groups",
        .{
            try pr.hasEdgeWith(
                "admins",
                .{
                    try pr.not(try pr.fieldEq("name", "a8m")),
                },
            ),
        },
    );

    try eqStr(
        \\has_edge(groups, has_edge(admins, !(name == "a8m")))
    ,
        try p.toString(alloc),
    );

    p = try pr.@"and"(
        try pr.fieldGt("age", 30),
        try pr.fieldContains("workplace", "fb"),
        .{},
    );

    try eqStr(
        \\age > 30 && contains(workplace, "fb")
    ,
        try p.toString(alloc),
    );

    p = try pr.not(try pr.fieldLt("score", 32.23));

    try eqStr(
        \\!(score < 3.223e1)
    ,
        try p.toString(alloc),
    );

    p = try pr.@"and"(
        try pr.fieldNull("active"),
        try pr.fieldNotNull("name"),
        .{},
    );

    try eqStr(
        \\active == null && name != null
    ,
        try p.toString(alloc),
    );

    p = try pr.@"or"(
        try pr.fieldNotIn("id", .{ 1, 2, 3 }),
        try pr.fieldHasSuffix("name", "admin"),
        .{},
    );

    try eqStr(
        \\id not in [1,2,3] || has_suffix(name, "admin")
    ,
        try p.toString(alloc),
    );

    p = try (try pr.eq(
        try Expr.initField(alloc, "current"),
        try Expr.initField(alloc, "total"),
    )).negate(alloc);

    try eqStr(
        \\!(current == total)
    ,
        try p.toString(alloc),
    );
}
