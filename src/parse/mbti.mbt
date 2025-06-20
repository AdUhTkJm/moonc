///|
/// A package detail.
/// 
pub struct PackDetail {
  fullname: String
  referred: String
  _fns: Array[FnDetail]
  _structs: Array[StructDetail]
  _enums: Array[EnumDetail]
  _impls: Array[ImplDetail]
  _traits: Array[TraitDetail]
}


///|
/// Parses `.mbti` style function declarations.
/// 
/// It's a variant of `fndecl()`, without body and without checking for lambdas.
/// 
/// Moreover, it's quite the same with the function declarations in traits.
/// 
pub fn Parser::mbti_fn(self: Parser, vis: Visible) -> FnDetail {
  let detail = self.trait_fn();
  { ..detail, vis }
}

pub fn Parser::mbti_impl(self: Parser, vis: Visible) -> ImplDetail {
 let tyvars = self.tyvars();

  self.strip();
  let ntrait = self.qualified_typename();

  self.expects(For);
  self.strip();
  let nstruct = self.typename();

  let body = AST::new(Leaf, Loc::unknown(), Loc::unknown());

  // This is a stub. We need to first parse traits to fill things in.
  {
    vis, ext: None,
    nstruct, ntrait, nfunc: "<all>", params: [], body, tyvars,
    ty: Unknown
  };
}

pub fn Parser::mbti_toplevel(self: Parser) -> PackDetail {
  self.expects(Package);
  
  let fullname = if (self.consumes().ty is Str(w)) {
    w
  } else {
    @diag.error(self.last().loc, self.loc(), "expected package fullname");
    ""
  }

  let referred = if (fullname.contains("/")) {
    fullname.split("/").last().unwrap().to_string();
  } else { "" }

  let _fns = [];
  let _structs = [];
  let _enums = [];
  let _impls = [];
  let _traits = [];
  let mut vis: Visible = Pub;

  while (not(self.eof())) {
    let tok = self.consumes();
    match tok.ty {
      Fn => _fns.push(self.mbti_fn(vis));
      Impl => _impls.push(self.mbti_impl(vis));
      Struct => {
        let ast = self.structdecl(vis, None);
        guard ast.kind is StructDecl(detail)
        _structs.push(detail);
      }
      Enum => {
        let ast = self.enumdecl(vis, None);
        guard ast.kind is EnumDecl(detail)
        _enums.push(detail);
      }
      Type => {
        let ast = self.tydecl(vis, None, false);
        guard ast.kind is EnumDecl(detail)
        _enums.push(detail);
      }
      Trait => {
        let ast = self.traitdecl(vis);
        guard ast.kind is TraitDecl(detail)
        _traits.push(detail);
      }
      Priv | Pub | Puball | Pubopen => {
        self.retrace();
        vis = self.vis();
      }
      Attribute(name) => {
        @diag.warning(tok.loc, tok.loc.advance(tok.len), WUnknownAttribute(name));
      }
      _ => {
        @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected toplevel token \{tok.ty}");
      }
    }
  }

  { fullname, referred, _fns, _structs, _enums, _impls, _traits };
}

///|
/// Entry point of parsing a `.mbti` interface file.
/// 
pub fn Parser::load_mbti(filename: String, tokens: Array[Token]) -> PackDetail {
  let parser = Parser::new(filename, tokens);
  parser.mbti_toplevel();
}
