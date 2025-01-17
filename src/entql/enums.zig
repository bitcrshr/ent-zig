/// An Op represents a predicate operator.
pub const Op = enum {
    And,
    Or,
    Not,
    Eq,
    Neq,
    Gt,
    Gte,
    Lt,
    Lte,
    In,
    NotIn,

    pub fn toString(self: Op) []const u8 {
        return switch (self) {
            .And => "&&",
            .Or => "||",
            .Not => "!",
            .Eq => "==",
            .Neq => "!=",
            .Gt => ">",
            .Gte => ">=",
            .Lt => "<",
            .Lte => "<=",
            .In => "in",
            .NotIn => "not in",
        };
    }
};

/// A Func represents a function expression.
pub const Func = enum {
    EqualFold,
    Contains,
    ContainsFold,
    HasPrefix,
    HasSuffix,
    HasEdge,

    pub fn toString(self: Func) []const u8 {
        return switch (self) {
            .EqualFold => "equal_fold",
            .Contains => "contains",
            .ContainsFold => "contains_fold",
            .HasPrefix => "has_prefix",
            .HasSuffix => "has_suffix",
            .HasEdge => "has_edge",
        };
    }
};
