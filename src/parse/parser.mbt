typealias @utils.Map;
typealias @diag.Loc;

pub struct Parser {
  mut place: Int
  data: Array[Token]
  filename: String
  attr: Array[Attribute]
}

pub fn Parser::new(filename: String, tokens: Array[Token]) -> Parser {
  return { place: 0, data: tokens, filename: filename, attr: [] }
}

///|
/// Returns source location of EOF.
/// 
pub fn Parser::eof_loc(self: Parser) -> Loc {
  return self.data.last().unwrap().loc;
}

///|
/// Checks whether the token stream has reached EOF.
/// 
pub fn Parser::eof(self: Parser) -> Bool {
  return self.peek().isa(EOF);
}

///|
/// Returns the current location in the source code where the parser is
/// positioned.
///
pub fn Parser::loc(self: Parser) -> Loc {
  if (self.place == 0) {
    return self.data[0].loc.advance(self.data[0].len);
  }
  let tok = self.data[self.place - 1];
  return tok.loc.advance(tok.len);
}

///|
/// Consumes and returns the next token from the parser's token stream,
/// automatically advancing the parser's position.
///
pub fn Parser::consume(self: Parser) -> Token {
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }
  let t = self.data[self.place];
  self.place += 1;
  return t;
}

///|
/// Consumes the next token from the parser's token stream and advances
/// through it. Does not return the token.
///
pub fn Parser::advance(self: Parser) -> Unit {
  self.consume() |> ignore;
}

///|
/// Returns the current token at the parser's position without advancing the
/// position.
///
pub fn Parser::peek(self: Parser) -> Token {
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }
  self.data[self.place]
}

///|
/// Returns the previous token at the parser's position. Does not perform any
/// boundary checks; panics if there's no such token.
///
pub fn Parser::last(self: Parser) -> Token {
  self.data[self.place - 1]
}

///|
/// Retraces (goes back) by one token.
/// 
pub fn Parser::retrace(self: Parser) -> Unit {
  self.place -= 1;
}

///|
/// Checks if the next token in the parser's token stream matches the specified
/// token type, and advance the parser's position if and only if the match succeeds.
///
pub fn Parser::check(self: Parser, ty: TokenType) -> Bool {
  let old = self.place;
  if (not(self.consume().isa(ty))) {
    self.place = old;
    return false;
  }
  return true;
}

///|
/// Consumes the next token from the parser and validates that it matches the
/// expected token type, reporting a diagnostic error on mismatch.
///
pub fn Parser::expect(self: Parser, ty: TokenType) -> Unit {
  let tok = self.consume();
  if (not(tok.isa(ty))) {
    @diag.error(tok.loc, tok.loc.advance(tok.len), "expected \{ty}, but got \{tok.ty}");
  }
}

///|
/// **Strips newlines**, and returns the current token at the parser's position
/// without advancing the position.
///
pub fn Parser::peeks(self: Parser) -> Token {
  self.strip();
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }
  self.data[self.place]
}

///|
/// **Strips newlines**, and consumes and returns the next token from the token stream,
/// automatically advancing the parser's position.
///
pub fn Parser::consumes(self: Parser) -> Token {
  self.strip();
  if self.place >= self.data.length() {
    return Token::new(EOF, self.eof_loc(), 0);
  }

  let t = self.data[self.place];
  self.place += 1;
  return t;
}

/// **Strips newlines**, and checks if the next token in the parser's token stream
/// matches the specified token type, and advance the parser's position if and only
/// if the match succeeds.
///
pub fn Parser::checks(self: Parser, ty: TokenType) -> Bool {
  let old = self.place;
  if (not(self.consumes().isa(ty))) {
    self.place = old;
    return false;
  }
  return true;
}

///|
/// **Strips newlines**, consumes the next token from the parser, validates that
/// it matches the expected token type, and reports a diagnostic error on mismatch.
///
pub fn Parser::expects(self: Parser, ty: TokenType) -> Unit {
  let tok = self.consumes();
  if (not(tok.isa(ty))) {
    @diag.error(tok.loc, tok.loc.advance(tok.len), "expected \{ty}, but got \{tok.ty}");
  }
}

///|
/// Consumes the next token from the parser and validates that it is an
/// identifier, returning the identifier string. When it's not the case, a diagnostic
/// error is filed, and an empty string is returned.
///
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

///|
/// **Strips newlines**, consumes the next token from the parser and validates that
/// it is an identifier, returning the identifier string. When it's not the case,
/// a diagnostic error is filed, and an empty string is returned.
///
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

///|
/// Consumes the next token from the parser and validates that it is an
/// `Typename`, returning the type name string. When it's not the case, a diagnostic
/// error is filed, and an empty string is returned.
///
pub fn Parser::expect_typename(self: Parser) -> String {
  match self.consume() {
    { ty: Typename(x), .. } => x
    { ty: EOF, loc, len } => {
      @diag.error(loc, loc.advance(len), "reached EOF on recovery");
      ""
    }
    tok => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "expected type name, but got \{tok.ty}");
      self.expect_typename();
    }
  }
}

///|
/// Advances the parser's position past any consecutive newline tokens in the
/// token stream.
///
pub fn Parser::strip(self: Parser) -> Unit {
  while (self.place < self.data.length() && self.data[self.place].isa(Newline)) {
    self.place += 1;
  }
}

///|
/// Ignores everything until any token in `stop`. The `stop` itself is also consumed.
/// 
pub fn Parser::ignore_until(self: Parser, stop: Array[TokenType]) -> Unit {
  stop.push(EOF);
  for c = self.consume(); not(c.is_any(stop)); c = self.consume() { }
}

///|
/// Produces a name with the parser's current package, but without any ns.
/// 
fn unqualified(x: String) -> Name {
  Name::unqualified(None, x);
}

///|
/// Produces a name with the parser's current package, and with the specified ns.
/// 
fn qualified(ns: String, x: String) -> Name {
  Name::qualified(None, ns, x);
}

///|
/// Parses a base type from the token stream, handling both built-in primitive
/// types and user-defined named types with optional package qualification.
///
pub fn Parser::basetype(self: Parser) -> Type {
  let mut pack = None;
  if (self.peek().ty is Packname(x)) {
    self.advance();
    pack = Some(x);
    self.expect(Dot);
  }
  if (self.peek().ty is Ident("_")) {
    self.advance();
    return Unknown;
  }

  let ty = self.expect_typename();
  if (pack != None) {
    return Named({ pack: pack, name: ty, ns: None }, [])
  }
  match (ty) {
    "Int" => Int
    "Float" => Float
    "Double" => Double
    "Unit" => Unit
    _ => Named(unqualified(ty), [])
  }
}

