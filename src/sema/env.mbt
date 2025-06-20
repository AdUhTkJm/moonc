pub typealias @parse.(Type, Typevar, Name, PackDetail);
typealias @parse.(AST, StructDetail, EnumDetail, TraitDetail, Visible, Kwarg);
typealias @utils.Map;
typealias @diag.Loc;

pub struct LocalDetail {
  name: String
  mutable: Bool
  ty: Type
} derive(Show)

pub struct GlobalDecl {
  name: Name
  ty: Type
  vis: Visible
} derive(Show)

pub struct FnDetail {
  name: Name
  params: Array[String]
  kwargs: Array[Kwarg]
  tyvars: Array[Typevar]
  vis: Visible
  ty: Type
} derive(Show)

pub(all) struct Env {
  // These underscores are to avoid Moonbit's VSCode plugin identifying `struct`, `enum` etc too quickly.
  // The flickering is very annoying.
  _locals: Map[String, LocalDetail]
  _structs: Map[Name, StructDetail]
  _enums: Map[Name, EnumDetail]
  _globals: Map[Name, GlobalDecl]
  _fns: Map[Name, FnDetail]
  _traits: Map[Name, TraitDetail];
  curr_fn: Name?
  curr_for: AST?
  mut ast: AST
}

///|
/// Binds a new AST **without** clearing existing information.
/// 
pub fn Env::bind(self: Env, x: AST) -> Unit {
  x.visit(x => { match x.kind {
    GlobalDecl(detail) => self._globals[detail.name] = {
      name: detail.name,
      ty: detail.ty,
      vis: detail.vis
    };

    StructDecl(detail) => self._structs[detail.name] = detail;
    EnumDecl(detail) => self._enums[detail.name] = detail;

    FnDecl(detail) => self._fns[detail.name] = {
      name: detail.name,
      params: detail.params,
      tyvars: detail.tyvars,
      kwargs: detail.kwargs,
      vis: detail.vis,
      ty: detail.ty
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
    _traits: Map::new(),
    curr_fn: None,
    curr_for: None,
    ast: AST::new(Leaf, Loc::unknown(), Loc::unknown())
  }
}

///|
/// A deep copy. A direct `{ ..self }` will only shallow copy the 
/// contents of the maps.
/// 
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

///|
/// Finds out the type of a method `name` in the struct `sty`.
/// 
/// If there's no such struct or no such method, returns `None`.
/// 
pub fn Env::method_ty(self: Env, sty: Name, name: String) -> Type? {
  let qualified = Name :: { pack: sty.pack, ns: Some(sty.name), name };
  if (self._fns.contains(qualified)) {
    return Some(self._fns[qualified].ty);
  }
  return None;
}

///|
/// Loads a package into this typing environment.
/// 
/// To produce a PackDetail argument, see `Parser::load_mbti`, which parses
/// the `.mbti` interface file.
/// 
pub fn Env::load(self: Env, detail: PackDetail) -> Unit {
  let { fullname: _, referred, _fns, _structs, _enums, _impls, _traits } = detail;
  for _fn in _fns {
    let name = _fn.name.pack(referred);
    self._fns[name] = {
      name,
      vis: _fn.vis,
      params: _fn.params,
      kwargs: _fn.kwargs,
      tyvars: _fn.tyvars,
      ty: _fn.ty, 
    };
  }
  for _enum in _enums {
    let name = _enum.name.pack(referred);
    self._enums[name] = { .._enum, name };
  }
  for _struct in _structs {
    let name = _struct.name.pack(referred);
    self._structs[name] = { .._struct, name };
  }
  for _trait in _traits {
    let name = _trait.name.pack(referred);
    self._traits[name] = { .._trait, name };
  }
  // TODO: impls
}
