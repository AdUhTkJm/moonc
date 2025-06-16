pub struct Parser {
  mut place: Int
  data: Array[Token]
  pack: Option[String]
}

pub fn Parser::new(pack: Option[String], tokens: Array[Token]) -> Parser {
  return { place: 0, data: tokens, pack: pack }
}

pub fn Parser::eof_loc(self: Parser) -> @diag.Loc {
  return self.data.last().unwrap().loc;
}

pub fn Parser::loc(self: Parser) -> @diag.Loc {
  if (self.place == 0) {
    return self.data[0].loc.advance(self.data[0].len);
  }
  let tok = self.data[self.place - 1];
  return tok.loc.advance(tok.len);
}

pub fn Parser::consume(self: Parser) -> Token {
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }

  let t = self.data[self.place];
  self.place += 1;
  return t;
}

pub fn Parser::peek(self: Parser) -> Token {
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }

  self.data[self.place]
}

pub fn Parser::retrace(self: Parser) -> Unit {
  self.place -= 1;
}

pub fn Parser::check(self: Parser, ty: TokenType) -> Bool {
  let old = self.place;
  if (not(self.consume().isa(ty))) {
    self.place = old;
    return false;
  }
  return true;
}

pub fn Parser::expect(self: Parser, ty: TokenType) -> Unit {
  let tok = self.consume();
  if (not(tok.isa(ty))) {
    @diag.error(tok.loc, tok.loc.advance(tok.len), "expected \{ty}, but got \{tok.ty}");
  }
}

pub fn Parser::expect_ident(self: Parser) -> String {
  match self.consume() {
    { ty: Ident(x), .. } => x
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "reached EOF on recovery");
      ""
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "expected identifier, but got \{tok.ty}");
      self.expect_ident();
    }
  }
}

pub fn Parser::expect_typename(self: Parser) -> String {
  match self.consume() {
    { ty: Typename(x), .. } => x
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "reached EOF on recovery");
      ""
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "expected identifier, but got \{tok.ty}");
      self.expect_ident();
    }
  }
}

pub fn Parser::strip(self: Parser) -> Unit {
  while (self.place < self.data.length() && self.data[self.place].isa(Newline)) {
    self.place += 1;
  }
}

pub fn Parser::ignore_until(self: Parser, stop: Array[TokenType]) -> Unit {
  stop.push(EOF);
  for c = self.consume(); not(c.is_any(stop)); c = self.consume() { }
}

pub fn Parser::unqualified(self: Parser, x: String) -> Name {
  Name::unqualified(self.pack, x);
}

pub fn Parser::qualified(self: Parser, namespace: String, x: String) -> Name {
  Name::qualified(self.pack, namespace, x);
}

pub fn Parser::basetype(self: Parser) -> Type {
  let ty = self.expect_typename();
  match (ty) {
    "Int" => Int
    "Float" => Float
    "Double" => Double
    "Unit" => Unit
    _ => Named(ty, [])
  }
}

pub fn Parser::typename(self: Parser) -> Type {
  self.strip();
  if (self.check(LPar)) {
    let args = [];
    while (not(self.check(RPar)) && not(self.peek().isa(EOF))) {
      let ty = self.typename();
      args.push(ty);
      if (not(self.peek().isa(RPar))) {
        self.expect(Comma);
      }
    }
    if (not(self.check(Arrow))) {
      return Tuple(args);
    }
    let ret = self.typename();
    return Function(args, ret);
  }
  let from = self.peek().loc;
  let ty = self.basetype();
  if (self.check(LBracket)) {
    // Type arguments
    let args = [];
    while (not(self.check(RBracket)) && not(self.peek().isa(EOF))) {
      let argTy = self.typename();
      args.push(argTy);
      if (not(self.peek().isa(RBracket))) {
        self.expect(Comma);
      }
      self.strip();
    }

    if (ty is Named(x, [])) {
      return Named(x, args);
    } else {
      @diag.error(from, self.loc(), "builtin type \{ty} does not accept parameters");
      return ty;
    }
  }
  return ty;
}

pub fn Parser::visible(self: Parser) -> Visible {
  let tok = self.consume();
  match (tok.ty) {
    Pub => Pub
    _ => { self.retrace(); Priv }
  }
}

pub fn Parser::ifexpr(self: Parser) -> AST {
  let from = self.peek().loc;

  // The initial `if` is already consumed.
  let cond = self.expr();
  let body = self.block();
  let mut other = None;
  if (self.check(Else)) {
    other = Some(self.block());
  }
  AST::new(If(cond, body, other), from, self.loc());
}

