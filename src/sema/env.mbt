pub typealias @parse.(Type, Typevar, Name, PackDetail);
typealias @parse.(AST, StructDetail, EnumDetail, TraitDetail, AbstractDetail, Visible, Kwarg);
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
  _traits: Map[Name, TraitDetail]
  _abstracts: Map[Name, AbstractDetail]
  // Maps a short-hand name into its full name (or another name in `exposed`).
  exposed: Map[Name, Name]
  // We only map names of tyvars into the type itself.
  tyvars: Map[String, Type]
  // Also, map names to tyvars into the traits they'd need to implement.
  tyvar_traits: Map[String, Array[Name]]
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
    _abstracts: Map::new(),
    exposed: Map::new(),
    tyvars: Map::new(),
    tyvar_traits: Map::new(),
    curr_fn: None,
    curr_for: None,
    ast: AST::leaf()
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
  let { fullname, referred, _fns, _structs, _enums, _impls, _traits, _abstracts } = detail;
  for _fn in _fns {
    let name = _fn.name.pack(referred);
    self._fns[name] = {
      name,
      vis: _fn.vis,
      params: _fn.params,
      kwargs: _fn.kwargs,
      tyvars: _fn.tyvars,
      ty: _fn.ty.resolve_self(_fn.name.ns), 
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
  for _abstract in _abstracts {
    let name = _abstract.name.pack(referred);
    self._abstracts[name] = { .._abstract, name };
  }
  // TODO: impls

  if (fullname == "moonbitlang/core/builtin") {
    for _fn in _fns {
      self.exposed[_fn.name] = _fn.name.pack(referred);
    }
    for _enum in _enums {
      self.exposed[_enum.name] = _enum.name.pack(referred);
    }
    for _struct in _structs {
      self.exposed[_struct.name] = _struct.name.pack(referred);
    }
    for _trait in _traits {
      self.exposed[_trait.name] = _trait.name.pack(referred);
    }
    for _abstract in _abstracts {
      self.exposed[_abstract.name] = _abstract.name.pack(referred);
    }
  }
}

pub fn Env::resolve(self: Env, name: Name) -> Name {
  if (not(self.exposed.contains(name))) {
    return name;
  }
  self.exposed[name] = self.resolve(self.exposed[name]);
  return self.exposed[name];
}