///|
/// Parses types with prefix `&`. The symbol is not associative.
/// 
pub fn Parser::prefix_type(self: Parser) -> Type {
  if (self.check(Bitand)) {
    let ty = self.basetype();
    return VirtualBase(ty);
  }
  return self.basetype();
}

///|
/// Parses postfixes `?` and `[T]` (as type arguments).
/// 
/// The postfix `raise?` is also parsed here.
/// 
pub fn Parser::postfix_type(self: Parser) -> Type {
  let from = self.peek().loc;
  let mut ty = self.prefix_type();
  if (self.check(LBracket)) {
    // Type arguments
    let args = [];
    while (not(self.check(RBracket)) && not(self.eof())) {
      let argTy = self.typename();
      args.push(argTy);
      if (not(self.peek().isa(RBracket))) {
        self.expect(Comma);
      }
      self.strip();
    }

    if (ty is Named(x, [])) {
      ty = Named(x, args);
    } else {
      @diag.error(from, self.loc(), "builtin type \{ty} does not accept parameters");
    }
  }

  while (self.check(Ques)) {
    // Think of Unit?????Error, which is ((Unit????) ? Error).
    if (self.peek().isa(Typename(""))) {
      self.retrace();
      break;
    }
    ty = Option(ty);
  }

  if (self.check(Raise)) {
    if (not(self.check(Ques))) {
      self.retrace();
    }
    ty = MayError(ty);
  }
  return ty;
}

///| 
/// Parses binary type operator `?`, `!` and `raise`.
/// 
pub fn Parser::binary_type(self: Parser) -> Type {
  let mut ty = self.postfix_type();
  while (self.peek().is_any([Ques, Raise, Bang])) {
    let tok = self.consume();

    // When there's nothing after raise, it defaults to error.
    let next = if (not(self.peek().ty is Typename(_))) {
      Error
    } else  {
      self.basetype();
    }

    ty = match tok.ty {
      Ques => {
        if (not(next is Error)) {
          @diag.error(tok.loc, self.loc(), "expected '?Error'");
        }
        MayError(ty)
      }
      Bang | Raise => HasError(ty, next)
      _ => panic();
    }
  }
  return ty;
}

///|
/// Parses functional types, i.e. those of form `(X, Y) -> Z`.
/// 
/// Note that tuples are also parsed here because they also start with a `(`.
///  
pub fn Parser::functional_type(self: Parser) -> Type {
  if (self.checks(LPar)) {
    let args = [];
    while (not(self.checks(RPar)) && not(self.eof())) {
      let ty = self.typenames();
      args.push(ty);
      if (not(self.peek().isa(RPar))) {
        self.expects(Comma);
      }
    }
    if (not(self.checks(Arrow))) {
      if (args.length() == 1) {
        return args[0];
      }
      return Tuple(args);
    }
    let ret = self.typenames();
    return Function(args, ret);
  }
  return self.binary_type();
}

///|
/// Entry of type parsing.
/// 
pub fn Parser::typename(self: Parser) -> Type {
  return self.functional_type();
}

///|
/// **Strips newline**, and parses a type name.
/// 
pub fn Parser::typenames(self: Parser) -> Type {
  self.strip();
  return self.functional_type();
}

///|
/// Consume the next token and returns the visibility denoted by that.
/// 
/// If no such token is encountered, this retraces and defaults to `Priv`.
/// 
pub fn Parser::vis(self: Parser) -> Visible {
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
  if (self.checks(Else)) {
    other = if (self.checks(If)) {
      Some(self.ifexpr());
    } else {
      Some(self.block());
    }
  }
  AST::new(If(cond, body, other), from, self.loc());
}

fn Parser::base_pattern(self: Parser) -> Pattern {
  let tok = self.consumes();

  if (tok.isa(LPar)) {
    let pats = []
    while (not(self.checks(RPar)) && not(self.eof())) {
      pats.push(self.pattern());
      if (not(self.peeks().isa(RPar))) {
        self.expects(Comma);
      }
    }
    if (pats.length() == 1) {
      return pats[0];
    }
    return Tuple(pats);
  }

  if (tok.isa(LBrace)) {
    let fields = Map::new();
    let mut expanded = false;
    while (not(self.checks(RBrace)) && not(self.eof())) {
      if (self.checks(Expand)) {
        expanded = true;
      } else {
        let name = self.expect_idents();
        let mut binding: Pattern = Ident(name);
        if (self.checks(Colon)) {
          binding = self.pattern();
        }
        fields[name] = binding;
      }

      if (not(self.peeks().isa(RBrace))) {
        self.expects(Comma);
      }
    }
    return Struct(fields, expanded);
  }

  if (tok.isa(LBracket)) {
    let content: Array[Pattern] = [];
    while (not(self.checks(RBracket)) && not(self.eof())) {
      if (self.checks(Expand)) {
        let mut name = "_";
        if (self.peeks().isa(Ident(""))) {
          name = self.expect_ident();
        }
        content.push(Expand(name));
      } else {
        let name = self.pattern();
        content.push(name);
      }

      if (not(self.peeks().isa(RBracket))) {
        self.expects(Comma);
      }
    }
    return Array(content);
  }

  // Expect `-Int(...)`
  if (tok.isa(Minus)) {
    if (self.consumes().ty is Int(x, ty)) {
      return Int(-x, ty);
    }

    @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected match pattern");
    return Unknown;
  }

  match tok.ty {
    Int(x, ty) => Int(x, ty)
    Char(x) => Char(x)
    Str(x) => Str(x)
    Typename(x) => Enum(x, [])
    Ident(x) => Ident(x)
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected match pattern");
      Unknown
    }
  }
}

pub fn Parser::composite_pattern(self: Parser) -> Pattern {
  let from = self.peek().loc;
  let pattern = self.base_pattern();

  if (self.check(LPar)) {
    if (pattern is Enum(x, [])) {
      let bindings = [];
      while (not(self.checks(RPar)) && not(self.eof())) {
        bindings.push(self.pattern());
        if (not(self.peek().isa(RPar))) {
          self.expects(Comma);
        }
      }
      return Enum(x, bindings);
    } else {
      @diag.error(from, self.loc(), "binding a variant that does not accept argument");
      return pattern;
    }
  }

  pattern
}