pub fn Parser::primary(self: Parser) -> AST {
  let from = self.peek().loc;
  let tok = self.consume();
  match (tok.ty) {
    Ident(name) => AST::new(VarRef(self.unqualified(name)), from, self.loc());
    Int(vi) => AST::new(Int(vi), from, self.loc());
    Double(vd) => AST::new(Double(vd), from, self.loc());
    Float(vf) => AST::new(Float(vf), from, self.loc());
    Str(vs) => AST::new(Str(vs), from, self.loc());
    LPar => {
      let what = self.expr();
      self.expect(RPar);
      what;
    }
    LBrace => {
      let old = self.place;
      self.strip();
      if (self.check(Ident(""))) {
        self.strip();
        // A struct initializer.
        if (self.check(Colon)) {
          self.place = old;
          self.strip();
          let map = Map::new();
          while (not(self.check(RBrace)) && not(self.peek().isa(EOF))) {
            let ident = self.expect_ident();
            self.expect(Colon);
            let init = self.expr();
            map[ident] = init;
            if (not(self.peek().isa(RBrace))) {
              self.expect(Comma);
            }
            self.strip();
          }
          return AST::new(StructInit(map), from, self.loc());
        }
      }
      self.place = old - 1;
      self.block();
    }
    If => self.ifexpr();
    Fn => self.fndecl(Priv);
    Typename(ty) => {
      // Ty::field
      self.expect(ColonColon);
      let name = self.expect_ident();
      AST::new(VarRef(self.qualified(ty, name)), from, self.loc());
    }
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected token \{tok.ty}");
      self.ignore_until([Semicolon, Let, RBrace, Newline]);
      AST::new(Leaf, tok.loc, tok.loc);
    }
  }
}

pub fn Parser::postfix(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.primary();
  
  while (self.peek().is_any([LPar, Dot])) {
    if (self.check(Dot)) {
      let field = self.expect_ident();
      n = AST::new(FieldRef(n, field), from, self.loc());
      continue;
    }

    if (self.check(LPar)) {
      let args = [];
      while (not(self.check(RPar)) && not(self.peek().isa(EOF))) {
        args.push(self.expr());
        if (not(self.peek().isa(RPar))) {
          self.expect(Comma);
        }
      }
      n = AST::new(Call(n, args), from, self.loc())
      continue;
    }

    panic();
  }

  return n;
}

