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
} derive(Eq, Hash)

pub(all) enum UnaryKind {
  Not
  Minus
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

pub fn Name::unqualified(pack: Option[String], x: String) -> Name {
  { pack: pack, namespace: None, name: x }
}

pub fn Name::qualified(pack: Option[String], namespace: String, x: String) -> Name {
  { pack: pack, namespace: Some(namespace), name: x }
}

pub(all) enum ASTType {
  FnDecl(Visible, Name, Array[String], AST)
  StructDecl(Visible, String, Array[(String, Type)])
  StructInit(Map[String, AST])
  ParamDecl(String)
  VarDecl(String, Bool, AST)
  If(AST, AST, Option[AST])
  Binary(BinaryKind, AST, AST)
  BinaryInplace(BinaryKind, AST, AST)
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
  }
}

pub impl Show for BinaryKind with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub impl Show for UnaryKind with to_string(self) -> String {
  match self {
    Not => "!"
    Minus => "-"
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

pub impl Show for Name with to_string(self) -> String {
  let builder = StringBuilder::new();
  if (self.pack is Some(pack)) {
    builder.write_string("@\{pack}.");
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

fn dep_str(ast: ASTType, depth: Int) -> String {
  match ast {
    Int(vi) => "\{vi}"
    Double(vd) => "\{vd}"
    Float(vf) => "\{vf}F"
    Str(vs) => "R\"(\{vs})\""
    VarRef(name) => "\{name}"
    Block(arr) => {
      let builder = StringBuilder::new();
      let indent = String::make(@math.maximum(2 * (depth - 1), 0), ' ');
      builder.write_string("{\n");
      for x in arr {
        builder.write_string("  \{indent}\{dep_str(x.kind, depth + 1)};\n");
      }
      builder.write_string("\{indent}}");
      builder.to_string();
    }
    Binary(kind, l, r) => "(\{dep_str(l.kind, depth)} \{kind} \{dep_str(r.kind, depth)})"
    BinaryInplace(kind, l, r) => "\{dep_str(l.kind, depth)} \{kind}= \{dep_str(r.kind, depth)}"
    VarDecl(name, mutable, init) => {
      let mutable = @utils.ite(mutable, "mut ", "");
      "let \{mutable}\{name} = \{dep_str(init.kind, depth)}"
    }
    ParamDecl(name) => name
    FnDecl(visible, name, params, body) => {
      let builder = StringBuilder::new();
      let params = params.join(", ");
      let params = @utils.ite(["main", "test", "init"].contains(name.name), params, "(\{params})");
      let visible = @utils.ite(visible == Priv, "", "\{visible} ")
      builder.write_string("\{visible}fn \{name}\{params} ");
      builder.write_string(dep_str(body.kind, depth));
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
    StructInit(map) => {
      let fields = map.to_array().map(fn (t) {
        let (x, y) = t;
        "\{x}: \{dep_str(y.kind, depth)}"
      }).join(", ");
      "{ \{fields} }";
    }
    If(cond, l, r) => {
      let builder = StringBuilder::new();
      builder.write_string("if \{cond} ");
      builder.write_string(dep_str(l.kind, depth));
      builder.write_string(r.map_or("", fn(x) { dep_str(x.kind, depth) }));
      builder.to_string();
    }
    Return(ast) => {
      match ast {
        None => "return";
        Some(ast) => "return \{dep_str(ast.kind, depth)}"
      }
    }
    Call(call, args) => {
      let args = args.map(fn (x) { dep_str(x.kind, depth) }).join(", ");
      "\{dep_str(call.kind, depth)}(\{args})";
    }
    ThisCall(this, name, args) => {
      let args = args.map(fn (x) { dep_str(x.kind, depth) }).join(", ");
      "\{dep_str(this.kind, depth)}.\{name}(\{args})";
    }
    FieldRef(x, name) => "\{dep_str(x.kind, depth)}.\{name}"
    Leaf => "<leaf>"
  }
}

pub impl Show for ASTType with to_string(self) -> String {
  dep_str(self, 1);
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
  let mapper = fn (x: AST) { x.map(f) };
  f({ kind:
  match self.kind {
    FnDecl(visible, name, params, body) => FnDecl(visible, name, params, body.map(f))
    VarDecl(name, mutable, init) => VarDecl(name, mutable, init.map(f))
    If(cond, l, r) => If(cond.map(f), l.map(f), r.map(mapper))
    Binary(kind, l, r) => Binary(kind, l.map(f), r.map(f))
    BinaryInplace(kind, l, r) => BinaryInplace(kind, l.map(f), r.map(f))
    Block(body) => Block(body.map(mapper))
    Return(x) => Return(x.map(mapper))
    Call(x, args) => Call(x.map(f), args.map(mapper));
    ThisCall(x, name, args) => ThisCall(x.map(f), name, args.map(mapper));
    FieldRef(x, name) => FieldRef(x.map(f), name)
    StructInit(map) => StructInit(Map::from_array(map.to_array().map(fn (t) { (t.0, t.1.map(f)) })))
    Int(_) | VarRef(_) | ParamDecl(_) | Leaf |
    StructDecl(_) | Double(_) | Float(_) | Str(_) => self.kind
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
