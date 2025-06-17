pub typealias @parse.(Type, Typevar, Name);
typealias @parse.(AST, StructDetail, EnumDetail, Visible);
typealias @utils.Map;
typealias @diag.Loc;

pub struct LocalDetail {
  name: String
  mutable: Bool
  ty: Type
}

pub struct GlobalDecl {
  name: Name
  ty: Type
  vis: Visible
}

pub struct FnDetail {
  name: Name
  params: Array[String]
  tyvars: Array[Typevar]
  vis: Visible
  ty: Type
}

pub(all) struct Env {
  // These underscores are to avoid Moonbit's VSCode plugin identifying `struct`, `enum` etc too quickly.
  // The flickering is very annoying.
  _locals: Map[String, LocalDetail]
  _structs: Map[Name, StructDetail]
  _enums: Map[Name, EnumDetail]
  _globals: Map[Name, GlobalDecl]
  _fns: Map[Name, FnDetail]
  mut curr_fn: Name?
  mut ast: AST
}

pub fn Env::bind(self: Env, x: AST) -> Unit {
  x.visit(fn (x) { match x.kind {
    GlobalDecl(detail) => self._globals[detail.name] = {
      name: detail.name,
      ty: x.ty,
      vis: detail.vis
    };

    StructDecl(detail) => self._structs[detail.name] = detail;
    EnumDecl(detail) => self._enums[detail.name] = detail;

    FnDecl(detail) => self._fns[detail.name] = {
      name: detail.name,
      params: detail.params,
      tyvars: detail.tyvars,
      vis: detail.vis,
      ty: x.ty
    };
    _ => ()
  } });
  self.ast = x;
}

pub fn Env::empty() -> Env {
  {
    _locals: Map::new(),
    _globals: Map::new(),
    _structs: Map::new(),
    _enums: Map::new(),
    _fns: Map::new(),
    curr_fn: None,
    ast: AST::new(Leaf, Loc::unknown(), Loc::unknown())
  }
}

pub fn Env::clone(self: Env) -> Env {
  {
    ..self,
    _locals: self._locals.clone(),
    _globals: self._globals.clone(),
    _structs: self._structs.clone(),
    _enums: self._enums.clone(),
    _fns: self._fns.clone(),
  }
}

pub fn Env::new(x: AST) -> Env {
  let z = Env::empty();
  z.bind(x);
  z
}