pub fn Parser::range_pattern(self: Parser) -> Pattern {
  let pattern = self.composite_pattern();

  if (self.check(IncRange)) {
    let qattern = self.base_pattern();
    return IncRange(pattern, qattern);
  }

  if (self.check(ExcRange)) {
    let qattern = self.base_pattern();
    return ExcRange(pattern, qattern);
  }

  return pattern;
}

pub fn Parser::or_pattern(self: Parser) -> Pattern {
  let pats = [self.range_pattern()];
  
  while (self.checks(Bitor)) {
    pats.push(self.range_pattern());
  }
  
  if (pats.length() == 1) {
    pats[0]
  } else {
    Or(pats)
  }
}

///|
/// Parses a matching pattern.
/// 
pub fn Parser::pattern(self: Parser) -> Pattern {
  self.or_pattern();
}

///|
/// Parses a `match` expression.
/// 
pub fn Parser::matchexpr(self: Parser) -> AST {
  let from = self.peek().loc;
  let matcher = self.expr();
  let branches = [];
  self.expects(LBrace);
  while (not(self.checks(RBrace)) && not(self.eof())) {
    self.strip();
    let pattern = self.pattern();

    self.expects(Arrrow);
    self.strip();
    let stmt = self.stmt();
    
    branches.push((pattern, stmt));
  }

  AST::new(Match(matcher, branches), from, self.loc());
}

///|
/// Parses an f-string (string with embedded expressions).
/// 
/// In lexer, these strings are lexed as-is, and thus must be
/// parsed here.
/// 
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
      'b'  => current.push('\b')
      '\\' => current.push('\\')
      '"'  => current.push('"')
      '\'' => current.push('\'')
      '0'  => current.push('\u0000')
      'u' => {
        let digits = [];
        let loc = from.advance(pos);
        if (ch() == '{') {
          for c = ch(); c != '}'; c = ch() {
            digits.push(c);
          }
          let unicode = parse_int(digits, 16, loc);
          current.push(Int::unsafe_to_char(unicode));
        } else {
          pos -= 1;
          for i in 0..<4 {
            let c = ch();
            if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
              @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
              break;
            }
            digits.push(c);
          }
          let unicode = parse_int(digits, 16, loc);
          current.push(Int::unsafe_to_char(unicode));
        }
      }
      'x' => {
        let digits = [];
        let loc = from.advance(pos);
        for i in 0..<2 {
          let c = ch();
          if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
            @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
            break;
          }
          digits.push(c);
        }
        let unicode = parse_int(digits, 16, loc);
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
        let ast = Parser::new(self.filename, tokens).expr();
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

///|
/// Parses a for loop.
/// 
/// Accepts both forms `for inits; cond; step` and `for x in y`.
/// 
pub fn Parser::forexpr(self: Parser) -> AST {
  let from = self.last().loc;
  let old = self.place;
  let _ = self.consumes();
  if (self.checks(In) || self.checks(Comma)) {
    self.place = old;
    let names = [];
    while (not(self.checks(In)) && not(self.eof())) {
      names.push(self.expect_idents());
      if (not(self.peeks().isa(In))) {
        self.expect(Comma);
      }
    }

    let range = self.expr();
    let body = self.block();
    let mut exit = None;
    if (self.checks(Else)) {
      exit = Some(self.block());
    }
    return AST::new(ForIn(names, range, body, exit), from, self.loc());
  }
  self.place = old;
  let names = [];
  while (not(self.checks(Semicolon)) && not(self.peek().isa(LBrace)) && not(self.eof())) {
    let ident = self.expect_idents();
    self.expects(Assign);
    let val = self.exprs();
    names.push((ident, val));

    if (self.check(Newline)) {
      break;
    }
    if (not(self.peeks().is_any([Semicolon, LBrace]))) {
      self.expect(Comma);
    }
  }

  let cond = if (self.checks(Semicolon) || self.peek().isa(LBrace)) {
    AST::new(Bool(true), self.loc(), self.loc());
  } else {
    let expr = self.exprs();
    self.checks(Semicolon) |> ignore;
    expr
  }

  let steps = [];
  while (not(self.checks(Semicolon)) && not(self.peek().isa(LBrace)) && not(self.eof())) {
    let name = self.expect_idents();
    self.expects(Assign);
    let step = self.exprs();
    steps.push((name, step));
    if (self.check(Newline)) {
      break;
    }
    if (not(self.peeks().is_any([Semicolon, LBrace]))) {
      self.expect(Comma);
    }
  }

  let body = self.block();

  let mut exit = None;
  if (self.checks(Else)) {
    exit = Some(self.block());
  }
  return AST::new(For(names, cond, steps, body, exit), from, self.loc());
}

///|
/// Parses a while loop.
/// 
pub fn Parser::whileexpr(self: Parser) -> AST {
  let from = self.last().loc;
  self.strip();
  let cond = self.expr();
  let body = self.block();
  let mut exit = None;
  if (self.checks(Else)) {
    exit = Some(self.block());
  }
  return AST::new(While(cond, body, exit), from, self.loc());
}

///|
/// Parses a `loop` loop, i.e. a pattern-matching loop.
/// 
pub fn Parser::loopexpr(self: Parser) -> AST {
  let from = self.last().loc;
  let matching = self.matchexpr();

  let mut exit = None;
  if (self.checks(Else)) {
    exit = Some(self.block());
  }

  let _true = AST::new(Bool(true), from, from);
  return AST::new(While(_true, matching, exit), from, self.loc());
}

