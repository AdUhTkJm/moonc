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
}

pub(all) enum UnaryKind {
  Not
  Minus
}

pub(all) enum ASTType {
  FnDecl(String, Array[AST], AST)
  ParamDecl(String)
  VarDecl(String, AST)
  If(AST, AST, Option[AST])
  Binary(BinaryKind, AST, AST)
  Block(Array[AST])
  VarRef(String)
  Return(AST)
  Int(Int)
  Leaf
}

pub(all) enum Type {
  Named(String, Array[Type])
  TypeParam(String, Array[Type])
  FixedArray(Type)
  Int
  Float
  Unknown
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

fn dep_str(ast: ASTType, depth: Int) -> String {
  match ast {
    Int(vi) => "\{vi}"
    VarRef(name) => name
    Block(arr) => {
      let builder = StringBuilder::new();
      let indent = String::make(2 * (depth - 1), ' ');
      builder.write_string("{\n");
      for x in arr {
        builder.write_string("  \{indent}\{dep_str(x.kind, depth)};\n");
      }
      builder.write_string("\{indent}}\n");
      builder.to_string();
    }
    Binary(kind, l, r) => "(\{dep_str(l.kind, depth)} \{kind} \{dep_str(r.kind, depth)})"
    VarDecl(name, init) => "let \{name} = \{dep_str(init.kind, depth)}"
    ParamDecl(name) => name
    FnDecl(name, params, body) => {
      let builder = StringBuilder::new();
      let params = params.map(fn (x) { x.kind.to_string() }).join(", ");
      builder.write_string("fn \{name}(\{params}) ");
      builder.write_string(dep_str(body.kind, depth + 1));
      builder.to_string();
    }
    If(cond, l, r) => {
      let builder = StringBuilder::new();
      builder.write_string("if \{cond} ");
      builder.write_string(dep_str(l.kind, depth + 1));
      builder.write_string(r.map_or("", fn(x) { dep_str(x.kind, depth + 1) }));
      builder.to_string();
    }
    Return(ast) => "return \{dep_str(ast.kind, depth)}"
    Leaf => "<leaf>"
  }
}

pub impl Show for ASTType with to_string(self) -> String {
  dep_str(self, 0);
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

pub fn ASTType::map(self: ASTType, f: (ASTType) -> ASTType) -> ASTType {
  match self {
    FnDecl(name, params, body) => f(FnDecl(name, params.map(fn (x) { x.map(f) }), body.map(f)))
    VarDecl(name, init) => f(VarDecl(name, init.map(f)))
    If(cond, l, r) => f(If(cond.map(f), l.map(f), r.map(fn (x) { x.map(f) })))
    Binary(kind, l, r) => f(Binary(kind, l.map(f), r.map(f)))
    Block(body) => f(Block(body.map(fn (x) { x.map(f) })))
    Return(x) => f(Return(x.map(f)))
    _ => f(self)
  }
}

pub fn AST::map(self: AST, f: (ASTType) -> (ASTType)) -> AST {
  { kind: self.kind.map(f), from: self.from, to: self.to, ty: self.ty }
}

pub fn AST::remove_leaf(self: AST) -> AST {
  self.map(fn (x) {
    match x {
      Block(arr) => Block(arr.filter(fn (x) { not(x.kind is Leaf) }))
      _ => x
    }
  })
}
