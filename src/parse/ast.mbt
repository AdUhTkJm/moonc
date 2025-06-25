pub(all) enum BinaryKind {
  Add
  Sub
  Mul
  Div
  Mod
  Lt
  Le
  Eq
  Ne
  Assign
  And
  Or
  Bitand
  Bitor
  Xor
  Lsh
  Rsh
} derive(Eq, Hash)

pub(all) enum UnaryKind {
  Not
  Minus
  Try
  Expand
  Raise
} derive(Eq, Hash)

pub(all) enum Visible {
  Priv
  Pub
  Pubopen
  Puball
} derive(Eq, Hash)

pub(all) struct Name {
  pack: String?
  ns: String?
  name: String
} derive(Eq, Hash)

pub(all) struct Attribute {
  name: String
  args: Array[String]
  kwargs: Map[String, String]
}

pub(all) enum Pattern {
  IncRange(Pattern, Pattern)
  ExcRange(Pattern, Pattern)
  Char(Char)
  Int(BigInt, IntTy)
  Str(String)
  Enum(String, Array[Pattern])
  Or(Array[Pattern])
  Tuple(Array[Pattern])
  Struct(Map[String, Pattern], Bool) // bool: has '..'
  Ident(String)
  Array(Array[Pattern])  // expand_front, content, expand_back
  Expand(String)
  Unknown
}

pub fn Name::unqualified(pack: Option[String], x: String) -> Name {
  { pack: pack, ns: None, name: x }
}

pub fn Name::qualified(pack: Option[String], ns: String, x: String) -> Name {
  { pack: pack, ns: Some(ns), name: x }
}

///|
/// Returns a new name with `self`'s name and namespace, and the given package.
/// 
pub fn Name::pack(self: Name, pack: String) -> Name {
  { ..self, pack: Some(pack) }
}

///|
/// Returns a new name without any package, but name and namespace remains unchanged.
/// 
pub fn Name::unpack(self: Name) -> Name {
  { ..self, pack: None }
}

///|
/// Returns true if the name does not have any namespace or package specified.
/// 
pub fn Name::standalone(self: Name) -> Bool {
  return self.ns is None && self.pack is None;
}

pub struct StructEntry {
  name: String
  ty: Type
  vis: Visible
  mutable: Bool
}

pub struct EnumEntry {
  tys: Array[Type]
  named: Map[String, Type]
}

pub(all) struct StructDetail {
  entries: Map[String, StructEntry]
  vis: Visible
  deriving: Array[Name]
  tyvars: Array[Typevar]
  name: Name
  ext: String?
}

pub(all) struct EnumDetail {
  entries: Map[String, EnumEntry]
  vis: Visible
  deriving: Array[Name]
  tyvars: Array[Typevar]
  name: Name
  error: Bool
  ext: String?
}

pub(all) struct AbstractDetail {
  vis: Visible
  tyvars: Array[Typevar]
  name: Name
  error: Bool
  ext: String?
}

pub(all) struct GlobalDetail {
  vis: Visible
  name: Name
  init: AST
  ty: Type
  ext: String?
}

pub(all) struct LocalDetail {
  name: String
  init: AST
  mutable: Bool
  ty: Type
}

pub struct Kwarg {
  name: String
  ty: Type
  default: AST?
} derive (Show)

pub(all) struct FnDetail {
  vis: Visible
  name: Name
  params: Array[String]
  tyvars: Array[Typevar]
  kwargs: Array[Kwarg]
  body: AST
  mut ty: Type
  ext: String?
}

pub(all) struct ImplDetail {
  vis: Visible
  ntrait: Name
  nstruct: Type
  nfunc: String
  params: Array[String]
  tyvars: Array[Typevar]
  body: AST
  ty: Type
  ext: String?
}

pub(all) struct TraitDetail {
  vis: Visible
  name: Name
  funcs: Array[FnDetail]
  tyvars: Array[Typevar]
  extends: Array[Name]
}

pub impl Show for StructEntry with to_string(self) -> String {
  let mutable = if (self.mutable) { "mut " } else { "" }
  let vis = if (self.vis == Priv) { "priv " } else { "" }
  "\{vis}\{mutable}\{self.name}: \{self.ty}"
}

