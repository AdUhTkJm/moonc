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
} derive(Eq, Hash)

pub(all) enum UnaryKind {
  Not
  Minus
  Try
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
}

pub(all) enum Pattern {
  IncRange(Pattern, Pattern)
  ExcRange(Pattern, Pattern)
  Char(Char)
  Int(Int)
  Str(String)
  Enum(String, Array[String])
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

pub(all) enum ASTType {
  FnDecl(Visible, Name, Array[String], AST)
  StructDecl(Visible, Name, Array[(String, Type)])
  StructInit(Map[String, AST])
  ParamDecl(String)
  VarDecl(String, Bool, AST)
  EnumDecl(Visible, Name, Array[(String, Array[Type])])
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
  Call(AST, Array[AST])
  ThisCall(AST, String, Array[AST])
  Double(Double)
  Float(Float)
  Str(String)
  Fstr(Array[AST])
  Bool(Bool)
  Arr(Array[AST])
  Continue
  Break(Option[AST])
  While(AST, AST, Option[AST])
  For(String, AST, AST, AST, AST, Option[AST])
  ForIn(String, AST, AST, Option[AST])
  Match(AST, Array[(Pattern, AST)])
  IncRange(AST, AST)
  ExcRange(AST, AST)
  ArrAccess(AST, AST)
  Leaf
}

pub(all) enum Type {
  Named(String, Array[Type])
  FixedArray(Type)
  Function(Array[Type], Type)
  Tuple(Array[Type])
  Int
  Float
  Unit
  Double
  Unknown
  Weak(Type)
} derive (Show)

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
      let params = arr.join(", ");
      let params = if (params.length() == 0) { "" } else { "(\{params})" }
      "\{x}\{params}"
    }
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

