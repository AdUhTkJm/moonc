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
} derive(Eq, Hash)

pub(all) enum UnaryKind {
  Not
  Minus
  Try
  Expand
} derive(Eq, Hash)

pub(all) enum Visible {
  Priv
  Pub
  Pubopen
  Puball
} derive(Eq, Hash)

pub(all) struct Name {
  pack: String?
  namespace: String?
  name: String
} derive(Eq, Hash)

pub(all) enum Pattern {
  IncRange(Pattern, Pattern)
  ExcRange(Pattern, Pattern)
  Char(Char)
  Int(Int)
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
  { pack: pack, namespace: None, name: x }
}

pub fn Name::qualified(pack: Option[String], namespace: String, x: String) -> Name {
  { pack: pack, namespace: Some(namespace), name: x }
}

pub fn Name::pack(self: Name, pack: String) -> Name {
  { ..self, pack: Some(pack) }
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

pub struct StructDetail {
  entries: Map[String, StructEntry]
  vis: Visible
  deriving: Array[Name]
  tyvars: Array[Typevar]
  name: Name
}

pub struct EnumDetail {
  entries: Map[String, EnumEntry]
  vis: Visible
  deriving: Array[Name]
  tyvars: Array[Typevar]
  name: Name
}

pub struct GlobalDetail {
  vis: Visible
  name: Name
  init: AST
}

pub struct LocalDetail {
  name: String
  init: AST
  mutable: Bool
}

pub struct FnDetail {
  vis: Visible
  name: Name
  params: Array[String]
  tyvars: Array[Typevar]
  body: AST
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

pub(all) enum ASTType {
  FnDecl(FnDetail)
  ImplDecl(Visible, Name, Name, String, Array[String], AST)
  StructDecl(StructDetail)
  StructInit(Map[String, AST])
  StructModif(AST, Map[String, AST])
  ParamDecl(String)
  VarDecl(LocalDetail)
  TupleDecl(Array[String], AST)
  TupleMake(Array[AST])
  GlobalDecl(GlobalDetail)
  EnumDecl(EnumDetail)
  EnumConstr(Name, Array[AST])
  If(AST, AST, Option[AST])
  Binary(BinaryKind, AST, AST)
  BinaryInplace(BinaryKind, AST, AST)
  Unary(UnaryKind, AST)
  Block(Array[AST])
  VarRef(Name)
  FieldRef(AST, String)
  Return(Option[AST])
  Int(Int)
  Call(AST, Array[AST], Map[String, AST])
  ThisCall(AST, String, Array[AST], Map[String, AST])
  Double(Double)
  Float(Float)
  Str(String)
  Fstr(Array[AST])
  Bool(Bool)
  Arr(Array[AST])
  Continue
  Char(Char)
  Break(Option[AST])
  While(AST, AST, Option[AST])
  For(String, AST, AST, AST, AST, Option[AST])
  ForIn(String, AST, AST, Option[AST])
  Match(AST, Array[(Pattern, AST)])
  IncRange(AST, AST)
  ExcRange(AST, AST)
  ArrAccess(AST, AST)
  Is(AST, Pattern)
  TupleAccess(AST, Int)
  Typealias(Visible, Type, Type)
  Fnalias(Visible, Name, Name)
  View(AST, AST, AST)
  Unit
  Leaf
}

pub(all) enum Type {
  Named(Name, Array[Type])
  Struct(Name, Array[Type])
  Enum(Name, Array[Type])
  FixedArray(Type)
  Function(Array[Type], Type)
  Tuple(Array[Type])
  Typevar(Typevar)
  Int
  Float
  Unit
  Double
  Bool
  Char
  Option(Type)
  Unknown
  Weak(Ref[Type])
}

pub(all) struct AST {
  kind: ASTType
  from: @diag.Loc
  to: @diag.Loc
  mut ty: Type
}

pub fn AST::new(kind: ASTType, from: @diag.Loc, to: @diag.Loc) -> AST {
  return {
    kind: kind,
    ty: Unknown,
    from: from,
    to: to
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
  }
}

pub impl Show for BinaryKind with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for UnaryKind with to_string(self) -> String {
  match self {
    Not => "!"
    Minus => "-"
    Try => "try?"
    Expand => ".."
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
    Int(x) => "\{x}"
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
  if (self.namespace is Some(namespace)) {
    builder.write_string("\{namespace}::");
  }
  builder.write_string(self.name);
  builder.to_string()
}

pub impl Show for Name with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for Type with to_string(self) -> String {
  match (self) {
    Int => "Int"
    Double => "Double"
    Float => "Float"
    Unit => "Unit"
    Bool => "Bool"
    Char => "Char"
    Named(x, []) | Struct(x, []) | Enum(x, []) => x.to_string()
    Named(x, arr) | Struct(x, arr) | Enum(x, arr) => {
      let s = arr.map(Type::to_string).join(", ")
      "\{x}[\{s}]"
    }
    FixedArray(x) => "FixedArray[\{x}]"
    Weak(x) => "'weak(\{x.val})"
    Unknown => "?"
    Tuple(arr) => {
      let s = arr.map(Type::to_string).join(", ")
      "(\{s})"
    }
    Option(x) => "\{x}?"
    Function(args, ret) => {
      let s = args.map(Type::to_string).join(", ")
      "((\{s}) -> \{ret})"
    }
    Typevar(var) => "\{var}"
  }
}

pub impl Show for Type with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

fn escape(s: String) -> String {
  let str = s.to_array();
  let result = [];
  let mut pos = 0;
  
  let ch = fn () {
    let c = str[pos];
    pos += 1;
    return c;
  }

  while (pos < s.length()) {
    match ch() {
      '\n' => result.append(['\\', 'n'])
      '\t' => result.append(['\\', 't'])
      '\r' => result.append(['\\', 'r'])
      '\\' => result.append(['\\', '\\'])
      '\'' => result.append(['\\', '\''])
      '\"' => result.append(['\\', '"'])
      '\u0000' => result.append(['\\', 'u', '0', '0', '0', '0'])
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
    Int(vi) => "\{vi}"
    Double(vd) => "\{vd}"
    Float(vf) => "\{vf}F"
    Str(vs) => "\"\{escape(vs)}\""
    VarRef(name) => "\{name}"
    Bool(vb) => "\{vb}"
    Char(vc) => "'\{escape(String::from_array([vc]))}'"
    Unit => "()"
    Fstr(vs) => "\"\{escapef(vs, depth)}\""
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
      let { name, mutable, init } = detail;
      let mutable = @utils.ite(mutable, "mut ", "");
      "let \{mutable}\{name}: \{ast.ty} = \{dep_str(init, depth)}"
    }
    TupleDecl(names, init) => {
      let name = names.join(", ");
      "let (\{name}): \{ast.ty} = \{dep_str(init, depth)}"
    }
    TupleMake(arr) => {
      let s = arr.map(fn (x) { dep_str(x, depth) }).join(", ");
      "(\{s})"
    }
    GlobalDecl(detail) => {
      let { vis, name, init } = detail;
      let visible = @utils.ite(vis == Priv, "", "\{vis} ")
      "let \{visible}\{name}: \{ast.ty} = \{dep_str(init, depth)}";
    }
    ParamDecl(name) => name
    FnDecl(detail) => {
      let { vis, name, params, tyvars, body } = detail;
      let params = if (["main", "test", "init"].contains(name.name)) {
        ""
      } else {
        let tys = if (ast.ty is Function(tys, _)) { tys } else { [] };
        fn get(i) { if (i >= tys.length()) { Type::Unknown } else { tys[i] } }
        let params = params.mapi(fn (i, x) { "\{x}: \{get(i)}"}).join(", ");
         "(\{params})";
      }
      let ret = if (ast.ty is Function(_, ret)) { "\{ret}" } else { "" };
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      "\{visible}fn\{tyvars} \{name}\{params} -> \{ret} \{dep_str(body, depth)}"
    }
    ImplDecl(visible, structname, traitname, funcname, params, body) => {
      let params = params.join(", ");
      let visible = @utils.ite(visible == Priv, "", "\{visible} ")
      "\{visible}impl \{traitname} for \{structname} with \{funcname}(\{params}) \{dep_str(body, depth)}"
    }
    StructDecl(detail) => {
      let { name, entries, tyvars, deriving, vis } = detail;
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let fields = entries.values().map(StructEntry::to_string).join("\n  \{indent}");
      let visible = if (vis == Priv) { "" } else { "\{vis} " };
      let deriving = deriving.map(Name::to_string).join(", ");
      let deriving = @utils.ite(deriving.length() == 0, "", " derive (\{deriving})");
      let tyvars = if (tyvars.is_empty()) { "" } else { let s = tyvars.map(Typevar::to_string).join(", "); "[\{s}]" };
      "\{visible}struct \{name}\{tyvars} {\n  \{indent}\{fields}\n\{indent}}\{deriving}"
    }
    EnumDecl(detail) => {
      let { name, entries, tyvars, deriving, vis } = detail;
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
      "\{visible}struct \{name}\{tyvars} {\n  \{indent}\{fields}\n\{indent}}\{deriving}";
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
    Call(call, args, positional) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      let mut pos = positional.iter().map(fn (x) { "\{x.0}=\{dep_str(x.1, depth)}" }).collect().join(", ");
      if (args.length() >= 1 && not(pos.is_empty())) {
        pos = ", \{pos}"
      }
      "\{dep_str(call, depth)}(\{args}\{pos})";
    }
    ThisCall(this, name, args, positional) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      let mut pos = positional.iter().map(fn (x) { "\{x.0}=\{dep_str(x.1, depth)}" }).collect().join(", ");
      if (args.length() >= 1 && not(pos.is_empty())) {
        pos = ", \{pos}"
      }
      "\{dep_str(this, depth)}.\{name}(\{args}\{pos})";
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
    While(cond, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "while \{dep_str(cond, depth)} \{dep_str(body, depth)}\{v}";
    }
    For(name, start, stop, step, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{name} = \{dep_str(start, depth)}; \{dep_str(stop, depth)}; \{name} = \{dep_str(step, depth)} \{dep_str(body, depth)}\{v}"
    }
    ForIn(name, range, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{name} in \{dep_str(range, depth)} \{dep_str(body, depth)}\{v}"
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
      let from = if (to.kind is Int(0)) { "" } else { dep_str(from, depth) }
      let to = if (to.kind is Int(2147483647)) { "" } else { dep_str(to, depth) }
      "\{dep_str(x, depth)}[\{from}:\{to}]"
    }
    Continue => "continue"
    Leaf => "<leaf>"
  }
}

pub impl Show for ASTType with to_string(self) -> String {
  dep_str({ kind: self, from: @diag.Loc::unknown(), to: @diag.Loc::unknown(), ty: Unknown }, 1);
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
  let mapper = fn (x: AST) { x.map(f) }
  f({ ..self, kind:
  match self.kind {
    FnDecl(detail) => FnDecl({ ..detail, body: detail.body.map(f) })
    ImplDecl(visible, struct_, trait_, func, params, body) => ImplDecl(visible, struct_, trait_, func, params, body.map(f))
    VarDecl(detail) => VarDecl({ ..detail, init: detail.init.map(f) })
    TupleDecl(name, init) => TupleDecl(name, init.map(f))
    TupleAccess(x, v) => TupleAccess(x.map(f), v)
    TupleMake(arr) => TupleMake(arr.map(mapper))
    GlobalDecl(detail) => GlobalDecl({ ..detail, init: detail.init.map(f) })
    If(cond, l, r) => If(cond.map(f), l.map(f), r.map(f))
    Binary(kind, l, r) => Binary(kind, l.map(f), r.map(f))
    BinaryInplace(kind, l, r) => BinaryInplace(kind, l.map(f), r.map(f))
    Unary(kind, l) => Unary(kind, l.map(f))
    Block(body) => Block(body.map(mapper))
    Return(x) => Return(x.map(f))
    Call(x, args, positional) => Call(x.map(f), args.map(mapper), cvt(positional, f));
    ThisCall(x, name, args, positional) => ThisCall(x.map(f), name, args.map(mapper), cvt(positional, f));
    FieldRef(x, name) => FieldRef(x.map(f), name)
    StructInit(map) => StructInit(cvt(map, f))
    StructModif(base, map) => StructModif(base.map(f), cvt(map, f))
    Arr(arr) => Arr(arr.map(mapper))
    Break(val) => Break(val.map(f))
    While(cond, body, exit) => While(cond.map(f), body.map(f), exit.map(f))
    For(name, start, stop, step, body, exit) => For(name, start.map(f), stop.map(f), step.map(f), body.map(f), exit.map(f))
    ForIn(indvar, range, body, exit) => ForIn(indvar, range.map(f), body.map(f), exit.map(f));
    EnumConstr(name, arr) => EnumConstr(name, arr.map(mapper))
    IncRange(x, y) => IncRange(x.map(f), y.map(f))
    ExcRange(x, y) => ExcRange(x.map(f), y.map(f))
    ArrAccess(x, y) => ArrAccess(x.map(f), y.map(f))
    Match(matcher, arr) => Match(matcher.map(f), arr.map(fn (t) { (t.0, t.1.map(f)) }))
    Fstr(vs) => Fstr(vs.map(mapper))
    Is(x, pat) => Is(x.map(f), pat)
    View(x, from, to) => View(x.map(f), from.map(f), to.map(f))
    Int(_) | VarRef(_) | ParamDecl(_) | Leaf |
    StructDecl(_) | Double(_) | Float(_) | Str(_) |
    Continue | EnumDecl(_) | Bool(_) | Char(_) |
    Unit | Typealias(_) | Fnalias(_) => self.kind
  }
  });
}

pub fn AST::visit(self: AST, f: (AST) -> Unit) -> Unit {
  self.map(fn (x) { f(x); x }) |> ignore;
}

pub fn AST::remove_leaf(self: AST) -> AST {
  self.map(fn (x) {
    match x {
      { kind: Block(arr), .. } => { kind: Block(arr.filter(fn (x) { not(x.kind is Leaf) })), from: x.from, to: x.to, ty: x.ty }
      _ => x
    }
  })
}

pub fn AST::weaken(self: AST) -> AST {
  self.map(fn (ast) {
    { ..ast, ty: ast.ty.weaken() }
  });
}

pub fn AST::tidy(self: AST) -> AST {
  self.remove_leaf().weaken();
}

pub fn Type::map(self: Type, f: (Type) -> Type) -> Type {
  let mapper = fn (x: Type) { x.map(f) }
  f(match self {
    Option(x) => Option(x.map(f))
    Tuple(arr) => Tuple(arr.map(mapper))
    Function(args, ret) => Function(args.map(mapper), ret.map(f))
    FixedArray(x) => FixedArray(x.map(f))
    Enum(name, arr) => Enum(name, arr.map(mapper))
    Struct(name, arr) => Struct(name, arr.map(mapper))
    Named(name, arr) => Named(name, arr.map(mapper))
    Weak(x) => Weak({ val: x.val.map(f) })
    Unknown | Int | Double | Float | Char | Bool | Typevar(_) | Unit => self
  })
}

pub fn Type::deweak(self: Type) -> Type {
  self.map(fn {
    Weak(x) => x.val;
    c => c
  });
}

pub fn Type::weaken(self: Type) -> Type {
  self.map(fn {
    Unknown => Weak(Ref::new(Unknown))
    c => c
  })
}

pub fn Type::weak() -> Type {
  Weak(Ref::new(Unknown))
}
