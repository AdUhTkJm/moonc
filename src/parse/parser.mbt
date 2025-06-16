pub struct Parser {
  mut place: Int
  data: Array[Token]
  pack: Option[String]
  filename: String
}

pub fn Parser::new(pack: Option[String], filename: String, tokens: Array[Token]) -> Parser {
  return { place: 0, data: tokens, pack: pack, filename: filename }
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

pub fn Parser::consumes(self: Parser) -> Token {
  self.strip();
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }

  let t = self.data[self.place];
  self.place += 1;
  return t;
}

pub fn Parser::checks(self: Parser, ty: TokenType) -> Bool {
  let old = self.place;
  if (not(self.consumes().isa(ty))) {
    self.place = old;
    return false;
  }
  return true;
}

pub fn Parser::expects(self: Parser, ty: TokenType) -> Unit {
  let tok = self.consumes();
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

pub fn Parser::expect_idents(self: Parser) -> String {
  match self.consumes() {
    { ty: Ident(x), .. } => x
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "reached EOF on recovery");
      ""
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "expected identifier, but got \{tok.ty}");
      self.expect_idents();
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
  let mut pack = self.pack;
  if (self.peek().ty is Packname(x)) {
    self.consume() |> ignore;
    pack = Some(x);
    self.expect(Dot);
  }
  let ty = self.expect_typename();
  if (pack != self.pack) {
    return Named({ pack: pack, name: ty, namespace: None }, [])
  }
  match (ty) {
    "Int" => Int
    "Float" => Float
    "Double" => Double
    "Unit" => Unit
    _ => Named(self.unqualified(ty), [])
  }
}

pub fn Parser::postfix_type(self: Parser) -> Type {
  let mut ty = self.basetype();
  while (self.checks(Ques)) {
    ty = Option(ty);
  }
  return ty;
}

pub fn Parser::typename(self: Parser) -> Type {
  if (self.checks(LPar)) {
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
  let ty = self.postfix_type();
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
    Puball => Puball
    Pubopen => Pubopen
    Priv => Priv
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

fn Parser::base_pattern(self: Parser) -> Pattern {
  let tok = self.consumes();
  match tok.ty {
    Int(x) => Int(x)
    Char(x) => Char(x)
    Str(x) => Str(x)
    Typename(x) => Enum(x, [])
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected match pattern");
      Unknown
    }
  }
}

pub fn Parser::pattern(self: Parser) -> Pattern {
  let from = self.peek().loc;
  let pattern = self.base_pattern();
  if (self.check(LPar)) {
    if (pattern is Enum(x, [])) {
      let bindings = [];
      while (not(self.check(RPar)) && not(self.peek().isa(EOF))) {
        bindings.push(self.expect_ident());
        if (not(self.peek().isa(RPar))) {
          self.expect(Comma);
        }
      }
      return Enum(x, bindings);
    } else {
      @diag.error(from, self.loc(), "binding a variant that does not accept argument");
      return pattern;
    }
  }

  if (self.check(IncRange)) {
    let qattern = self.base_pattern();
    return IncRange(pattern, qattern);
  }

  if (self.check(ExcRange)) {
    let qattern = self.base_pattern();
    return ExcRange(pattern, qattern);
  }

  pattern
}

pub fn Parser::matchexpr(self: Parser) -> AST {
  let from = self.peek().loc;
  let matcher = self.expr();
  let branches = [];
  self.expects(LBrace);
  while (not(self.checks(RBrace)) && not(self.peek().isa(EOF))) {
    let pattern = self.pattern();
    self.expects(Arrrow);
    let expr = self.expr();
    self.semicolon();
    branches.push((pattern, expr));
  }

  AST::new(Match(matcher, branches), from, self.loc());
}

pub fn Parser::fstr(self: Parser, str_: String) -> AST {
  let from = self.peek().loc.advance(-str_.length());
  let str = str_.to_array();
  let mut pos = 0;
  let chunks = [];

  let ch = fn () {
    let c = str[pos];
    pos += 1;
    return c;
  }
  let current = [];

  while (pos < str.length()) {
    match ch() {
    '\\' => {
      let next = ch();
      match next {
      'n'  => current.push('\n')
      't'  => current.push('\t')
      'r'  => current.push('\r')
      '\\' => current.push('\\')
      '"'  => current.push('"')
      '\'' => current.push('\'')
      '0'  => current.push('\u0000')
      'u'  => {
        let digits = [];
        let loc = from.advance(pos);
        for i in 0..<4 {
          let c = ch();
          if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
            @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
            break;
          }
          digits.push(c);
        }
        let unicode = parse_hex(digits, loc);
        current.push(Int::unsafe_to_char(unicode));
      }
      '{' => {
        let s = String::from_array(current);
        let loc = from.advance(pos);
        chunks.push(AST::new(Str(s), loc.advance(-current.length()), loc));
        current.clear();

        let mut depth = 1;
        let code = [];
        while (depth > 0) {
          let c = ch();
          if (pos > str.length()) {
            @diag.error(from, self.loc(), "unterminated f-string literal");
            break;
          } else if (c == '{') {
            depth += 1;
          } else if (c == '}') {
            depth -= 1;
            if depth == 0 {
              break;
            }
          }

          if (depth > 0) {
            code.push(c);
          }
        }

        let code = String::from_array(code);
        let tokens = Lexer::new(self.filename + "_fstring_\{@utils.count()}", code).lex();
        let errcnt = @diag.errcnt();
        let ast = Parser::new(self.pack, self.filename, tokens).expr();
        if (errcnt != @diag.errcnt()) {
          @diag.error(from, self.loc(), "cannot parse subexpression in f-string");
          return AST::new(Str(""), from, self.loc());
        }
        chunks.push(ast);
      }
      _ => {
        let loc = from.advance(pos);
        @diag.error(loc, loc.advance(1), ("unknown escape sequence"));
      }
      }
    }
    c => current.push(c);
    }
  }
  let s = String::from_array(current);
  let loc = from.advance(pos);
  chunks.push(AST::new(Str(s), loc.advance(-current.length()), loc));

  if (chunks.length() == 1) {
    return chunks[0];
  }
  return AST::new(Fstr(chunks), from, self.loc());
}

