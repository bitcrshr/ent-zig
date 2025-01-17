const P = @import("./P.zig");
const Op = @import("./enums.zig").Op;

pub fn not(x: P) P {
    return P.UnaryExpr(Op.Not, x.toExpr());
}