pub impl Show for StructEntry with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub(all) struct Typevar {
  name: String
  extend: Array[Name]
}

pub impl Show for Typevar with to_string(self) -> String {
  if (self.extend.is_empty()) {
    return self.name;
  }

  let extend = self.extend.map(Name::to_string).join(" + ");
  "\{self.name}: \{extend}"
}

pub impl Show for Typevar with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

///|
/// Represents different kinds of AST (Abstract Syntax Tree) nodes in the MoonBit
/// compiler.
///
/// Each variant corresponds to a specific syntactic construct in the MoonBit
/// language, containing the necessary data to represent that construct in the
/// AST.
///
/// Constructors:
///
/// * `FnDecl(FnDetail)`: Function declaration.
/// * `ImplDecl(ImplDetail)`: Implementations of traits.
/// * `StructDecl(StructDetail)`: Structure type declaration.
/// * `TraitDecl(TraitDetail)`: Trait declaration.
/// * `StructInit(Map[String, AST])`: Structure initialization with field
/// mappings.
/// * `StructModif(AST, Map[String, AST])`: Structure modification using spread
/// (or expand) syntax.
/// * `StructLet(Pattern, AST, Type)`: Structure destructuring in let bindings,
/// with type optionally annotated (where the usual `None` is expressed by `Unknown`;
/// same below).
/// * `EnumLet(Pattern, AST, Type)`: Enum matching in let bindings, with type
/// optionally annotated.
/// * `ParamDecl(String)`: Parameter declaration with its name.
/// * `VarDecl(LocalDetail)`: Local variable declaration.
/// * `TupleDecl(Array[String], AST, Type)`: Tuple destructuring in let bindings,
/// with optional type annotation.
/// * `TupleMake(Array[AST])`: Tuple construction.
/// * `GlobalDecl(GlobalDetail)`: Global variable declaration.
/// * `EnumDecl(EnumDetail)`: Enumeration type declaration.
/// * `EnumConstr(Name, Array[AST])`: Enumeration constructor call.
/// * `If(AST, AST, Option[AST])`: Conditional expression with optional else
/// branch.
/// * `Binary(BinaryKind, AST, AST)`: Binary operation.
/// * `BinaryInplace(BinaryKind, AST, AST)`: In-place binary operation (e.g.,
/// `+=`, `*=`). Note that assignment is included here.
/// * `Unary(UnaryKind, AST)`: Unary operation. Note `try?` and `guard` are both
/// included here.
/// * `Block(Array[AST])`: Block expression containing multiple statements.
/// * `VarRef(Name)`: Variable reference.
/// * `FieldRef(AST, String)`: Field access on an expression.
/// * `Return(Option[AST])`: Return statement with optional return value.
/// * `Int(BigInt, IntTy)`: Integer literal, with arbitrary precision. This will
/// be truncated according to values given in `IntTy`.
/// * `Call(AST, Array[AST], Map[String, AST])`: Function call with positional
/// and keyword (named) arguments. These are referred to as `kwargs` throughout
/// the code and in documentation.
/// * `ChainCall(AST, String, Array[AST], Map[String, AST])`: Method call on an
/// object with the `..` operator. This AST node records the object, function name
/// and both positional and keyword arguments.
/// * `Double(Double)`: Double-precision floating-point literal.
/// * `Float(Float)`: Single-precision floating-point literal.
/// * `Str(String)`: String literal.
/// * `Fstr(Array[AST])`: Formatted string with embedded expressions.
/// * `Bool(Bool)`: Boolean literal.
/// * `Arr(Array[AST])`: Array literal.
/// * `Continue(Array[AST])`: Continue statement with optional values for loop
/// variables.
/// * `Char(Char)`: Character literal.
/// * `Break(Option[AST])`: Break statement with optional loop-yielded value.
/// * `While(AST, AST, Option[AST])`: While loop with condition, body, and an
/// optional else clause.
/// * `For(Array[(String, AST)], AST, Array[(String, AST)], AST, Option[AST])`:
/// For loop with initialization, condition, update, body, and an optional else
/// clause.
/// * `ForIn(Array[String], AST, AST, Option[AST])`: For-in loop with variables,
/// iterable, body, and an optional else clause.
/// * `Match(AST, Array[(Pattern, AST)])`: Pattern matching expression.
/// * `IncRange(AST, AST)`: Inclusive range expression (`..=`).
/// * `ExcRange(AST, AST)`: Exclusive range expression (`..<`).
/// * `ArrAccess(AST, AST)`: Array/map access, recording array and index/key.
/// * `Is(AST, Pattern)`: Pattern checking expression.
/// * `TupleAccess(AST, Int)`: Tuple element access by index.
/// * `Typealias(Visible, Type, Type)`: Type alias declaration.
/// * `Fnalias(Visible, Name, Name)`: Function alias declaration.
/// * `View(AST, AST, AST)`: Array/string view with start and end indices.
/// * `Guard(AST, Option[AST])`: Guard expression with condition and an optional
/// else branch.
/// * `Test(Option[String], AST)`: Test block with an optional name.
/// * `FFIBody(String)`: Foreign function interface body.
/// * `Byte(Byte)`: A byte literal.
/// * `ByteStr(Bytes)`: A byte-string literal.
/// * `Raise`: Raise an error.
/// * `Unit`: Unit value `()`.
/// * `Leaf`: Placeholder node (typically removed during processing).
///
pub(all) enum ASTType {
  FnDecl(FnDetail)
  ImplDecl(ImplDetail)
  StructDecl(StructDetail)
  TraitDecl(TraitDetail)
  StructInit(Map[String, AST])
  StructModif(AST, Map[String, AST])
  StructLet(Pattern, AST, Type);
  EnumLet(Pattern, AST, Type);
  ParamDecl(String)
  VarDecl(LocalDetail)
  TupleDecl(Array[String], AST, Type)
  TupleMake(Array[AST])
  GlobalDecl(GlobalDetail)
  EnumDecl(EnumDetail)
  AbstractDecl(AbstractDetail)
  EnumConstr(Name, Array[AST])
  If(AST, AST, Option[AST])
  Binary(BinaryKind, AST, AST)
  BinaryInplace(BinaryKind, AST, AST)
  Unary(UnaryKind, AST)
  Block(Array[AST])
  VarRef(Name)
  FieldRef(AST, String)
  Return(Option[AST])
  Int(BigInt, IntTy)
  Call(AST, Array[AST], Map[String, AST])
  ChainCall(AST, String, Array[AST], Map[String, AST])
  Double(Double)
  Float(Float)
  Str(String)
  Fstr(Array[AST])
  Bool(Bool)
  Arr(Array[AST])
  Continue(Array[AST])
  Char(Char)
  Break(Option[AST])
  While(AST, AST, Option[AST])
  For(Array[(String, AST)], AST, Array[(String, AST)], AST, Option[AST])
  ForIn(Array[String], AST, AST, Option[AST])
  Match(AST, Array[(Pattern, AST)])
  IncRange(AST, AST)
  ExcRange(AST, AST)
  ArrAccess(AST, AST)
  Is(AST, Pattern)
  TupleAccess(AST, Int)
  Typealias(Visible, Type, Type)
  Fnalias(Visible, Name, Name)
  View(AST, AST, AST)
  Guard(AST, Option[AST])
  Test(Option[String], AST)
  FFIBody(String)
  Byte(Byte)
  ByteStr(Bytes)
  Unit
  Leaf
}

