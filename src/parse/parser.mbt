pub struct Parser {
  mut place: Int
  data: Array[Token]
}

pub fn Parser::new(tokens: Array[Token]) -> Parser {
  return { place: 0, data: tokens }
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

pub fn Parser::check(self: Parser, ty: TokenType) -> Bool {
  let success = self.peek().isa(ty);
  if (success) {
    let _ = self.consume();
  }
  return success;
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

pub fn Parser::ignore_until(self: Parser, stop: Array[TokenType]) -> Unit {
  stop.push(EOF);
  for c = self.consume(); c.is_any(stop); c = self.consume() { }
  // This has been consumed; we need to put it back.
  self.place -= 1;
}

pub fn Parser::typename(self: Parser) -> Type {
  let ty = self.expect_typename();
  match (ty) {
    "Int" => Int
    "Float" => Float
    _ => Named(ty, [])
  }
}

pub fn Parser::primary(self: Parser) -> AST {
  let from = self.peek().loc;
  match (self.consume()) {
    { ty: Ident(name), .. } => {
      return AST::new(VarRef(name), from, self.loc());
    }
    { ty: Int(vi), .. } => {
      return AST::new(Int(vi), from, self.loc());
    }
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "unexpected EOF");
      return AST::new(Leaf, loc, loc);
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected token \{tok}");
      self.ignore_until([Semicolon, Let, RBrace]);
      return AST::new(Leaf, tok.loc, tok.loc);
    }
  }
}

pub fn Parser::add(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.primary();
  while (self.peek().is_any([Plus, Minus])) {
    let kind = match (self.consume().ty) {
      Plus => Add
      Minus => Sub
      _ => panic();
    }
    let x = self.primary();
    n = AST::new(Binary(kind, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::expr(self: Parser) -> AST {
  return self.primary();
}

pub fn Parser::stmt(self: Parser) -> AST {
  let from = self.peek().loc;
  match (self.peek().ty) {
    Let => {
      let _ = self.consume();
      let name = self.expect_ident();
      let mut ty = None;
      // Check (: Ty)
      if (self.check(Colon)) {
        ty = Some(self.typename());
      }
      self.expect(Eq);
      let init = self.expr();
      let ast = AST::new(VarDecl(name, init), from, self.loc());
      if (ty is Some(x)) {
        ast.ty = x;
      }
      return ast;
    }
    _ => self.expr()
  }
}

pub fn Parser::block(self: Parser) -> AST {
  let from = self.peek().loc;
  self.expect(LBrace);
  let content = [];
  while (not(self.check(RBrace))) {
    content.push(self.stmt());
    if (self.check(EOF)) {
      @diag.error(from, from.advance(1), "left brace is never closed");
      break;
    }
  }
  return AST::new(Block(content), from, self.loc());
}

pub fn Parser::fndecl(self: Parser) -> AST {
  let from = self.peek().loc;
  let name = self.expect_ident();
  let args = [];
  if (not(["main", "init", "test"].contains(name))) {
    self.expect(LPar);
    while (not(self.check(RPar))) {
      let argfrom = self.peek().loc;
      let argname = self.expect_ident();
      let mut ty = None;
      if (self.check(Colon)) {
        ty = Some(self.typename());
      }
      let ast = AST::new(ParamDecl(argname), argfrom, self.loc());
      if (ty is Some(x)) {
        ast.ty = x;
      }
      args.push(ast);

      if (not(self.peek().isa(RPar))) {
        self.expect(Comma);
      }
    }
  }
  let block = self.block();
  return AST::new(FnDecl(args, block), from, self.loc());
}

pub fn Parser::toplevel(self: Parser) -> AST {
  match (self.consume()) {
    { ty: Fn, .. } => self.fndecl();
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "unexpected EOF");
      return AST::new(Leaf, loc, loc);
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected top-level token \{tok.ty}");
      self.ignore_until([Fn, Let]);
      return self.toplevel();
    }
  }
}

pub fn Parser::parse(self: Parser) -> AST {
  if self.data.length() == 0 {
    panic();
  }
  return self.toplevel();
}