pub fn Parser::primary(self: Parser) -> AST {
  let from = self.peek().loc;
  let tok = self.consume();
  match (tok.ty) {
    Ident(name) => AST::new(VarRef(self.unqualified(name)), from, self.loc());
    Int(vi) => AST::new(Int(vi), from, self.loc());
    Double(vd) => AST::new(Double(vd), from, self.loc());
    Float(vf) => AST::new(Float(vf), from, self.loc());
    Str(vs) => self.fstr(vs);
    True => AST::new(Bool(true), from, self.loc());
    False => AST::new(Bool(false), from, self.loc());
    Char(vc) => AST::new(Char(vc), from, self.loc());
    LPar => {
      let what = self.expr();
      self.expect(RPar);
      what;
    }
    LBrace => {
      let old = self.place;
      if (self.checks(Expand)) {
        self.strip();
        let base = self.expr();
        self.expects(Comma);
        
        // Now replicate the logic below.
        let map = Map::new();
        while (not(self.checks(RBrace)) && not(self.peek().isa(EOF))) {
          let ident = self.expect_idents();
          map[ident] = if (self.checks(Colon)) {
            self.exprs();
          } else {
            AST::new(VarRef(self.unqualified(ident)), from, from);
          }

          if (not(self.peek().isa(RBrace))) {
            self.expects(Comma);
          }
        }
        return AST::new(StructModif(base, map), from, self.loc());
      }

      if (self.checks(Ident(""))) {
        // A struct initializer.
        if (self.checks(Colon)) {
          self.place = old;
          let map = Map::new();
          while (not(self.checks(RBrace)) && not(self.peek().isa(EOF))) {
            let ident = self.expect_idents();
            map[ident] = if (self.checks(Colon)) {
              self.exprs();
            } else {
              // The name is omitted.
              AST::new(VarRef(self.unqualified(ident)), from, from);
            }

            self.strip();
            if (not(self.peek().isa(RBrace))) {
              self.expects(Comma);
            }
          }
          return AST::new(StructInit(map), from, self.loc());
        }
      }
      self.place = old - 1;
      self.block();
    }
    Match => self.matchexpr();
    If => self.ifexpr();
    Fn => self.fndecl(Priv);
    Typename(ty) => {
      if (self.check(ColonColon)) {
        // Ty::A(...)
        if (self.peek().isa(Typename(""))) {
          let name = self.expect_typename();
          let exprs = [];
          if (self.check(LPar)) {
            while (not(self.checks(RPar)) && not(self.peek().isa(EOF))) {
              exprs.push(self.expr());
              self.strip();

              if (not(self.peek().isa(RPar))) {
                self.expects(Comma);
              }
            }
          }
          return AST::new(EnumConstr(self.qualified(ty, name), exprs), from, self.loc());
        }
        // Ty::field
        let name = self.expect_ident();
        return AST::new(VarRef(self.qualified(ty, name)), from, self.loc());
      }
      // Ty(...)
      let exprs = [];
      if (self.check(LPar)) {
        while (not(self.checks(RPar)) && not(self.peek().isa(EOF))) {
          exprs.push(self.expr());
          self.strip();

          if (not(self.peek().isa(RPar))) {
            self.expects(Comma);
          }
        }
      }

      return AST::new(EnumConstr(self.unqualified(ty), exprs), from, self.loc());
    }
    LBracket => {
      let exprs = [];
      while (not(self.checks(RBracket)) && not(self.peek().isa(EOF))) {
        exprs.push(self.expr());
        self.strip();

        if (not(self.peek().isa(RBracket))) {
          self.expects(Comma);
        }
      }
      AST::new(Arr(exprs), from, self.loc());
    }
    Packname(pack) => {
      self.expects(Dot);
      if (not(self.peek().isa(Ident(""))) && not(self.peek().isa(Typename("")))) {
        @diag.error(from, self.loc(), "package name does not qualify another name");
        return AST::new(Leaf, from, self.loc());
      }
      let n = self.primary();
      match n {
        { kind: VarRef(x), .. } => { ..n, kind: VarRef(x.pack(pack)) }
        { kind: EnumConstr(x, tys), .. } => { ..n, kind: EnumConstr(x.pack(pack), tys) }
        _ => panic()
      }
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
  
  while (self.peek().is_any([LPar, Dot, LBracket])) {
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
          self.strip();
        }
      }
      n = AST::new(Call(n, args), from, self.loc())
      continue;
    }

    if (self.check(LBracket)) {
      let ind = self.expr();
      self.expects(RBracket);
      n = AST::new(ArrAccess(n, ind), from, self.loc());
      continue;
    }

    panic();
  }

  return n;
}

