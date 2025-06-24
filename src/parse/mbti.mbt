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
  _abstracts: Array[AbstractDetail]
}


///|
/// Parses `.mbti` style function declarations.
/// 
/// It's a variant of `fndecl()`, without body and without checking for lambdas.
/// 
pub fn Parser::mbti_fn(self: Parser, vis: Visible) -> FnDetail {
  self.strip();
  
  let tyvars = self.tyvars();
  let hasname = self.peek().isa(Ident(""));
  let hastypename = self.peek().isa(Typename(""));

  let name = if (hasname) {
    unqualified(self.expect_ident())
  } else if (hastypename) {
    let ns = self.expect_typename();
    self.expect(ColonColon);
    let name = self.expect_ident();
    qualified(ns, name);
  } else {
    @diag.error(self.last().loc, self.loc(), "expected function name");
    unqualified("")
  };

  let params = [];
  let argTys = [];
  let kwargs = [];

  self.expects(LPar);
  self.strip();
  let mut i = 0;
  while (not(self.checks(RPar)) && not(self.eof())) {
    let mut argname = "_\{i}";
    let mut is_kwarg = false;
    let mut is_opt = false;
    let mut ty = Type::Unknown;

    let loc = self.peek().loc;
    if (self.peeks().ty is Ident(w)) {
      self.advance();
      argname = w;
      is_kwarg = self.checks(Tilde);
      is_opt = self.checks(Ques);
      if (is_kwarg && is_opt) {
        @diag.error(loc, self.loc(), "modifiers '~' and '=' cannot appear together")
      }
      self.expects(Colon);
      ty = self.typename().variate(tyvars);
    } else {
      ty = self.typename().variate(tyvars);
    }
    
    if (is_kwarg) {
      let mut default = None;
      // No assignment (default value) is allowed.
      if (self.checks(Assign)) {
        let tok = self.consumes();
        if (not(tok.ty is Expand) && not(tok.ty is Ident("_"))) {
          @diag.error(tok.loc, tok.loc.advance(tok.len), "default argument in declaration should be a placeholder '..' or '_'");
        }
        default = Some(AST::leaf());
      }
      kwargs.push({ name: argname, ty, default });
    } else if (is_opt) {
      kwargs.push({ name: argname, ty: Option(ty), default: None });
    } else {
      params.push(argname);
      argTys.push(ty);
    }

    if (not(self.peeks().isa(RPar))) {
      self.expect(Comma);
    }

    i = i + 1;
  }
  
  // The return type is not optional.
  let mut retTy = Type::Unknown;
  self.expects(Arrow);
  retTy = self.typename();
  

  let ty = Function(argTys, retTy).variate(tyvars);
  let body = AST::new(Block([]), Loc::unknown(), Loc::unknown());
  return { vis, name, params, tyvars, body, ty, kwargs, ext: None };
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
    "@" + fullname.split("/").last().unwrap().to_string();
  } else { "" }

  let _fns = [];
  let _structs = [];
  let _enums = [];
  let _impls = [];
  let _traits = [];
  let _abstracts = [];
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
        if (ast.kind is EnumDecl(detail)) {
          _enums.push(detail);
        } else {
          guard ast.kind is AbstractDecl(detail);
          _abstracts.push(detail);
        }
      }
      Suberror => {
        let ast = self.tydecl(vis, None, true);
        if (ast.kind is EnumDecl(detail)) {
          _enums.push(detail);
        } else {
          guard ast.kind is AbstractDecl(detail);
          _abstracts.push(detail);
        }
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
      EOF => break;
      _ => {
        @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected toplevel token \{tok.ty}");
      }
    }
  }

  { fullname, referred, _fns, _structs, _enums, _impls, _traits, _abstracts };
}

///|
/// Entry point of parsing a `.mbti` interface file.
/// 
pub fn Parser::load_mbti(filename: String, tokens: Array[Token]) -> PackDetail {
  let parser = Parser::new(filename, tokens);
  parser.mbti_toplevel();
}
