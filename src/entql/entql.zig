const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const enums = @import("./enums.zig");
const Op = enums.Op;
const Func = enums.Func;

const expr = @import("./expr.zig");
const UnaryExpr = expr.UnaryExpr;
const BinaryExpr = expr.BinaryExpr;
const NaryExpr = expr.NaryExpr;
const CallExpr = expr.CallExpr;
const Field = expr.Field;
const Edge = expr.Edge;
const Value = expr.Value;

const Expr = expr.Expr;
const P = expr.P;

pub fn not(x: P) P {
    return P{
        .UnaryExpr = &UnaryExpr{
            .op = Op.Not,
            .x = x.asExpr(),
        },
    };
}

pub fn @"and"(x: P, y: P, comptime zs: anytype, alloc: Allocator) anyerror!P {
    if (zs.len == 0) {
        return P{
            .BinaryExpr = &BinaryExpr{
                .op = Op.And,
                .x = x.asExpr(),
                .y = y.asExpr(),
            },
        };
    }

    var zsP: [zs.len]P = undefined;

    comptime {
        const T = @TypeOf(zs);
        const type_info = @typeInfo(T);

        if (type_info != .Struct or !type_info.Struct.is_tuple) {
            @compileError("Expected a tuple, found " ++ @typeName(T));
        }

        for (type_info.Struct.fields) |field| {
            if (field.type != P) {
                @compileError("expected all values in tuple to be of type P, but found a value of type " ++ @typeName(f.type));
            }
        }

        for (zs, 0..) |z, i| {
            zsP[i] = z;
        }
    }

    var xs = try alloc.alloc(Expr, zsP.len + 2);
    xs[0] = x;
    xs[1] = y;

    for (zsP, 0..) |z, i| {
        xs[i] = z.asExpr();
    }

    return P{
        .NaryExpr = &NaryExpr{
            .op = Op.And,
            .xs = xs,
            .alloc = alloc,
        },
    };
}

pub fn @"or"(x: P, y: P, comptime zs: anytype, alloc: Allocator) anyerror!P {
    var zsP: [zs.len]P = undefined;

    comptime {
        if (zs.len == 0) {
            return P{
                .BinaryExpr = &BinaryExpr{
                    .op = Op.Or,
                    .x = x.asExpr(),
                    .y = y.asExpr(),
                },
            };
        }

        const T = @TypeOf(zs);
        const type_info = @typeInfo(T);

        if (type_info != .Struct or !type_info.Struct.is_tuple) {
            @compileError("Expected a tuple, found " ++ @typeName(T));
        }

        for (type_info.Struct.fields) |field| {
            if (field.type != P) {
                @compileError("expected all values in tuple to be of type P, but found a value of type " ++ @typeName(f.type));
            }
        }

        for (zs, 0..) |z, i| {
            zsP[i] = z;
        }
    }

    var xs = try alloc.alloc(Expr, zsP.len + 2);
    xs[0] = x;
    xs[1] = y;

    for (zsP, 0..) |z, i| {
        xs[i] = z.asExpr();
    }

    return P{
        .NaryExpr = &NaryExpr{
            .op = Op.Or,
            .xs = xs,
            .alloc = alloc,
        },
    };
}

pub fn f(name: []const u8) Field {
    return Field{ .name = name };
}

test "f" {
    const testing = std.testing;
    const eqVals = testing.expectEqual;

    try eqVals(
        f("foo"),
        Field{ .name = "foo" },
    );
}

pub fn eq(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Eq,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldEq(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Eq,
            .x = Expr{ .Field = Field{ .name = name } },
            .y = Expr{ .Value = try Value.of(v, alloc) },
        },
    };
}

pub fn neq(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Neq,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldNeq(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Neq,
            .x = Field{ .name = name },
            .y = try Value.of(v, alloc),
        },
    };
}

pub fn gt(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Gt,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldGt(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Gt,
            .x = Field{ .name = name },
            .y = try Value.of(v, alloc),
        },
    };
}

pub fn gte(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Gte,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldGte(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Gte,
            .x = Field{ .name = name },
            .y = try Value.of(v, alloc),
        },
    };
}

pub fn lt(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Lt,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldLt(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Lt,
            .x = Field{ .name = name },
            .y = try Value.of(v, alloc),
        },
    };
}
pub fn lte(x: Expr, y: Expr) P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Lte,
            .x = x,
            .y = y,
        },
    };
}

pub fn fieldLte(name: []const u8, v: anytype, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Lte,
            .x = Field{ .name = name },
            .y = try Value.of(v, alloc),
        },
    };
}