pub(all) struct AST {
  kind: ASTType
  from: @diag.Loc
  to: @diag.Loc
  mut attr: Array[Attribute]
  mut ty: Type
}

pub fn AST::new(kind: ASTType, from: @diag.Loc, to: @diag.Loc) -> AST {
  return {
    kind: kind,
    ty: Unknown,
    from: from,
    to: to,
    attr: []
  }
}

pub impl Show for BinaryKind with to_string(self) -> String {
  match self {
    Div => "/"
    Mul => "*"
    Sub => "-"
    Add => "+"
    Mod => "%"
    Lt => "<"
    Le => "<="
    Eq => "=="
    Ne => "!="
    Assign => "="
    And => "&&"
    Or => "||"
    Bitand => "&"
    Bitor => "|"
    Xor => "^"
    Lsh => "<<"
    Rsh => ">>"
  }
}

pub impl Show for BinaryKind with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for UnaryKind with to_string(self) -> String {
  match self {
    Not => "!"
    Minus => "-"
    Try => "try? "
    Expand => ".."
    Raise => "raise "
  }
}

pub impl Show for UnaryKind with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for Visible with to_string(self) -> String {
  match self {
    Priv => "priv"
    Pub => "pub"
    Pubopen => "pub(open)"
    Puball => "pub(all)"
  }
}

