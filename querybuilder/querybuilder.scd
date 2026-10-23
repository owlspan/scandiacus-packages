// querybuilder - building SQL without pasting values into it.
//
//     import "querybuilder"
//     import "sqlite"
//
//     let q = qbFrom("notes")
//     q.pick(["id", "body"])
//     q.where("tag = ?", "urgent")
//     q.where("id > ?", "10")
//     q.order("id desc")
//     q.limit(20)
//
//     must(q.check())
//     for row in must(db.query(conn, q.sql(), q.params())) { ... }
//
// The whole point is that values never touch the SQL string. Every
// `where` takes its value separately and the condition holds a `?`, so
// `sql()` comes back with placeholders and `params()` with the values,
// in the order the placeholders expect.
//
// Identifiers - table and column names - cannot be placeholders in any
// SQL database, so those are checked to be plain names and refused if
// they are not. That is the one place a builder can go wrong, and it is
// checked rather than trusted.
//
// **These are methods, not functions.** A struct handed to a plain
// function is copied, so `qbWhere(q, ...)` would build up a query the
// caller never sees. A method's receiver is passed by reference, which
// is what makes a builder work at all.

struct Query {
    table: str
    cols: []str
    conds: []str
    vals: []str
    orderBy: str
    limitN: int
    offsetN: int
    problem: str
}

pub fn qbFrom(table: str) -> Query {
    let q = Query{table: table, limitN: -1, offsetN: -1}
    if !qbSafeName(table) {
        q.problem = "\"{table}\" is not a valid table name"
    }
    return q
}

// Letters, digits and underscore, not starting with a digit.
pub fn qbSafeName(name: str) -> bool {
    if name == "" { return false }
    let first = __strAt(name, 0)
    let ok = (first >= 65 && first <= 90) || (first >= 97 && first <= 122)
    if !ok && first != 95 { return false }

    let i = 0
    while i < len(name) {
        let c = __strAt(name, i)
        let good = (c >= 65 && c <= 90) || (c >= 97 && c <= 122)
        good = good || (c >= 48 && c <= 57) || c == 95
        if !good { return false }
        i = i + 1
    }
    return true
}

impl Query {
    // Which columns to read. Without this it is `select *`.
    fn pick(self, cols: []str) {
        for c in cols {
            if !qbSafeName(c) {
                self.note("\"{c}\" is not a valid column name")
                return
            }
        }
        self.cols = cols
    }

    // A condition and the one value it compares against. The condition
    // holds the `?`; the value never appears in the SQL. Several are
    // joined with `and`.
    fn where(self, condition: str, value: str) {
        push(self.conds, condition)
        push(self.vals, value)
    }

    // A condition with no value, for `x is null` and the like.
    fn whereRaw(self, condition: str) {
        push(self.conds, condition)
    }

    // A condition over several values, for `in (?, ?, ?)`.
    fn whereIn(self, column: str, values: []str) {
        if !qbSafeName(column) {
            self.note("\"{column}\" is not a valid column name")
            return
        }
        if len(values) == 0 {
            // `in ()` is a syntax error in most databases, and the
            // honest meaning of an empty set is a condition nothing
            // satisfies.
            push(self.conds, "1 = 0")
            return
        }
        let marks: []str = []
        for v in values {
            push(marks, "?")
            push(self.vals, v)
        }
        push(self.conds, "{column} in ({join(marks, ", ")})")
    }

    // `order by`. The column is checked; the direction is asc or desc.
    fn order(self, spec: str) {
        let parts = split(trim(spec), " ")
        if len(parts) == 0 || !qbSafeName(parts[0]) {
            self.note("\"{spec}\" is not a valid order")
            return
        }
        let dir = ""
        if len(parts) > 1 {
            let d = lower(parts[1])
            if d != "asc" && d != "desc" {
                self.note("order direction must be asc or desc, got \"{parts[1]}\"")
                return
            }
            dir = " " + d
        }
        self.orderBy = parts[0] + dir
    }

    fn limit(self, n: int) {
        self.limitN = n
    }

    fn offset(self, n: int) {
        self.offsetN = n
    }

    // Keep the first problem. The later ones are usually consequences.
    fn note(self, problem: str) {
        if self.problem == "" {
            self.problem = problem
        }
    }

    // The SQL, with a placeholder everywhere a value goes.
    fn sql(self) -> str {
        let cols = "*"
        if len(self.cols) > 0 {
            cols = join(self.cols, ", ")
        }
        let out = "select {cols} from {self.table}"
        if len(self.conds) > 0 {
            out = out + " where " + join(self.conds, " and ")
        }
        if self.orderBy != "" {
            out = out + " order by " + self.orderBy
        }
        if self.limitN >= 0 {
            out = out + " limit {self.limitN}"
        }
        if self.offsetN >= 0 {
            out = out + " offset {self.offsetN}"
        }
        return out
    }

    // The values, in the order the placeholders expect them.
    fn params(self) -> []str {
        return self.vals
    }

    // Whether anything was rejected while building.
    fn ok(self) -> bool {
        return self.problem == ""
    }

    // The same as a failure, so it can be used with ?.
    fn check(self) -> void! {
        if self.problem != "" {
            return fail(self.problem)
        }
    }
}

// ---- writing ----
//
// These are plain functions because nothing is being built up: each one
// takes everything it needs and hands back a statement.

pub fn qbInsert(table: str, cols: []str, values: []str) -> str! {
    if !qbSafeName(table) {
        return fail("\"{table}\" is not a valid table name")
    }
    if len(cols) != len(values) {
        return fail("{len(cols)} column(s) but {len(values)} value(s)")
    }
    if len(cols) == 0 {
        return fail("an insert needs at least one column")
    }
    let marks: []str = []
    for c in cols {
        if !qbSafeName(c) {
            return fail("\"{c}\" is not a valid column name")
        }
        push(marks, "?")
    }
    return "insert into {table} ({join(cols, ", ")}) values ({join(marks, ", ")})"
}

// The condition is the caller's, so this cannot build an update that
// touches every row by accident: a missing one is refused.
pub fn qbUpdate(table: str, cols: []str, condition: str) -> str! {
    if !qbSafeName(table) {
        return fail("\"{table}\" is not a valid table name")
    }
    if len(cols) == 0 {
        return fail("an update needs at least one column")
    }
    if trim(condition) == "" {
        return fail("refusing to build an update with no condition - pass \"1 = 1\" if you meant every row")
    }
    let sets: []str = []
    for c in cols {
        if !qbSafeName(c) {
            return fail("\"{c}\" is not a valid column name")
        }
        push(sets, "{c} = ?")
    }
    return "update {table} set {join(sets, ", ")} where {condition}"
}

pub fn qbDelete(table: str, condition: str) -> str! {
    if !qbSafeName(table) {
        return fail("\"{table}\" is not a valid table name")
    }
    if trim(condition) == "" {
        return fail("refusing to build a delete with no condition - pass \"1 = 1\" if you meant every row")
    }
    return "delete from {table} where {condition}"
}