pub fn Parser::primary(self: Parser) -> AST {
  let from = self.peek().loc;
  let tok = self.consume();
  match (tok.ty) {
    Int(vi, ty) => AST::new(Int(vi, ty), from, self.loc());
    Double(vd, _) => AST::new(Double(vd), from, self.loc());
    Float(vf) => AST::new(Float(vf), from, self.loc());
    Str(vs) => self.fstr(vs);
    RawStr(vs) => AST::new(Str(vs), from, self.loc());
    True => AST::new(Bool(true), from, self.loc());
    False => AST::new(Bool(false), from, self.loc());
    Char(vc) => AST::new(Char(vc), from, self.loc());
    Byte(vb) => AST::new(Byte(vb), from, self.loc());
    ByteStr(vs) => AST::new(ByteStr(vs), from, self.loc());
    Ident(name) => {
      // A function.
      if (self.checks(Arrrow)) {
        let body = self.exprs();
        let detail = FnDetail :: {
          vis: Priv, name: unqualified("__lambda_\{@utils.count()}"),
          params: [name], tyvars: [], kwargs: [],
          body, ty: Function([Unknown], Unknown), ext: None
        }
        return AST::new(FnDecl(detail), from, self.loc());
      }

      AST::new(VarRef(unqualified(name)), from, self.loc());
    }
    LPar => {
      let old = self.place;
      let mut good = true;
      // Try to identify a parameter list.
      let params = [];
      let argTys = [];

      while (not(self.checks(RPar)) && not(self.eof())) {
        if (self.peeks().ty is Ident(w)) {
          self.advance();
          let argname = w;
          let mut ty = Type::Unknown;
          if (self.checks(Colon)) {
            ty = self.typename();
          }
          params.push(argname);
          argTys.push(ty);
        } else {
          good = false;
          break;
        }

        if (not(self.peeks().isa(RPar)) && not(self.check(Comma))) {
          good = false;
          break;
        }
      }
      
      if (good && self.checks(Arrrow)) {
        let body = self.exprs();
        let detail = FnDetail :: {
          vis: Priv, name: unqualified("__lambda_\{@utils.count()}"),
          params, tyvars: [], kwargs: [],
          body, ty: Function(argTys, Unknown), ext: None
        }
        return AST::new(FnDecl(detail), from, self.loc());
      }

      // Failure: not parameter list.
      // Try determine whether this is a unit, tuple or grouping.
      self.place = old;

      let exprs = [];
      while (not(self.checks(RPar)) && not(self.eof())) {
        exprs.push(self.exprs());
        if (not(self.peeks().isa(RPar))) {
          self.expects(Comma);
        }
      }

      if (exprs.is_empty()) {
        AST::new(Unit, from, self.loc())
      } else if (exprs.length() == 1) {
        exprs[0]
      } else {
        AST::new(TupleMake(exprs), from, self.loc())
      }
    }
    LBrace => {
      let old = self.place;
      if (self.checks(Expand)) {
        self.strip();
        let base = self.expr();
        self.expects(Comma);
        
        // Replicated from below.
        let map = Map::new();
        while (not(self.checks(RBrace)) && not(self.eof())) {
          let ident = self.expect_idents();
          map[ident] = if (self.checks(Colon)) {
            self.exprs();
          } else {
            AST::new(VarRef(unqualified(ident)), from, from);
          }

          if (not(self.peek().isa(RBrace))) {
            self.expects(Comma);
          }
        }
        return AST::new(StructModif(base, map), from, self.loc());
      }

      if (self.checks(Ident(""))) {
        // A struct initializer.
        if (self.peeks().is_any([Colon, Comma])) {
          self.place = old;
          let map = Map::new();
          while (not(self.checks(RBrace)) && not(self.eof())) {
            let ident = self.expect_idents();
            map[ident] = if (self.checks(Colon)) {
              self.exprs();
            } else {
              // The name is omitted.
              AST::new(VarRef(unqualified(ident)), from, from);
            }

            if (not(self.peeks().isa(RBrace))) {
              self.expect(Comma);
            }
          }
          return AST::new(StructInit(map), from, self.loc());
        }
      }
      self.place = old - 1;
      self.block();
    }
    For => self.forexpr();
    While => self.whileexpr();
    Loop => self.loopexpr();
    Match => self.matchexpr();
    If => self.ifexpr();
    Fn => self.fndecl(Priv, None);
    Typename(ty) => {
      if (self.check(ColonColon)) {
        // Ty::A(...)
        if (self.peek().isa(Typename(""))) {
          let name = self.expect_typename();
          let exprs = [];
          if (self.check(LPar)) {
            while (not(self.checks(RPar)) && not(self.eof())) {
              exprs.push(self.exprs());
              if (not(self.peeks().isa(RPar))) {
                self.expects(Comma);
              }
            }
          }
          return AST::new(EnumConstr(qualified(ty, name), exprs), from, self.loc());
        }
        // Ty:: { ... }
        if (self.checks(LBrace)) {
          self.retrace();
          let init = self.primary();
          init.ty = Named(unqualified(ty), []);
          return init;
        }

        // Ty::field
        let name = self.expect_ident();
        return AST::new(VarRef(qualified(ty, name)), from, self.loc());
      }
      // Ty(...)
      let exprs = [];
      if (self.check(LPar)) {
        while (not(self.checks(RPar)) && not(self.eof())) {
          exprs.push(self.expr());
          self.strip();

          if (not(self.peek().isa(RPar))) {
            self.expects(Comma);
          }
        }
      }

      return AST::new(EnumConstr(unqualified(ty), exprs), from, self.loc());
    }
    LBracket => {
      let exprs = [];
      while (not(self.checks(RBracket)) && not(self.eof())) {
        exprs.push(self.exprs());

        if (not(self.peeks().isa(RBracket))) {
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
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected \{tok.ty}");
      self.ignore_until([Semicolon, Let, RBrace, Newline]);
      AST::new(Leaf, tok.loc, tok.loc);
    }
  }
}

pub fn Parser::postfix(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.primary();

  fn retrace() {
    self.retrace(); return true;
  }
  
  // Moonbit allows `.` and `..` to be on the next line.
  while (self.peek().is_any([LPar, Dot, LBracket, Double(0, ""), Expand]) ||
        (self.peek().isa(Newline) && self.checks(Dot) && retrace()) ||
        (self.peek().isa(Newline) && self.checks(Expand) && retrace())) {
    if (self.peek().ty is Double(_, w)) {
      self.advance();
      // This is actually things like t.0, t.1;
      // but it's lexed as 't' .0, 't' .1.
      // We have the original representation of the string for this.
      let chars = w.to_array();
      if (chars[0] != '.') {
        @diag.error(from, self.loc(), "unexpected double literal: \{w}");
        continue;
      }
      let ind = parse_int(chars[1:].to_array(), 10, from)
      n = AST::new(TupleAccess(n, ind), from, self.loc());
      continue;
    }

    if (self.check(Dot)) {
      let field = self.expect_idents();
      n = AST::new(FieldRef(n, field), from, self.loc());
      continue;
    }

    let mut chain = None;
    if (self.check(Expand)) {
      chain = Some(self.expect_idents());
      // fallthrough
    }

    if (self.check(LPar)) {
      let args = [];
      let kwargs = Map::new();
      while (not(self.checks(RPar)) && not(self.eof())) {
        self.strip();
        let expr = self.expr();
        if (self.checks(Assign)) {
          if (expr.kind is VarRef(v) && v.pack is None && v.ns is None) {
            kwargs[v.name] = self.exprs();
          } else {
            @diag.error(expr.from, self.loc(), "assignment does not return a value");
          }
        } else if (self.checks(Tilde)) {
          if (expr.kind is VarRef(v) && v.pack is None && v.ns is None) {
            kwargs[v.name] = expr;
          } else {
            @diag.error(expr.from, self.loc(), "a name is expected to precede '~' as named argument");
          }
        } else if (self.checks(Ques)) {
          if (expr.kind is VarRef(v) && v.pack is None && v.ns is None) {
            kwargs[v.name] = expr;
          } else {
            @diag.error(expr.from, self.loc(), "a name is expected to precede '?' as optional argument");
          }
        } else {
          args.push(expr);
        }

        if (not(self.peeks().isa(RPar))) {
          self.expect(Comma);
          self.strip();
        }
      }
      n = if (chain is Some(field)) {
        AST::new(ChainCall(n, field, args, kwargs), from, self.loc());
      } else {
        AST::new(Call(n, args, kwargs), from, self.loc())
      }
      continue;
    }

    if (self.check(LBracket)) {
      let s32 = { signed: true, len: 32 };

      // arr[:x?]
      if (self.checks(Colon)) {
        let min = AST::new(Int(0, s32), from, self.loc());
        // arr[:]
        let max = if (self.checks(RBracket)) {
          AST::new(Int(2147483647, s32), from, self.loc());
        } else {
          let expr = self.expr();
          self.expects(RBracket);
          expr;
        }
        n = AST::new(View(n, min, max), from, self.loc());
        continue;
      }

      let ind = self.expr();
      if (self.checks(Colon)) {
        let max = if (self.checks(RBracket)) {
           AST::new(Int(2147483647, s32), from, self.loc());
        } else {
          let expr = self.expr();
          self.expects(RBracket);
          expr;
        }
        n = AST::new(View(n, ind, max), from, self.loc());
        continue;
      }
      
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
    self.strip();
    let n = self.prefix();
    return AST::new(Unary(Minus, n), from, self.loc());
  }

  if (self.check(Bang)) {
    self.strip();
    let n = self.prefix();
    return AST::new(Unary(Not, n), from, self.loc());
  }
  if (self.check(Expand)) {
    self.strip();
    let n = self.prefix();
    return AST::new(Unary(Expand, n), from, self.loc());
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
    self.strip();
    let x = self.prefix();
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
    self.strip();
    let x = self.mul();
    n = AST::new(Binary(kind, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::shift(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.add();
  while (self.peek().is_any([Lsh, Rsh])) {
    let kind: BinaryKind = match (self.consume().ty) {
      Lsh => Lsh
      Rsh => Rsh
      _ => panic()
    }
    self.strip();
    let x = self.add();
    n = AST::new(Binary(kind, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::ismatch(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.shift();
  while (self.check(Is)) {
    self.strip();
    let x = self.pattern();
    n = AST::new(Is(n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::cmp(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.ismatch();
  while (self.peek().is_any([Lt, Gt, Ge, Le])) {
    let cmp = self.consume().ty;
    self.strip();
    let x = self.ismatch();
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
  while (self.peek().is_any([Ne, Eq])) {
    let cmp = self.consume().ty;
    self.strip();
    let x = self.cmp();
    let binary = match cmp {
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
    self.strip();
    let x = self.eq();
    n = AST::new(Binary(Bitand, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::xor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.bitand();
  while (self.check(Xor)) {
    self.strip();
    let x = self.bitand();
    n = AST::new(Binary(Xor, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::bitor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.xor();
  while (self.check(Bitor)) {
    self.strip();
    let x = self.xor();
    n = AST::new(Binary(Bitor, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::logand(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.bitor();
  while (self.check(Logand)) {
    self.strip();
    let x = self.bitor();
    n = AST::new(Binary(And, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::logor(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.logand();
  while (self.check(Logor)) {
    self.strip();
    let x = self.logand();
    n = AST::new(Binary(Or, n, x), from, self.loc());
  }
  return n;
}

pub fn Parser::range(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.logor();
  while (self.peek().is_any([ExcRange, IncRange])) {
    let tok = self.consume();
    let x = self.logor();
    match tok.ty {
      ExcRange => n = AST::new(ExcRange(n, x), from, self.loc());
      IncRange => n = AST::new(IncRange(n, x), from, self.loc());
      _ => panic()
    }
  }
  return n;
}

pub fn Parser::pipe(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut n = self.range();
  // Pipe is allowed to appear on a new line.
  while (self.checks(Pipe)) {
    let x = self.range();
    if (x.kind is Call(func, w, kwargs)) {
      n = AST::new(Call(func, [n, ..w], kwargs), from, self.loc());
    } else {
      n = AST::new(Call(x, [n], Map::new()), from, self.loc());
    }
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
  return self.pipe();
}

pub fn Parser::cast(self: Parser) -> AST {
  let n = self.tryres();
  // Moonbit does not support things like `10: Byte: Int`.
  // EXTENSION: we regard this as a C-style forced cast, rather than an annotation.
  if (self.checks(Colon)) {
    if (not(self.peek().isa(Typename("")))) {
      // This is a view like a[1:2].
      self.retrace();
    } else {
      n.ty = self.typename();
    }
  }
  return n;
}

pub fn Parser::expr(self: Parser) -> AST {
  return self.cast();
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
      // Tuple declaration.
      if (self.checks(LPar)) {
        let names = [];
        while (not(self.checks(RPar)) && not(self.eof())) {
          names.push(self.expect_ident());
          if (not(self.peek().isa(RPar))) {
            self.expects(Comma);
          }
        }
        let mut ty = None;
        if (self.checks(Colon)) {
          ty = Some(self.typename());
        }
        self.expects(Assign);
        let init = self.exprs();
        self.semicolon();
        return AST::new(TupleDecl(names, init, ty.or(Unknown)), from, self.loc());
      }

      // Struct declaration.
      if (self.checks(LBrace)) {
        self.retrace();
        let pattern = self.pattern();
        let mut ty = None;
        if (self.checks(Colon)) {
          ty = Some(self.typename());
        }
        self.expects(Assign);
        let init = self.exprs();
        self.semicolon();
        return AST::new(StructLet(pattern, init, ty.or(Unknown)), from, self.loc());
      }

      // Enum declaration.
      if (self.peeks().ty is Typename(_)) {
        self.advance();
        let pattern = self.pattern();
        let mut ty = None;
        if (self.checks(Colon)) {
          ty = Some(self.typename());
        }
        self.expects(Assign);
        let init = self.exprs();
        self.semicolon();
        return AST::new(EnumLet(pattern, init, ty.or(Unknown)), from, self.loc());
      }

      let mutable = self.checks(Mut);
      let name = self.expect_idents();
      let mut ty = None;
      if (self.checks(Colon)) {
        ty = Some(self.typename());
      }
      self.expects(Assign);
      let init = self.exprs();
      self.semicolon();
      return AST::new(VarDecl({ name, mutable, init, ty: ty.or(Unknown) }), from, self.loc());
    }
    Return => {
      if (self.peek().is_any([Newline, Semicolon, RBrace])) {
        self.advance();
        return AST::new(Return(None), from, self.loc());
      }
      let expr = self.expr();
      self.semicolon();
      return AST::new(Return(Some(expr)), from, self.loc());
    }
    Break => {
      if (self.peek().is_any([Newline, Semicolon, RBrace])) {
        self.advance();
        return AST::new(Break(None), from, self.loc());
      }
      let expr = self.expr();
      self.semicolon();
      return AST::new(Break(Some(expr)), from, self.loc());
    }
    Continue => {
      let exprs = []
      while (not(self.peek().is_any([Newline, Semicolon]))) {
        exprs.push(self.expr());
        if (not(self.peek().is_any([Newline, Semicolon]))) {
          self.expect(Comma);
          self.strip();
        }
      }
      self.semicolon();
      return AST::new(Continue(exprs), from, self.loc());
    }
    Guard => {
      let cond = self.exprs();
      let mut other = None;
      if (self.checks(Else)) {
        other = Some(self.block());
      }
      self.semicolon();
      AST::new(Guard(cond, other), from, self.loc());
    }
    Raise => {
      let expr = self.exprs();
      AST::new(Unary(Raise, expr), from, self.loc());
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
    self.strip();
    if (self.check(EOF)) {
      @diag.error(from, from.advance(1), "left brace is never closed");
      break;
    }
  }
  return AST::new(Block(content), from, self.loc());
}

pub fn Parser::tyvar(self: Parser) -> Typevar {
  let name = if (self.peek().ty is Ident("_")) {
    self.advance(); "_"
  } else {
    self.expect_typename();
  }

  if (not(self.checks(Colon))) {
    return { name, extend: [] }
  }
  let extend = [self.qualified_typename()];
  while (self.checks(Plus)) {
    extend.push(self.qualified_typename());
  }
  { name, extend }
}

pub fn Parser::deriving(self: Parser) -> Array[Name] {
  let deriving = [];
  if (self.checks(Derive)) {
    self.expects(LPar);
    while (not(self.checks(RPar)) && not(self.eof())) {
      let name = self.qualified_typename();
      deriving.push(name);
      if (not(self.peek().isa(RPar))) {
        self.expects(Comma);
      }
    }
  }
  deriving
}

pub fn Parser::fndecl(self: Parser, vis: Visible, ext: String?) -> AST {
  self.strip();
  let from = self.peek().loc;
  
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
    unqualified("__lambda_\{@utils.count()}")
  };

  let params = [];
  let argTys = [];
  let kwargs = [];
  let special = ["main", "init"].contains(name.name);
  let matching = not(special) && not(self.peeks().isa(LPar));

  if (not(special) && not(matching)) {
    self.expects(LPar);
    self.strip();
    while (not(self.checks(RPar)) && not(self.eof())) {
      let argname = self.expect_idents();
      let loc = self.peek().loc;
      let is_kwarg = self.checks(Tilde);
      let is_opt = self.checks(Ques);
      if (is_kwarg && is_opt) {
        @diag.error(loc, self.loc(), "modifiers '~' and '=' cannot appear together")
      }

      let mut ty = Type::Unknown;
      if (self.checks(Colon)) {
        ty = self.typename();
      }
      if (is_kwarg) {
        let mut default = None;
        if (self.checks(Assign)) {
          default = Some(self.exprs());
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
    }
  }
  // Check the optional return type.
  let mut retTy = Type::Unknown;
  if (self.checks(Arrow)) {
    retTy = self.typename();
  }

  let body = if (self.checks(Assign)) {
    // An FFI body.
    let tok = self.consumes();
    let endloc = tok.loc.advance(tok.len);
    match tok.ty {
      Str(w) | RawStr(w) => AST::new(FFIBody(w), tok.loc, endloc)
      _ => {
        @diag.error(tok.loc, endloc, "expected a string literal as external function name");
        AST::new(Leaf, tok.loc, endloc);
      }
    }
  } else if (matching) {
    let from = self.peek().loc;
    params.push("__matcher");
    // This is a match expression.
    let branches = [];
    self.expects(LBrace);
    while (not(self.checks(RBrace)) && not(self.eof())) {
      let pattern = self.pattern();
      self.expects(Arrrow);
      let stmt = self.stmt();
      branches.push((pattern, stmt));
    }
    let varref = AST::new(VarRef(unqualified("__matcher")), from, from);
    AST::new(Match(varref, branches), from, self.loc());
  } else {
    self.block();
  }
  
  let ty = Function(argTys, retTy);
  let ast = AST::new(FnDecl({ vis, name, params, tyvars, body, ty, kwargs, ext }), from, self.loc());
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}

pub fn Parser::structdecl(self: Parser, vis: Visible, ext: String?) -> AST {
  self.strip();
  let from = self.peek().loc;
  let name = self.expect_typename();

  let tyvars = self.tyvars();

  let fields = [];
  self.expect(LBrace);
  self.strip();
  while (not(self.check(RBrace)) && not(self.eof())) {
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
  let deriving = self.deriving();
  let detail = StructDetail :: {
    vis,
    name: unqualified(name),
    entries: Map::from_array(fields.map(fn (x) { (x.name, x) })),
    tyvars, deriving, ext
  };
  let ast = AST::new(StructDecl(detail), from, self.loc());
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}

pub fn Parser::enumdecl(self: Parser, vis: Visible, ext: String?) -> AST {
  self.strip();
  let from = self.peek().loc;
  let name = self.expect_typename();

  let tyvars = self.tyvars();

  let variants = [];
  self.expect(LBrace);
  self.strip();
  while (not(self.check(RBrace)) && not(self.eof())) {
    let name = self.expect_typename();
    let tys = [];
    // No newline allowed.
    if (self.check(LPar)) {
      while (not(self.check(RPar)) && not(self.eof())) {
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
  let deriving = self.deriving();
  let detail = EnumDetail :: {
    vis,
    name: unqualified(name),
    entries: Map::from_array(variants.map(fn (x) { (x.0, { tys: x.1, named: Map::new() }) })),
    tyvars, deriving, error: false, ext
  };
  let ast = AST::new(EnumDecl(detail), from, self.loc());
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}

pub fn Parser::globaldecl(self: Parser, vis: Visible, ext: String?) -> AST {
  let from = self.peek().loc;
  let name = self.expect_idents();
  let mut ty = None;
  if (self.checks(Colon)) {
    ty = Some(self.typename());
  }
  self.expects(Assign);
  let init = self.exprs();
  self.semicolon();
  let detail = GlobalDetail :: {
    vis, ext, init,
    name: unqualified(name),
    ty: ty.or(Unknown)
  };
  let ast = AST::new(GlobalDecl(detail), from, self.loc());
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}

pub fn Parser::constdecl(self: Parser, vis: Visible, ext: String?) -> AST {
  let from = self.peek().loc;
  self.strip();
  let name = self.expect_typename();
  let mut ty = None;
  if (self.checks(Colon)) {
    ty = Some(self.typename());
  }
  self.expects(Assign);
  let init = self.exprs();
  self.semicolon();
  let detail = GlobalDetail :: {
    name: unqualified(name),
    init, ext, vis,
    ty: ty.or(Unknown)
  };
  let ast = AST::new(GlobalDecl(detail), from, self.loc());
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}


pub fn Parser::qualified_typename(self: Parser) -> Name {
  let mut pack = None;
  if (self.peek().ty is Packname(x)) {
    pack = Some(x);
  }
  let name = self.expect_typename();
  let mut name = unqualified(name);
  if (pack is Some(x)) {
    name = name.pack(x);
  }
  name;
}

pub fn Parser::qualified_name(self: Parser) -> Name {
  let mut pack = None;
  if (self.peek().ty is Packname(x)) {
    pack = Some(x);
    self.advance();
    self.expects(Dot);
    self.strip();
  }
  let name = self.expect_ident();
  let mut name = unqualified(name);
  if (pack is Some(x)) {
    name = name.pack(x);
  }
  name;
}

pub fn Parser::impldecl(self: Parser, vis: Visible, ext: String?) -> AST {
  let from = self.peek().loc;
  let tyvars = self.tyvars();

  self.strip();
  let ntrait = self.qualified_typename();

  self.expects(For);
  self.strip();
  let nstruct = self.typename();

  self.expects(With);
  let nfunc = self.expect_idents();
  let params = [];
  let argTys = [];

  self.expects(LPar);
  while (not(self.checks(RPar)) && not(self.eof())) {
    let argname = self.expect_idents();
    let mut ty = Type::Unknown;
    if (self.checks(Colon)) {
      ty = self.typename();
    }
    params.push(argname);
    argTys.push(ty);

    if (not(self.peeks().isa(RPar))) {
      self.expects(Comma);
    }
  }
  
  // Check the optional return type.
  let mut retTy = Type::Unknown;
  self.strip();
  if (self.check(Arrow)) {
    retTy = self.typename();
  }

  let body = if (self.checks(Assign)) {
    // An FFI body.
    let tok = self.consumes();
    let endloc = tok.loc.advance(tok.len);
    match tok.ty {
      Str(w) | RawStr(w) => AST::new(FFIBody(w), tok.loc, endloc)
      _ => {
        @diag.error(tok.loc, endloc, "expected a string literal as external function name");
        AST::new(Leaf, tok.loc, endloc);
      }
    }
  } else {
    self.block();
  }
  
  let detail = ImplDetail :: {
    vis, ext,
    nstruct, ntrait, nfunc, params, body, tyvars,
    ty: Function(argTys, retTy)
  };
  let ast = AST::new(ImplDecl(detail), from, self.loc());
  ast.ty = Function(argTys, retTy);
  ast.attr = self.attr;
  self.attr.clear();
  return ast;
}

pub fn Parser::aliasfn(self: Parser, vis: Visible) -> AST {
  let from = self.peek().loc;
  let src = self.qualified_name();
  let mut tgt = src;
  if (self.checks(As)) {
    tgt = self.qualified_name();
  }
  AST::new(Fnalias(vis, src, tgt), from, self.loc());
}

pub fn Parser::aliasty(self: Parser, vis: Visible) -> AST {
  let from = self.peek().loc;
  let src = self.typename();
  let mut tgt = src;
  if (self.checks(As)) {
    tgt = self.typename();
    return AST::new(Typealias(vis, src, tgt), from, self.loc());
  }
  if (src is Named(name, tyvars)) {
    return AST::new(Typealias(vis, src, Named(name.unpack(), tyvars)), from, self.loc());
  }
  @diag.error(from, self.loc(), "aliasing non-user defined type");
  return AST::new(Leaf, from, self.loc());
}

pub fn Parser::tyvars(self: Parser) -> Array[Typevar] {
  let tyvars = [];
  if (self.checks(LBracket)) {
    while (not(self.checks(RBracket)) && not(self.eof())) {
      tyvars.push(self.tyvar());
      if (not(self.peeks().isa(RBracket))) {
        self.expects(Comma);
      }
    }
  }
  tyvars
}

///|
/// Parses a top-level type declaration:
/// 
/// The modifier `pub(all)` etc. are handled in `toplevel().
/// 
pub fn Parser::tydecl(self: Parser, vis: Visible, ext: String?, error: Bool) -> AST {
  self.strip();
  let from = self.peek().loc;

  let name = self.expect_typename();
  let name = unqualified(name);
  let tyvars = self.tyvars();
  let tys = [];
  if (not(self.check(Newline) || self.check(Semicolon))) {
    // Either there's nothing, or there's a single typename.
    tys.push(self.typename());
  }

  let deriving = self.deriving();
  self.semicolon();

  let detail = EnumDetail :: {
    entries: Map::from_array([("__mem", { tys, named: Map::new() })]),
    name, tyvars, deriving, error, ext, vis
  }
  AST::new(EnumDecl(detail), from, self.loc())
}

pub fn Parser::attribute(self: Parser, name: String) -> Unit {
  let from = self.peek().loc;
  let kwargs = Map::new();
  let args = [];
  if (self.check(LPar)) {
    while (not(self.checks(RPar)) && not(self.eof())) {
      let tok = self.consumes();
      if (tok.ty is Str(w)) {
        args.push(w);
      } else if (tok.ty is Ident(x)) {
        if (self.checks(Assign)) {
          let next = self.consumes();
          if (next.ty is Str(w)) {
            kwargs[x] = w;
          } else {
            @diag.error(from, self.loc(), "unexpected attribute entry");
          }
        } else {
          args.push(x);
        }
      } else {
        @diag.error(from, self.loc(), "unexpected attribute entry");
      }
      if (not(self.peeks().isa(RPar))) {
        self.expect(Comma);
      }
    }
  }
  self.attr.push({ name, args, kwargs });
}

pub fn Parser::testdecl(self: Parser) -> AST {
  let from = self.peek().loc;
  let mut tok = self.consumes();
  let mut name = None;
  if (tok.ty is Str(w)) {
    name = Some(w);
    tok = self.consumes();
  }
  if (not(tok.isa(LBrace))) {
    @diag.error(from, self.loc(), "a block should follow 'test'");
  }
  self.retrace();
  let body = self.block();
  AST::new(Test(name, body), from, self.loc())
}

///|
/// Parses a function declaration inside a trait.
/// 
pub fn Parser::trait_fn(self: Parser) -> FnDetail {
  self.strip();
  
  let tyvars = self.tyvars();
  let name = unqualified(self.expect_ident())

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
      if (self.checks(Colon)) {
        ty = self.typename();
      }
    } else {
      ty = self.typename();
    }
    
    if (is_kwarg) {
      let mut default = None;
      if (self.checks(Assign)) {
        default = Some(self.exprs());
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
  
  // Check the optional return type.
  let mut retTy = Type::Unknown;
  if (self.checks(Arrow)) {
    retTy = self.typename();
  }

  let ty = Function(argTys, retTy);
  let body = AST::new(Block([]), Loc::unknown(), Loc::unknown());
  return { vis: Priv, name, params, tyvars, body, ty, kwargs, ext: None };
}


///|
/// Parses a trait declaration.
/// 
pub fn Parser::traitdecl(self: Parser, vis: Visible) -> AST {
  let from = self.last().loc;
  self.strip();
  let name = unqualified(self.expect_typename());
  let tyvars = self.tyvars();
  let funcs = [];
  self.expects(LBrace);
  while (not(self.checks(RBrace)) && not(self.eof())) {
    funcs.push(self.trait_fn());

    if (self.peek().isa(RBrace)) {
      self.semicolon();
    }
    self.strip();
  }

  let detail = TraitDetail :: { vis, name, tyvars, funcs };
  AST::new(TraitDecl(detail), from, self.loc());
}

///|
/// Parses a toplevel declaration.
/// 
/// The arguments carry over visibility and extern information.
/// 
pub fn Parser::toplevel(self: Parser, vis: Visible, ext: String?) -> AST {
  let tok = self.consume();

  fn noext(f) {
    if (ext is Some(_)) {
      @diag.error(tok.loc, self.loc(), "'extern' isn't allowed for this top-level definition");
    }
    f(vis);
  }

  match (tok.ty) {
    Fn => self.fndecl(vis, ext);
    Struct => self.structdecl(vis, ext);
    Enum => self.enumdecl(vis, ext);
    Let => self.globaldecl(vis, ext);
    Const => self.constdecl(vis, ext);
    Impl => self.impldecl(vis, ext);
    EOF => AST::new(Leaf, Loc::unknown(), Loc::unknown());
    Newline | Semicolon => self.toplevel(vis, ext);
    Fnalias => noext((vis) => self.aliasfn(vis));
    Typealias => noext((vis) => self.aliasty(vis));
    Trait => noext((vis) => self.traitdecl(vis));
    Type => self.tydecl(vis, ext, self.checks(Bang));
    Suberror => self.tydecl(vis, ext, true);
    Test => {
      if (vis != Priv) {
        @diag.warning(tok.loc, self.loc(), WPubTest);
      }
      self.testdecl();
    }
    Attribute(name) => { self.attribute(name); self.toplevel(vis, ext) }
    Pub | Pubopen | Puball | Priv => {
      self.retrace();
      let vis = self.vis();
      return self.toplevel(vis, ext);
    }
    Extern => {
      if (self.peeks().ty is Str(x)) {
        self.advance();
        return self.toplevel(vis, Some(x));
      }
      return self.toplevel(vis, Some("default"));
    }
    _ => {
      @diag.error(tok.loc, tok.loc.advance(tok.len), "unexpected top-level token \{tok.ty}");
      self.ignore_until([Fn, Struct, Enum]);
      if (not(self.eof())) {
        self.retrace();
      }
      return self.toplevel(vis, ext);
    }
  }
}

///|
/// Handles a translation unit.
/// 
/// It produces a block containing all toplevel declarations and definitions.
/// 
pub fn Parser::toplevel_block(self: Parser) -> AST {
  let top = [];

  while (not(self.eof())) {
    let ast = self.toplevel(Priv, None);
    if (ast.kind is Leaf) {
      break;
    }
    top.push(ast);
  }
  return AST::new(Block(top), self.data[0].loc, self.loc());
}

///|
/// Entry point of parsing.
/// 
pub fn Parser::parse(self: Parser) -> AST {
  if self.data.length() == 0 {
    return AST::new(Leaf, Loc::unknown(), Loc::unknown())
  }
  let top = self.toplevel_block();
  return top.tidy();
}