pub impl Show for Visible with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for Pattern with to_string(self) -> String {
  match self {
    Int(x, _) => "\{x}"
    Str(x) => x
    Char(x) => "'\{x}'"
    IncRange(x, y) => "\{x}..=\{y}"
    ExcRange(x, y) => "\{x}..<\{y}"
    Unknown => "?"
    Enum(x, arr) => {
      let params = arr.map(Pattern::to_string).join(", ");
      let params = if (params.length() == 0) { "" } else { "(\{params})" }
      "\{x}\{params}"
    }
    Or(arr) => arr.map(Pattern::to_string).join(" | ")
    Tuple(arr) => {
      let s = arr.map(Pattern::to_string).join(", ");
      "(\{s})"
    }
    Ident(x) => x
    Struct(map, default) => {
      let empty = map.size() == 0;
      let default = if (default) { @utils.ite(empty, "..", ", ..") } else { "" }
      let fields = map.iter().map(fn (t) {
        let (x, y) = t;
        "\{x}: \{y}"
      }).collect().join(", ");
      "{ \{fields}\{default} }"
    }
    Array(content) => "[" + content.map(fn (x) { x.to_string() }).join(", ") + "]";
    Expand(x) => ".. \{x}"
  }
}

pub impl Show for Pattern with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for Name with to_string(self) -> String {
  let builder = StringBuilder::new();
  if (self.pack is Some(pack)) {
    builder.write_string("\{pack}.");
  }
  if (self.ns is Some(ns)) {
    builder.write_string("\{ns}::");
  }
  builder.write_string(self.name);
  builder.to_string()
}

pub impl Show for Name with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

// We do not use the standard escape, because String::op_as_view is deprecated,
// and it's not easy to remove the surrounding quotes.
fn escape(s: String) -> String {
  let str = s.to_array();
  let result = [];
  let mut pos = 0;
  
  let ch = fn () {
    let c = str[pos];
    pos += 1;
    return c;
  }

  while (pos < str.length()) {
    match ch() {
      '\n' => result.append(['\\', 'n'])
      '\t' => result.append(['\\', 't'])
      '\r' => result.append(['\\', 'r'])
      '\\' => result.append(['\\', '\\'])
      '\'' => result.append(['\\', '\''])
      '\"' => result.append(['\\', '"'])
      '\b' => result.append(['\\', 'b'])
      c => result.push(c)
    }
  }

  return String::from_array(result);
}

fn escapef(s: Array[AST], depth: Int) -> String {
  let builder = StringBuilder::new();
  for x in s {
    match x.kind {
      Str(vs) => builder.write_string(escape(vs))
      _ => builder.write_string("\\{\{dep_str(x, depth)}}")
    }
  }
  builder.to_string()
}

