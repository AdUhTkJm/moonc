pub(all) struct Variable {
  name: String
  ty: Type
} derive (Show)

pub(all) enum BinaryKind {
  Add
  Sub
  Mul
  Div
  Mod
} derive (Show)

pub(all) enum UnaryKind {
  Not
  Minus
} derive (Show)

pub(all) enum ASTType {
  FnDecl(Array[AST], AST)
  ParamDecl(String)
  VarDecl(String, AST)
  Binary(BinaryKind, AST, AST)
  Block(Array[AST])
  VarRef(String)
  Int(Int)
  Leaf
} derive (Show)

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
} derive (Show)

pub fn AST::new(kind: ASTType, from: @diag.Loc, to: @diag.Loc) -> AST {
  return {
    kind: kind,
    ty: Unknown,
    from: from,
    to: to
  }
}