pub fn Parser::mul(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.postfix();
  while (self.peek().is_any([Star, Slash, Percent])) {
    let kind = match (self.consume().ty) {
      Star => Mul
      Slash => Div
      Percent => Mod
      _ => panic()
    }
    let x = self.postfix();
    n = AST::new(Binary(kind, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::add(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.mul();
  while (self.peek().is_any([Plus, Minus])) {
    let kind = match (self.consume().ty) {
      Plus => Add
      Minus => Sub
      _ => panic()
    }
    let x = self.mul();
    n = AST::new(Binary(kind, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::cmp(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.add();
  while (self.peek().is_any([Lt, Gt, Ge, Lt, Ne, Eq])) {
    let cmp = self.consume().ty;
    let x = self.add();
    let binary = match cmp {
      Lt => Binary(Lt, n, x)
      Le => Binary(Le, n, x)
      Gt => Binary(Lt, x, n)
      Ge => Binary(Le, x, n)
      Eq => Binary(Eq, n, x)
      Ne => Binary(Ne, n, x)
      _ => panic()
    }
    n = AST::new(binary, from, self.loc());
  }
  return n;
}

pub fn Parser::expr(self: Parser) -> AST {
  return self.cmp();
}

pub fn Parser::semicolon(self: Parser) -> Unit {
  let has_semicolon = self.check(Semicolon);
  let omissible = self.check(Newline) || self.peek().is_any([RBrace]);
  if (not(has_semicolon) && not(omissible)) {
    self.expect(Semicolon);
  }
}

pub fn Parser::stmt(self: Parser) -> AST {
  let from = self.peek().loc;
  match (self.consume().ty) {
    Let => {
      self.strip();
      let mutable = self.check(Mut);
      self.strip();
      let name = self.expect_ident();
      let mut ty = None;
      // Check (: Ty)
      self.strip();
      if (self.check(Colon)) {
        ty = Some(self.typename());
      }
      self.strip();
      self.expect(Assign);
      self.strip();
      let init = self.expr();
      self.semicolon();
      let ast = AST::new(VarDecl(name, mutable, init), from, self.loc());
      if (ty is Some(x)) {
        ast.ty = x;
      }
      return ast;
    }
    Return => {
      if (self.check(Newline)) {
        return AST::new(Return(None), from, self.loc());
      }
      let expr = self.expr();
      self.semicolon();
      return AST::new(Return(Some(expr)), from, self.loc());
    }
    _ => {
      self.retrace();
      let from = self.peek().loc;
      let mut expr = self.expr();
      let old = self.place;
      // The +=, -= etc. will not be affected by newline.
      self.strip();
      if (self.peek().is_any([PlusEq, MinusEq, StarEq, SlashEq, PercentEq])) {
        let tok = self.consume();
        let kind = match tok.ty {
          PlusEq => Add
          MinusEq => Sub
          StarEq => Mul
          SlashEq => Div
          PercentEq => Mod
          _ => panic()
        }
        self.strip();
        let rhs = self.expr();
        expr = AST::new(BinaryInplace(kind, expr, rhs), from, self.loc());
      } else {
        self.place = old;
      }
      self.semicolon();
      return expr;
    }
  }
}

pub fn Parser::block(self: Parser) -> AST {
  self.strip();
  let from = self.peek().loc;
  self.expect(LBrace);
  let content = [];
  self.strip();
  while (not(self.check(RBrace))) {
    content.push(self.stmt());
    self.strip();
    if (self.check(EOF)) {
      @diag.error(from, from.advance(1), "left brace is never closed");
      break;
    }
  }
  return AST::new(Block(content), from, self.loc());
}

pub fn Parser::fndecl(self: Parser, visible: Visible) -> AST {
  self.strip();
  let from = self.peek().loc;
  let hasname = self.peek().isa(Ident(""));
  let hastypename = self.peek().isa(Typename(""));
  // Cannot use `ite` here when operands have side-effects.
  let name = if (hasname) {
    self.unqualified(self.expect_ident())
  } else if (hastypename) {
    let namespace = self.expect_typename();
    self.expect(ColonColon);
    let name = self.expect_ident();
    self.qualified(namespace, name);
  } else {
    self.unqualified("__lambda_\{@utils.count()}")
  };
  let args = [];
  let argTys = [];
  self.strip();
  if (not(["main", "init", "test"].contains(name.name))) {
    self.expect(LPar);
    self.strip();
    while (not(self.check(RPar)) && not(self.peek().isa(EOF))) {
      let argname = self.expect_ident();
      let mut ty = Type::Unknown;
      if (self.check(Colon)) {
        ty = self.typename();
      }
      args.push(argname);
      argTys.push(ty);

      if (not(self.peek().isa(RPar))) {
        self.expect(Comma);
      }
      self.strip();
    }
  }
  // Check the optional return type.
  let mut retTy = Type::Unknown;
  self.strip();
  if (self.check(Arrow)) {
    retTy = self.typename();
  }

  let block = self.block();
  // FnDecl only records its return type;
  // the function type can be inferred from `args`.
  let ast = AST::new(FnDecl(visible, name, args, block), from, self.loc());
  ast.ty = Function(argTys, retTy);
  return ast;
}

pub fn Parser::structdecl(self: Parser, visible: Visible) -> AST {
  self.strip();
  let from = self.peek().loc;
  let name = self.expect_typename();
  let fields = [];
  self.expect(LBrace);
  self.strip();
  while (not(self.check(RBrace))) {
    let name = self.expect_ident();
    self.expect(Colon);
    let ty = self.typename();
    fields.push((name, ty));
    if (not(self.peek().isa(RBrace))) {
      self.expect(Newline);
    }
    self.strip();
  }
  return AST::new(StructDecl(visible, name, fields), from, self.loc());
}

pub fn Parser::toplevel(self: Parser, visible: Visible) -> AST {
  let tok = self.consume();
  match (tok.ty) {
    Fn => self.fndecl(visible);
    Struct => self.structdecl(visible);
    EOF => AST::new(Leaf, @diag.Loc::unknown(), @diag.Loc::unknown());
    Newline => self.toplevel(visible);
    Pub | Pubopen | Puball | Priv => {
      self.retrace();
      let visible = self.visible();
      return self.toplevel(visible);
    }
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected top-level token \{tok.ty}");
      self.ignore_until([Fn, Struct]);
      self.retrace();
      return self.toplevel(visible);
    }
  }
}

pub fn Parser::toplevel_block(self: Parser) -> AST {
  let top = [];

  while (not(self.peek().isa(EOF))) {
    let ast = self.toplevel(Priv);
    if (ast.kind is Leaf) {
      break;
    }
    top.push(ast);
  }
  return AST::new(Block(top), self.data[0].loc, self.loc());
}

pub fn Parser::parse(self: Parser) -> AST {
  if self.data.length() == 0 {
    return AST::new(Leaf, @diag.Loc::unknown(), @diag.Loc::unknown())
  }
  let top = self.toplevel_block();
  return top.remove_leaf();
}