pub fn Parser::prefix(self: Parser) -> AST {
  let from = self.peek().loc;
  if (self.check(Minus)) {
    let n = self.prefix();
    return AST::new(Unary(Minus, n), from, self.loc());
  }
  if (self.check(Bang)) {
    let n = self.prefix();
    return AST::new(Unary(Not, n), from, self.loc());
  }
  return self.postfix();
}

pub fn Parser::mul(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.prefix();
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
  while (self.peek().is_any([Lt, Gt, Ge, Lt])) {
    let cmp = self.consume().ty;
    let x = self.add();
    let binary = match cmp {
      Lt => Binary(Lt, n, x)
      Le => Binary(Le, n, x)
      Gt => Binary(Lt, x, n)
      Ge => Binary(Le, x, n)
      _ => panic()
    }
    n = AST::new(binary, from, self.loc());
  }
  return n;
}

pub fn Parser::eq(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.cmp();
  while (self.peek().is_any([Lt, Gt, Ge, Lt, Ne, Eq])) {
    let cmp = self.consume().ty;
    let x = self.cmp();
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

pub fn Parser::bitand(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.eq();
  while (self.check(Bitand)) {
    let x = self.eq();
    n = AST::new(Binary(Bitand, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::xor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.bitand();
  while (self.check(Xor)) {
    let x = self.bitand();
    n = AST::new(Binary(Xor, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::bitor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.xor();
  while (self.check(Bitor)) {
    let x = self.xor();
    n = AST::new(Binary(Bitor, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::logand(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.bitor();
  while (self.check(Logand)) {
    let x = self.bitor();
    n = AST::new(Binary(And, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::logor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.logand();
  while (self.check(Logor)) {
    let x = self.logand();
    n = AST::new(Binary(Or, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::ismatch(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.logor();
  while (self.check(Is)) {
    let x = self.pattern();
    n = AST::new(Is(n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::tryres(self: Parser) -> AST {
  let from = self.peek().loc;
  if (self.checks(Try)) {
    self.expects(Ques);
    let after = self.tryres();
    return AST::new(Unary(Try, after), from, self.loc());
  }
  return self.ismatch();
}

pub fn Parser::expr(self: Parser) -> AST {
  return self.tryres();
}

pub fn Parser::exprs(self: Parser) -> AST {
  self.strip()
  return self.expr();
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
      let mutable = self.checks(Mut);
      let name = self.expect_idents();
      let mut ty = None;
      // Check (: Ty)
      if (self.checks(Colon)) {
        ty = Some(self.typename());
      }
      self.expects(Assign);
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
      if (self.check(Newline) || self.check(Semicolon)) {
        return AST::new(Return(None), from, self.loc());
      }
      let expr = self.expr();
      self.semicolon();
      return AST::new(Return(Some(expr)), from, self.loc());
    }
    Break => {
      if (self.check(Newline) || self.check(Semicolon)) {
        return AST::new(Break(None), from, self.loc());
      }
      let expr = self.expr();
      self.semicolon();
      return AST::new(Break(Some(expr)), from, self.loc());
    }
    While => {
      self.strip();
      let cond = self.expr();
      let body = self.block();
      let mut exit = None;
      if (self.checks(Else)) {
        exit = Some(self.block());
      }
      return AST::new(While(cond, body, exit), from, self.loc());
    }
    For => {
      let name = self.expect_idents();
      if (self.checks(In)) {
        let range = self.expr();
        let body = self.block();
        let mut exit = None;
        if (self.checks(Else)) {
          exit = Some(self.block());
        }
        return AST::new(ForIn(name, range, body, exit), from, self.loc());
      }
      self.expects(Assign);
      let start = self.exprs();

      self.expects(Semicolon);
      let cond = self.exprs();

      self.expects(Semicolon);
      let name2 = self.expect_idents();
      if (name2 != name) {
        @diag.error(self.data[self.place - 1].loc, self.loc(), "mutating non-induction variable \{name2}");
      }

      self.expects(Assign);
      let newval = self.exprs();

      let body = self.block();

      let mut exit = None;
      if (self.checks(Else)) {
        exit = Some(self.block());
      }
      return AST::new(For(name, start, cond, newval, body, exit), from, self.loc());
    }
    Continue => {
      if (not(self.check(Newline)) && not(self.check(Semicolon))) {
        @diag.error(from, self.loc(), "continue should occupy a single line");
      }
      AST::new(Continue, from, self.loc());
    }
    _ => {
      self.retrace();
      let from = self.peek().loc;
      let mut expr = self.expr();
      let old = self.place;
      // The +=, -= etc. will not be affected by newline.
      self.strip();
      if (self.peek().is_any([PlusEq, MinusEq, StarEq, SlashEq, PercentEq, Assign, AndEq, XorEq, OrEq])) {
        let tok = self.consume();
        let kind = match tok.ty {
          PlusEq => Add
          MinusEq => Sub
          StarEq => Mul
          SlashEq => Div
          PercentEq => Mod
          Assign => Assign
          AndEq => And
          XorEq => Xor
          OrEq => Or
          _ => panic()
        }
        let rhs = self.exprs();
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
  while (not(self.check(RBrace)) && not(self.check(EOF))) {
    content.push(self.stmt());
    if (self.checks(EOF)) {
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
  while (not(self.check(RBrace)) && not(self.peek().isa(EOF))) {
    // `mut` and `priv` can come at any order.
    let mut mutable = self.checks(Mut);
    let mut vis = Visible::Pub;
    if (self.checks(Priv)) {
      vis = Priv;
    }
    if (self.checks(Mut)) {
      mutable = true;
    }

    let name = self.expect_ident();
    self.expect(Colon);
    let ty = self.typename();
    fields.push({ name, ty, mutable, vis });
    if (not(self.peek().isa(RBrace))) {
      self.semicolon();
    }
    self.strip();
  }
  let deriving = [];
  if (self.checks(Derive)) {
    self.expects(LPar);
    while (not(self.checks(RPar)) && not(self.peek().isa(EOF))) {
      let name = self.qualified_typename();
      deriving.push(name);
      if (not(self.peek().isa(RPar))) {
        self.expects(Comma);
      }
    }
  }
  return AST::new(StructDecl(visible, self.unqualified(name), fields, deriving), from, self.loc());
}

pub fn Parser::enumdecl(self: Parser, visible: Visible) -> AST {
  self.strip();
  let from = self.peek().loc;
  let name = self.expect_typename();
  let variants = [];
  self.expect(LBrace);
  self.strip();
  while (not(self.check(RBrace)) && not(self.peek().isa(EOF))) {
    let name = self.expect_typename();
    let tys = [];
    // No newline allowed.
    if (self.check(LPar)) {
      while (not(self.check(RPar)) && not(self.peek().isa(EOF))) {
        let ty = self.typename();
        tys.push(ty);
        if (not(self.peek().isa(RPar))) {
          self.expect(Comma);
        }
      }
      if (tys.length() == 0) {
        @diag.error(from, self.loc(), "empty enum variant when '()' is present");
      }
    }
    variants.push((name, tys));
    if (not(self.peek().isa(RBrace))) {
      self.semicolon();
    }
    self.strip();
  }
  let deriving = [];
  if (self.checks(Derive)) {
    self.expects(LPar);
    while (not(self.checks(RPar)) && not(self.peek().isa(EOF))) {
      let name = self.qualified_typename();
      deriving.push(name);
      if (not(self.peek().isa(RPar))) {
        self.expects(Comma);
      }
    }
  }
  return AST::new(EnumDecl(visible, self.unqualified(name), variants, deriving), from, self.loc());
}

pub fn Parser::globaldecl(self: Parser, visible: Visible) -> AST {
  let from = self.peek().loc;
  let name = self.expect_idents();
  let mut ty = None;
  if (self.checks(Colon)) {
    ty = Some(self.typename());
  }
  self.expects(Assign);
  self.strip();
  let init = self.expr();
  self.semicolon();
  let ast = AST::new(GlobalDecl(visible, self.unqualified(name), init), from, self.loc());
  if (ty is Some(x)) {
    ast.ty = x;
  }
  return ast;
}

pub fn Parser::qualified_typename(self: Parser) -> Name {
  let mut pack = None;
  if (self.peek().ty is Packname(x)) {
    pack = Some(x);
  }
  let name = self.expect_typename();
  let mut name = self.unqualified(name);
  if (pack is Some(x)) {
    name = name.pack(x);
  }
  name;
}

pub fn Parser::impldecl(self: Parser, visible: Visible) -> AST {
  let from = self.peek().loc;

  self.strip();
  let _trait = self.qualified_typename();

  self.expects(For);
  self.strip();
  let _struct = self.qualified_typename();

  self.expects(With);
  let func = self.expect_idents();
  let args = [];
  let argTys = [];

  self.expects(LPar);
  while (not(self.checks(RPar)) && not(self.peek().isa(EOF))) {
    let argname = self.expect_ident();
    let mut ty = Type::Unknown;
    if (self.checks(Colon)) {
      ty = self.typename();
    }
    args.push(argname);
    argTys.push(ty);

    if (not(self.peek().isa(RPar))) {
      self.expects(Comma);
    }
  }
  
  // Check the optional return type.
  let mut retTy = Type::Unknown;
  self.strip();
  if (self.check(Arrow)) {
    retTy = self.typename();
  }

  let body = self.block();
  // FnDecl only records its return type;
  // the function type can be inferred from `args`.
  let ast = AST::new(ImplDecl(visible, _struct, _trait, func, args, body), from, self.loc());
  ast.ty = Function(argTys, retTy);
  return ast;
}

pub fn Parser::toplevel(self: Parser, visible: Visible) -> AST {
  let tok = self.consume();
  match (tok.ty) {
    Fn => self.fndecl(visible);
    Struct => self.structdecl(visible);
    Enum => self.enumdecl(visible);
    Let => self.globaldecl(visible);
    Impl => self.impldecl(visible);
    EOF => AST::new(Leaf, @diag.Loc::unknown(), @diag.Loc::unknown());
    Newline | Semicolon => self.toplevel(visible);
    Pub | Pubopen | Puball | Priv => {
      self.retrace();
      let visible = self.visible();
      return self.toplevel(visible);
    }
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected top-level token \{tok.ty}");
      self.ignore_until([Fn, Struct, Enum]);
      if (not(self.peek().isa(EOF))) {
        self.retrace();
      }
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
