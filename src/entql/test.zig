const std = @import("std");
const testing = std.testing;
const t_allocator = testing.allocator;
const eqStr = testing.expectEqualStrings;

const EntAllocator = @import("util").EntAllocator;

const Expr = @import("./Expr.zig");
const Predicate = @import("./Predicate.zig");
const Field = @import("./Field.zig");
const Edge = @import("./Edge.zig");

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field1 = Field.init(alloc, "name");
    const field2 = Field.init(alloc, "org");

    const p = field1.eq("a8m").@"and"(field2.in(.{ "fb", "ent" }));
    defer p.deinit();

    const expected =
        \\name == "a8m" && org in ["fb","ent"]
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field1 = Field.init(alloc, "name");
    const field2 = Field.init(alloc, "org");

    const p = field1.eq("mashraki")
        .negate()
        .@"or"(
        field2.in(
            .{ "fb", "ent" },
        ),
    );
    defer p.deinit();

    const expected =
        \\!(name == "mashraki") || org in ["fb","ent"]
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});
    const edge1 = Edge.init(alloc, "groups");
    const edge2 = Edge.init(alloc, "admins");
    const field = Field.init(alloc, "name");

    const p = edge1.existsWith(.{
        edge2.existsWith(
            .{field.eq("a8m").negate()},
        ),
    });
    defer p.deinit();

    const expected =
        \\has_edge(groups, has_edge(admins, !(name == "a8m")))
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field1 = Field.init(alloc, "age");
    const field2 = Field.init(alloc, "workplace");

    const p = field1.gt(30).@"and"(
        field2.contains("fb"),
    );
    defer p.deinit();

    const expected =
        \\age > 30 && contains(workplace, "fb")
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field = Field.init(alloc, "score");

    const p = field.lt(32.23).negate();
    defer p.deinit();

    const expected =
        \\!(score < 3.223e1)
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field1 = Field.init(alloc, "active");
    const field2 = Field.init(alloc, "name");

    const p = field1.isNull().@"and"(field2.isNotNull());
    defer p.deinit();

    const expected =
        \\active == null && name != null
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}

test {
    const alloc = EntAllocator.init(t_allocator, .{});

    const field1 = Field.init(alloc, "id");
    const field2 = Field.init(alloc, "name");

    const p = field1.notIn(.{ 1, 2, 3 }).@"or"(field2.hasSuffix("admin"));
    defer p.deinit();

    const expected =
        \\id not in [1,2,3] || has_suffix(name, "admin")
    ;
    const got = try p.toString(t_allocator);
    defer t_allocator.free(got);

    try eqStr(expected, got);
}