fn dep_str(ast: AST, depth: Int) -> String {
  match ast.kind {
    Int(vi, _) => "\{vi}"
    Double(vd) => "\{vd}"
    Float(vf) => "\{vf}F"
    Str(vs) => "\"\{escape(vs)}\""
    VarRef(name) => "\{name}"
    Bool(vb) => "\{vb}"
    Char(vc) => "'\{escape(String::from_array([vc]))}'"
    Unit => "()"
    Leaf => "<leaf>"
    Byte(vb) => "\{vb}"
    ByteStr(vs) => "\{vs}"
    Fstr(vs) => "\"\{escapef(vs, depth)}\""
    FFIBody(ffi) => "= \"\{ffi}\""
    Arr(arr) => {
      let s = arr.map(fn (x) { dep_str(x, depth) }).join(", ");
      "[\{s}]"
    }
    Block(arr) => {
      let builder = StringBuilder::new();
      let indent = String::make(@math.maximum(2 * (depth - 1), 0), ' ');
      builder.write_string("{\n");
      for x in arr {
        builder.write_string("  \{indent}\{dep_str(x, depth + 1)};\n");
      }
      builder.write_string("\{indent}}");
      builder.to_string();
    }
    Binary(kind, l, r) => "(\{dep_str(l, depth)} \{kind} \{dep_str(r, depth)})"
    BinaryInplace(kind, l, r) => {
      let kind = if (kind is Assign) { "=" } else { "\{kind}=" }
      "\{dep_str(l, depth)} \{kind} \{dep_str(r, depth)}"
    }
    Unary(kind, l) => "(\{kind}\{dep_str(l, depth)})"
    VarDecl(detail) => {
      let { name, mutable, init, ty } = detail;
      let mutable = @utils.ite(mutable, "mut ", "");
      "let \{mutable}\{name}: \{ty} = \{dep_str(init, depth)}"
    }
    TupleDecl(names, init, ty) => {
      let name = names.join(", ");
      "let (\{name}): \{ty} = \{dep_str(init, depth)}"
    }
    StructLet(pattern, init, ty) | EnumLet(pattern, init, ty) => {
      "let \{pattern}: \{ty} = \{dep_str(init, depth)}";
    }
    TupleMake(arr) => {
      let s = arr.map(fn (x) { dep_str(x, depth) }).join(", ");
      "(\{s})"
    }
    GlobalDecl(detail) => {
      let { vis, name, init, ty, ext } = detail;
      let visible = @utils.ite(vis == Priv, "", "\{vis} ");
      let ext = if (ext is Some(w)) { "extern \"\{w}\"" } else { "" };
      "\{ext}let \{visible}\{name}: \{ty} = \{dep_str(init, depth)}";
    }
    ParamDecl(name) => name
    FnDecl(detail) => {
      let { vis, name, params, tyvars, body, ty, kwargs, ext } = detail;
      let params = if (["main", "init"].contains(name.name)) {
        ""
      } else {
        let tys = if (ty is Function(tys, _)) { tys } else { [] };
        fn get(i) { if (i >= tys.length()) { Type::Unknown } else { tys[i] } }
        let params = params.mapi(fn (i, x) { "\{x}: \{get(i)}"}).join(", ");
        let mut s = kwargs.map(fn (t) {
          let { name, ty, default } = t;
          let s = default.map_or("", fn (x) { " = \{dep_str(x, depth)}" })
          "\{name}: \{ty}\{s}"
        }).join(", ");
        if (not(kwargs.is_empty()) && not(params.is_empty())) {
          s = ", \{s}";
        }
         "(\{params}\{s})";
      }
      let ret = if (ty is Function(_, ret)) { "\{ret}" } else { "" };
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      let ext = if (ext is Some(w)) { "extern \"\{w}\"" } else { "" };
      "\{visible}\{ext}fn\{tyvars} \{name}\{params} -> \{ret} \{dep_str(body, depth)}"
    }
    ImplDecl(detail) => {
      let params = detail.params.join(", ");
      let visible = @utils.ite(detail.vis == Priv, "", "\{detail.vis} ")
      let tyvars = if (detail.tyvars.is_empty()) { "" } else { let s = detail.tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      "\{visible}impl\{tyvars} \{detail.ntrait} for \{detail.nstruct} with \{detail.nfunc}(\{params}) \{dep_str(detail.body, depth)}"
    }
    StructDecl(detail) => {
      let { name, entries, tyvars, deriving, vis, ext } = detail;
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let fields = entries.values().map(StructEntry::to_string).join("\n  \{indent}");
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let deriving = deriving.map(Name::to_string).join(", ");
      let deriving = @utils.ite(deriving.length() == 0, "", " derive (\{deriving})");
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      let ext = if (ext is Some(w)) { "extern \"\{w}\"" } else { "" };
      "\{visible}\{ext}struct \{name}\{tyvars} {\n  \{indent}\{fields}\n\{indent}}\{deriving}"
    }
    TraitDecl(detail) => {
      let strs = [];
      let { name, vis, funcs, tyvars, extends } = detail;
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let extends = if (extends.is_empty()) { "" } else { let s = extends.map(Name::to_string).join(" + "); " : \{s}"}
      for i in funcs {
        let { name, params, tyvars, ty, kwargs, .. } = i;
        let params = if (["main", "init"].contains(name.name)) {
          ""
        } else {
          let tys = if (ty is Function(tys, _)) { tys } else { [] };
          fn get(i) { if (i >= tys.length()) { Type::Unknown } else { tys[i] } }
          let params = params.mapi(fn (i, x) { "\{x}: \{get(i)}"}).join(", ");
          let mut s = kwargs.map(fn (t) {
            let { name, ty, default } = t;
            let s = default.map_or("", fn (x) { " = \{dep_str(x, depth)}" })
            "\{name}: \{ty}\{s}"
          }).join(", ");
          if (not(kwargs.is_empty()) && not(params.is_empty())) {
            s = ", \{s}";
          }
          "(\{params}\{s})";
        }
        let ret = if (ty is Function(_, ret)) { "\{ret}" } else { "" };
        let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
        strs.push("fn\{tyvars} \{name}\{params} -> \{ret}")
      }
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let body = strs.join("  \{indent}\n");
      "\{visible}trait\{tyvars}\{extends} \{name} {\n  \{indent}\{body}\n\{indent}}"
    }
    EnumDecl(detail) => {
      let { name, entries, tyvars, deriving, vis, error: _, ext } = detail;
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let fields = entries.iter().map(fn (t) {
        let (x, y) = t;
        let s = y.tys.map(Type::to_string).join(", ");
        let s = if (s.length() == 0) { "" } else { "(\{s})" }
        "\{x}\{s}"
      }).join("\n  \{indent}");
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let deriving = deriving.map(Name::to_string).join(", ");
      let deriving = @utils.ite(deriving.length() == 0, "", " derive (\{deriving})");
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      let ext = if (ext is Some(w)) { "extern \"\{w}\"" } else { "" };
      "\{visible}\{ext}enum \{name}\{tyvars} {\n  \{indent}\{fields}\n\{indent}}\{deriving}";
    }
    AbstractDecl(detail) => {
      let { name, tyvars, vis, error, ext } = detail;
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      let ext = if (ext is Some(w)) { "extern \"\{w}\"" } else { "" };
      let ty = if (error) { "suberror" } else { "type" }
      "\{visible}\{ext}\{ty} \{name}\{tyvars}";
    }
    StructInit(map) => {
      let fields = map.to_array().map(fn (t) {
        let (x, y) = t;
        "\{x}: \{dep_str(y, depth)}"
      }).join(", ");
      "{ \{fields} }";
    }
    StructModif(base, map) => {
      let fields = map.to_array().map(fn (t) {
        let (x, y) = t;
        "\{x}: \{dep_str(y, depth)}"
      }).join(", ");
      "{ ..\{dep_str(base, depth)}, \{fields} }";
    }
    If(cond, l, r) => {
      let builder = StringBuilder::new();
      builder.write_string("if \{cond} ");
      builder.write_string(dep_str(l, depth));
      builder.write_string(r.map_or("", fn(x) { " else \{dep_str(x, depth)}" }));
      builder.to_string();
    }
    Return(ast) => {
      match ast {
        None => "return";
        Some(ast) => "return \{dep_str(ast, depth)}"
      }
    }
    Call(call, args, kwargs) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      let mut pos = kwargs.iter().map(fn (x) { "\{x.0}=\{dep_str(x.1, depth)}" }).collect().join(", ");
      if (args.length() >= 1 && not(pos.is_empty())) {
        pos = ", \{pos}"
      }
      "\{dep_str(call, depth)}(\{args}\{pos})";
    }
    ChainCall(this, name, args, kwargs) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      let mut pos = kwargs.iter().map(fn (x) { "\{x.0}=\{dep_str(x.1, depth)}" }).collect().join(", ");
      if (args.length() >= 1 && not(pos.is_empty())) {
        pos = ", \{pos}"
      }
      "\{dep_str(this, depth)}..\{name}(\{args}\{pos})";
    }
    EnumConstr(name, args) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      let args = if (args.length() == 0) { "" } else { "(\{args})" }
      "\{name}\{args}";
    }
    FieldRef(x, name) => "\{dep_str(x, depth)}.\{name}"
    Break(val) => {
      let v = val.map_or("", fn (x) { " \{dep_str(x, depth)}" });
      "break\{v}";
    }
    Continue(arr) => {
      let mut v = arr.map(fn (x) { "\{dep_str(x, depth)}" }).join(", ");
      if (v.length() > 0) {
        v = " \{v}";
      }
      "continue\{v}";
    }
    While(cond, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "while \{dep_str(cond, depth)} \{dep_str(body, depth)}\{v}";
    }
    For(inits, stop, steps, body, exit) => {
      let init = inits.map(fn (t) {
        let (name, init) = t;
        "\{name} = \{dep_str(init, depth)}"
      }).join(", ");
      let step = steps.map(fn (t) {
        let (name, step) = t;
        "\{name} = \{dep_str(step, depth)}"
      }).join(", ");
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{init}; \{dep_str(stop, depth)}; \{step} \{dep_str(body, depth)}\{v}"
    }
    ForIn(names, range, body, exit) => {
      let names = names.join(", ");
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{names} in \{dep_str(range, depth)} \{dep_str(body, depth)}\{v}"
    }
    IncRange(begin, end) => "\{dep_str(begin, depth)}..=\{dep_str(end, depth)}"
    ExcRange(begin, end) => "\{dep_str(begin, depth)}..<\{dep_str(end, depth)}"
    ArrAccess(begin, end) => "\{dep_str(begin, depth)}[\{dep_str(end, depth)}]"
    Match(matcher, arr) => {
      let indent = String::make(@math.maximum(2 * (depth - 1), 0), ' ');
      let s = arr.map(fn (t) {
        let (pat, body) = t;
        "  \{indent}\{pat} => \{dep_str(body, depth + 1)}"
      }).join("\n");
      "match \{dep_str(matcher, depth)} {\n\{s}\n\{indent}}"
    }
    Is(x, pat) => "(\{dep_str(x, depth)} is \{pat})"
    TupleAccess(x, v) => "\{dep_str(x, depth)}.\{v}"
    Typealias(visible, src, tgt) => {
      let visible = if (visible == Priv) { "" } else { "\{visible} " }
      "\{visible}typealias \{src} as \{tgt}"
    }
    Fnalias(visible, src, tgt) => {
      let visible = if (visible == Priv) { "" } else { "\{visible} " }
      "\{visible}fnalias \{src} as \{tgt}"
    }
    View(x, from, to) => {
      let from = if (to.kind is Int(0, _)) { "" } else { dep_str(from, depth) }
      let to = if (to.kind is Int(2147483647, _)) { "" } else { dep_str(to, depth) }
      "\{dep_str(x, depth)}[\{from}:\{to}]"
    }
    Guard(cond, other) => {
      let other = if (other is Some(x)) { " else \{dep_str(x, depth)}"} else { "" }
      "guard \{cond}\{other}"
    }
    Test(name, body) => {
      let name = name.map_or("", fn (x) { " \"\{x}\"" });
      "test\{name} \{dep_str(body, depth)}"
    }
  }
}