pub fn fieldContains(name: []const u8, substr: []const u8, alloc: Allocator) anyerror!P {
    const args = [_]Expr{ Field{ .name = name }, try Value.of(substr, alloc) };

    return P{
        .CallExpr = &CallExpr{
            .func = Func.Contains,
            .args = args[0..],
        },
    };
}

pub fn fieldContainsFold(name: []const u8, substr: []const u8, alloc: Allocator) anyerror!P {
    const args = [_]Expr{ Field{ .name = name }, try Value.of(substr, alloc) };

    return P{
        .CallExpr = &CallExpr{
            .func = Func.ContainsFold,
            .args = args[0..],
        },
    };
}

pub fn fieldEqualFold(name: []const u8, v: []const u8, alloc: Allocator) anyerror!P {
    const args = [_]Expr{ Field{ .name = name }, try Value.of(v, alloc) };

    return P{
        .CallExpr = &CallExpr{
            .func = Func.EqualFold,
            .args = args[0..],
        },
    };
}

pub fn fieldHasPrefix(name: []const u8, prefix: []const u8, alloc: Allocator) anyerror!P {
    const args = [_]Expr{ Field{ .name = name }, try Value.of(prefix, alloc) };

    return P{
        .CallExpr = &CallExpr{
            .func = Func.HasPrefix,
            .args = args[0..],
        },
    };
}

pub fn fieldHasSuffix(name: []const u8, suffix: []const u8, alloc: Allocator) anyerror!P {
    const args = [_]Expr{ Field{ .name = name }, try Value.of(suffix, alloc) };

    return P{
        .CallExpr = &CallExpr{
            .func = Func.HasSuffix,
            .args = args[0..],
        },
    };
}

pub fn fieldIn(name: []const u8, comptime vs: anytype, alloc: Allocator) anyerror!P {
    comptime {
        const T = @TypeOf(vs);
        const type_info = @typeInfo(T);

        if (type_info != .Struct or !type_info.Struct.is_tuple) {
            @compileError("vs must be a tuple");
        }
    }

    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.In,
            .x = Expr{ .Field = Field{ .name = name } },
            .y = Expr{ .Value = try Value.of(vs, alloc) },
        },
    };
}

pub fn fieldNotIn(name: []const u8, comptime vs: anytype, alloc: Allocator) anyerror!P {
    comptime {
        const T = @TypeOf(vs);
        const type_info = @typeInfo(T);

        if (type_info != .Struct or !type_info.Struct.is_tuple) {
            @compileError("vs must be a tuple");
        }
    }

    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.NotIn,
            .x = Field{ .name = name },
            .v = try Value.of(vs, alloc),
        },
    };
}

pub fn fieldNull(name: []const u8, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Eq,
            .x = Field{ .name = name },
            .y = try Value.of(null, alloc),
        },
    };
}

pub fn fieldNotNull(name: []const u8, alloc: Allocator) anyerror!P {
    return P{
        .BinaryExpr = &BinaryExpr{
            .op = Op.Neq,
            .x = Field{ .name = name },
            .y = try Value.of(null, alloc),
        },
    };
}

pub fn hasEdge(name: []const u8) P {
    const args = [_]Expr{Expr{ .Edge = Edge{ .name = name } }};
    return P{
        .CallExpr = &CallExpr{
            .func = Func.HasEdge,
            .args = args[0..],
        },
    };
}

pub fn hasEdgeWith(name: []const u8, ps: []P, alloc: Allocator) anyerror!P {
    const exprs = [_][]Expr{[_]Expr{ Expr{ .Edge = Edge{ .name = name } }, try p2Expr(ps, alloc) }};

    const args = try std.mem.concat(alloc, Expr, exprs);

    return P{
        .CallExpr = &CallExpr{
            .func = Func.HasEdge,
            .args = args,
        },
    };
}

fn p2Expr(ps: []P, alloc: Allocator) anyerror![]Expr {
    const list = std.ArrayList(Expr).init(alloc);
    errdefer list.deinit();

    for (ps) |p| {
        try list.append(p);
    }

    return list.toOwnedSlice();
}

test "and_fieldEq_fieldIn" {
    const testing = std.testing;
    const alloc = testing.allocator;
    const eqStrs = testing.expectEqualStrings;

    const a = try fieldEq("name", "a8m", alloc);
    const b = try fieldIn("org", .{ "fb", "ent" }, alloc);
    const p = try @"and"(
        a,
        b,
        .{},
        alloc,
    );
    defer p.deinit();

    const p_str = try p.toString(alloc);
    defer alloc.free(p_str);

    try eqStrs(
        \\name == "a8m" && org in ["fb","ent"]
    ,
        p_str,
    );
}
