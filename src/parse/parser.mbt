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

pub fn Parser::typename(self: Parser) -> Type {
  let ty = self.expect_typename();
  match (ty) {
    "Int" => Int
    "Float" => Float
    _ => Named(ty, [])
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
    Ident(name) => AST::new(VarRef(name), from, self.loc());
    Int(vi) => AST::new(Int(vi), from, self.loc());
    LPar => {
      let what = self.expr();
      self.expect(RPar);
      what;
    }
    LBrace => {
      self.retrace();
      self.block();
    }
    If => self.ifexpr();
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected token \{tok.ty}");
      self.ignore_until([Semicolon, Let, RBrace, Newline]);
      AST::new(Leaf, tok.loc, tok.loc);
    }
  }
}

pub fn Parser::call(self: Parser) -> AST {
  let from = self.peek().loc;
  let n = self.primary();
  
  if (not(self.check(LPar))) {
    return n;
  }

  let args = [];
  while (not(self.check(RPar))) {
    args.push(self.expr());
    if (not(self.peek().isa(RPar))) {
      self.expect(Comma);
    }
  }
  return AST::new(Call(n, args), from, self.loc())
}

pub fn Parser::mul(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.call();
  while (self.peek().is_any([Star, Slash, Percent])) {
    let kind = match (self.consume().ty) {
      Star => Mul
      Slash => Div
      Percent => Mod
      _ => panic()
    }
    let x = self.call();
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
  match (self.peek().ty) {
    Let => {
      let _ = self.consume();
      let name = self.expect_ident();
      let mut ty = None;
      // Check (: Ty)
      if (self.check(Colon)) {
        ty = Some(self.typename());
      }
      self.expect(Assign);
      let init = self.expr();
      self.semicolon();
      let ast = AST::new(VarDecl(name, init), from, self.loc());
      if (ty is Some(x)) {
        ast.ty = x;
      }
      return ast;
    }
    Return => {
      self.consume() |> ignore;
      let expr = self.expr();
      self.semicolon();
      return AST::new(Return(expr), from, self.loc());
    }
    _ => {
      let expr = self.expr();
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

pub fn Parser::fndecl(self: Parser) -> AST {
  self.strip();
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
  return AST::new(FnDecl(name, args, block), from, self.loc());
}

pub fn Parser::toplevel(self: Parser) -> AST {
  let top = [];

  while (not(self.peek().isa(EOF))) {
    let tok = self.consume();
    match (tok.ty) {
      Fn => top.push(self.fndecl());
      EOF => break;
      Newline => continue;
      _ => {
        @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected top-level token \{tok.ty}");
        self.ignore_until([Fn]);
        self.retrace();
        continue;
      }
    }
  }
  return AST::new(Block(top), self.data[0].loc, self.loc());
}

pub fn Parser::parse(self: Parser) -> AST {
  if self.data.length() == 0 {
    panic();
  }
  let top = self.toplevel();
  return top.remove_leaf();
}