pub impl Show for ASTType with to_string(self) -> String {
  dep_str({ kind: self, from: @diag.Loc::unknown(), to: @diag.Loc::unknown(), ty: Unknown, attr: [] }, 1);
}

pub impl Show for ASTType with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for AST with to_string(self) -> String {
  self.kind.to_string();
}

pub impl Show for AST with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

fn[K: Eq + Hash] cvt(map: Map[K, AST], f: (AST) -> AST) -> Map[K, AST] {
  Map::from_array(map.iter().map(fn (t) { (t.0, t.1.map(f)) }).collect())
}

pub fn AST::map(self: AST, f: (AST) -> AST) -> AST {
  let mapper = (x: AST) => x.map(f)
  f({ ..self, kind: match self.kind {
    FnDecl(detail) => FnDecl({ ..detail, body: detail.body.map(f), kwargs: detail.kwargs.map(fn (x) { { ..x, default: x.default.map(mapper) } }) })
    ImplDecl(detail) => ImplDecl({ ..detail, body: detail.body.map(f) })
    VarDecl(detail) => VarDecl({ ..detail, init: detail.init.map(f) })
    TupleDecl(name, init, ty) => TupleDecl(name, init.map(f), ty)
    TupleAccess(x, v) => TupleAccess(x.map(f), v)
    TupleMake(arr) => TupleMake(arr.map(mapper))
    StructLet(pat, ast, ty) => StructLet(pat, ast.map(f), ty)
    EnumLet(pat, ast, ty) => EnumLet(pat, ast.map(f), ty)
    GlobalDecl(detail) => GlobalDecl({ ..detail, init: detail.init.map(f) })
    If(cond, l, r) => If(cond.map(f), l.map(f), r.map(mapper))
    Binary(kind, l, r) => Binary(kind, l.map(f), r.map(f))
    BinaryInplace(kind, l, r) => BinaryInplace(kind, l.map(f), r.map(f))
    Unary(kind, l) => Unary(kind, l.map(f))
    Block(body) => Block(body.map(mapper))
    Return(x) => Return(x.map(f))
    Call(x, args, kwargs) => Call(x.map(f), args.map(mapper), cvt(kwargs, f));
    ChainCall(x, name, args, kwargs) => ChainCall(x.map(f), name, args.map(mapper), cvt(kwargs, f));
    FieldRef(x, name) => FieldRef(x.map(f), name)
    StructInit(map) => StructInit(cvt(map, f))
    StructModif(base, map) => StructModif(base.map(f), cvt(map, f))
    Arr(arr) => Arr(arr.map(mapper))
    Break(val) => Break(val.map(f))
    Continue(val) => Continue(val.map(mapper))
    While(cond, body, exit) => While(cond.map(f), body.map(f), exit.map(mapper))
    For(inits, stop, steps, body, exit) => For(inits.map((x) => (x.0, x.1.map(f))), stop.map(f), steps.map((x) => (x.0, x.1.map(f))), body.map(f), exit.map(mapper))
    ForIn(indvar, range, body, exit) => ForIn(indvar, range.map(f), body.map(f), exit.map(mapper));
    EnumConstr(name, arr) => EnumConstr(name, arr.map(mapper))
    IncRange(x, y) => IncRange(x.map(f), y.map(f))
    ExcRange(x, y) => ExcRange(x.map(f), y.map(f))
    ArrAccess(x, y) => ArrAccess(x.map(f), y.map(f))
    Match(matcher, arr) => Match(matcher.map(f), arr.map((x) => (x.0, x.1.map(f))))
    Fstr(vs) => Fstr(vs.map(mapper))
    Is(x, pat) => Is(x.map(f), pat)
    View(x, from, to) => View(x.map(f), from.map(f), to.map(f))
    Guard(cond, other) => Guard(cond.map(f), other.map(mapper))
    Test(name, body) => Test(name, body.map(f))
    Int(_) | VarRef(_) | ParamDecl(_) | Leaf |
    StructDecl(_) | Double(_) | Float(_) | Str(_) |
    Unit | EnumDecl(_) | Bool(_) | Char(_) |
    Typealias(_) | Fnalias(_) | FFIBody(_) | Byte(_) |
    ByteStr(_) | TraitDecl(_) | AbstractDecl(_) => self.kind
  }
  });
}