fn dep_str(ast: AST, depth: Int) -> String {
  match ast.kind {
    Int(vi) => "\{vi}"
    Double(vd) => "\{vd}"
    Float(vf) => "\{vf}F"
    Str(vs) => "R\"(\{vs})\""
    VarRef(name) => "\{name}"
    Bool(vb) => "\{vb}"
    Fstr(vs) => "F:" + vs.map(fn (x) { dep_str(x, depth) }).join("") + ":F"
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
    BinaryInplace(kind, l, r) => "\{dep_str(l, depth)} \{kind}= \{dep_str(r, depth)}"
    Unary(kind, l) => "(\{kind}\{dep_str(l, depth)})"
    VarDecl(name, mutable, init) => {
      let mutable = @utils.ite(mutable, "mut ", "");
      "let \{mutable}\{name} = \{dep_str(init, depth)}"
    }
    ParamDecl(name) => name
    FnDecl(visible, name, params, body) => {
      let builder = StringBuilder::new();
      let params = params.join(", ");
      let params = @utils.ite(["main", "test", "init"].contains(name.name), params, "(\{params})");
      let visible = @utils.ite(visible == Priv, "", "\{visible} ")
      builder.write_string("\{visible}fn \{name}\{params} ");
      builder.write_string(dep_str(body, depth));
      builder.to_string();
    }
    StructDecl(visible, name, fields) => {
      let builder = StringBuilder::new();
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let fields = fields.map(fn (t) { let (x, y) = t; "\{x}: \{y}" }).join("\n  \{indent}");
      let visible = @utils.ite(visible == Priv, "", "\{visible} ")
      builder.write_string("\{visible}struct \{name} {\n  \{indent}");
      builder.write_string(fields);
      builder.write_string("\n\{indent}}");
      builder.to_string();
    }
    EnumDecl(visible, name, variants) => {
      let builder = StringBuilder::new();
      let indent = String::make(@math.maximum(2 * depth - 2, 0), ' ');
      let fields = variants.map(fn (t) {
        let (x, y) = t;
        let s = y.map(Type::to_string).join(", ");
        let s = if (s.length() == 0) { "" } else { "(\{s})" }
        "\{x}\{s}"
      }).join("\n  \{indent}");
      
      let visible = @utils.ite(visible == Priv, "", "\{visible} ")
      builder.write_string("\{visible}struct \{name} {\n  \{indent}");
      builder.write_string(fields);
      builder.write_string("\n\{indent}}");
      builder.to_string();
    }
    StructInit(map) => {
      let fields = map.to_array().map(fn (t) {
        let (x, y) = t;
        "\{x}: \{dep_str(y, depth)}"
      }).join(", ");
      "{ \{fields} }";
    }
    If(cond, l, r) => {
      let builder = StringBuilder::new();
      builder.write_string("if \{cond} ");
      builder.write_string(dep_str(l, depth));
      builder.write_string(r.map_or("", fn(x) { dep_str(x, depth) }));
      builder.to_string();
    }
    Return(ast) => {
      match ast {
        None => "return";
        Some(ast) => "return \{dep_str(ast, depth)}"
      }
    }
    Call(call, args) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      "\{dep_str(call, depth)}(\{args})";
    }
    ThisCall(this, name, args) => {
      let args = args.map(fn (x) { dep_str(x, depth) }).join(", ");
      "\{dep_str(this, depth)}.\{name}(\{args})";
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
      let v = exit.map_or("", fn (x) { "else \{dep_str(x, depth)}" });
      "while \{dep_str(cond, depth)} \{dep_str(body, depth)} \{v}";
    }
    For(name, start, stop, step, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{name} = \{dep_str(start, depth)}; \{dep_str(stop, depth)}; \{name} = \{dep_str(step, depth)} \{dep_str(body, depth)}\{v}"
    }
    ForIn(name, range, body, exit) => {
      let v = exit.map_or("", fn (x) { " else \{dep_str(x, depth)}" });
      "for \{name} in \{dep_str(range, depth)}; \{dep_str(body, depth)} \{dep_str(body, depth)}\{v}"
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

pub fn AST::map(self: AST, f: (AST) -> AST) -> AST {
  f({ kind:
  match self.kind {
    FnDecl(visible, name, params, body) => FnDecl(visible, name, params, body.map(f))
    VarDecl(name, mutable, init) => VarDecl(name, mutable, init.map(f))
    If(cond, l, r) => If(cond.map(f), l.map(f), r.map(f))
    Binary(kind, l, r) => Binary(kind, l.map(f), r.map(f))
    BinaryInplace(kind, l, r) => BinaryInplace(kind, l.map(f), r.map(f))
    Unary(kind, l) => Unary(kind, l.map(f))
    Block(body) => Block(body.map(f))
    Return(x) => Return(x.map(f))
    Call(x, args) => Call(x.map(f), args.map(f));
    ThisCall(x, name, args) => ThisCall(x.map(f), name, args.map(f));
    FieldRef(x, name) => FieldRef(x.map(f), name)
    StructInit(map) => StructInit(Map::from_array(map.to_array().map(fn (t) { (t.0, t.1.map(f)) })))
    Arr(arr) => Arr(arr.map(f))
    Break(val) => Break(val.map(f))
    While(cond, body, exit) => While(cond.map(f), body.map(f), exit.map(f))
    For(name, start, stop, step, body, exit) => For(name, start.map(f), stop.map(f), step.map(f), body.map(f), exit.map(f))
    ForIn(indvar, range, body, exit) => ForIn(indvar, range.map(f), body.map(f), exit.map(f));
    EnumConstr(name, arr) => EnumConstr(name, arr.map(f))
    IncRange(x, y) => IncRange(x.map(f), y.map(f))
    ExcRange(x, y) => ExcRange(x.map(f), y.map(f))
    ArrAccess(x, y) => ArrAccess(x.map(f), y.map(f))
    Match(matcher, arr) => Match(matcher.map(f), arr.map(fn (t) { (t.0, t.1.map(f)) }))
    Fstr(vs) => Fstr(vs.map(f))
    Int(_) | VarRef(_) | ParamDecl(_) | Leaf |
    StructDecl(_) | Double(_) | Float(_) | Str(_) |
    Continue | EnumDecl(_) | Bool(_) => self.kind
  },
    from: self.from,
    to: self.to,
    ty: self.ty
  });
}

pub fn AST::remove_leaf(self: AST) -> AST {
  self.map(fn (x) {
    match x {
      { kind: Block(arr), .. } => { kind: Block(arr.filter(fn (x) { not(x.kind is Leaf) })), from: x.from, to: x.to, ty: x.ty }
      _ => x
    }
  })
}
