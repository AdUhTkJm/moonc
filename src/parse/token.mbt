pub(all) enum TokenType {
  // Literals
  Ident(String)     // [a-z_][\w_\d]*
  Typename(String)  // [A-Z][\w_\d]*
  Int(Int)          // 0 ~ 2147483647
  FP(Double)        // Floating point literals, ending with .F
  Str(String)       // "[^"]*"

  // Keywords
  Let
  Fn

  // Operators
  LBrace            // {
  RBrace            // }
  Semicolon         // ;
  LBracket          // [
  RBracket          // ]
  LPar              // (
  RPar              // )
  Plus              // +
  Minus             // -
  Star              // *
  Slash             // /
  Ques              // ?
  Bang              // !
  Comma             // ,
  Colon             // :
  Eq                // =

  // Special
  EOF
  Unknown
} derive(Eq, Hash)

pub impl Show for TokenType with to_string(self) -> String {
  match (self) {
    EOF => "<EOF>"
    Colon => "':'"
    Comma => "','"
    Bang => "'!'"
    Ques => "'?'"
    Slash => "'/'"
    Star => "'*'"
    Minus => "'-'"
    Plus => "'+'"
    LPar => "'('"
    RPar => "')'"
    LBracket => "'['"
    RBracket => "']'"
    Semicolon => "';'"
    LBrace => "'{'"
    RBrace => "'}'"
    Eq => "'='"
    Fn => "fn"
    Let => "let"
    Str(_) => "string literal"
    FP(_) => "floating-point literal"
    Int(_) => "integer literal"
    Typename(_) => "type name"
    Ident(_) => "identifier"
    Unknown => "unknown"
  }
}

pub impl Show for TokenType with output(self, writer) -> Unit {
  writer.write_string(self.to_string())
}

pub struct Token {
  ty: TokenType
  loc: @diag.Loc
  len: Int
} derive(Show)

pub fn Token::new(ty: TokenType, loc: @diag.Loc, len: Int) -> Token {
  return { ty: ty, loc: loc, len: len };
}

pub fn Token::isa(self: Token, ty: TokenType) -> Bool {
  if (ty == self.ty) {
    return true;
  }
  match (ty, self.ty) {
    (Ident(_), Ident(_)) => true
    (Typename(_), Typename(_)) => true
    (Int(_), Int(_)) => true
    (FP(_), FP(_)) => true
    (Str(_), Str(_)) => true
    _ => false
  }
}

pub fn Token::is_any(self: Token, tys: Array[TokenType]) -> Bool {
  return @utils.any(tys, fn (ty) { self.isa(ty) });
}