pub fn AST::visit(self: AST, f: (AST) -> Unit) -> Unit {
  self.map((x) => { f(x); x }) |> ignore;
}

pub fn AST::remove_leaf(self: AST) -> AST {
  self.map((x) => match x {
    { kind: Block(arr), .. } => { ..x, kind: Block(arr.filter(fn (x) { not(x.kind is Leaf) })) }
    _ => x
  })
}

pub fn AST::weaken(self: AST) -> AST {
  self.map((ast) => { ..ast,
    ty: ast.ty.weaken(),
    kind: match ast.kind {
      FnDecl(detail) => FnDecl({ ..detail, ty: detail.ty.weaken() })
      GlobalDecl(detail) => GlobalDecl({ ..detail, ty: detail.ty.weaken() })
      ImplDecl(detail) => ImplDecl({ ..detail, ty: detail.ty.weaken() })
      VarDecl(detail) => VarDecl({ ..detail, ty: detail.ty.weaken() })
      TupleDecl(a, b, ty) => TupleDecl(a, b, ty.weaken())
      StructLet(a, b, ty) => StructLet(a, b, ty.weaken())
      EnumLet(a, b, ty) => EnumLet(a, b, ty.weaken())
      c => c
    }
  });
}

pub fn AST::tidy(self: AST) -> AST {
  self.remove_leaf().weaken();
}

pub fn AST::leaf() -> AST {
  AST::new(Leaf, Loc::unknown(), Loc::unknown())
}
