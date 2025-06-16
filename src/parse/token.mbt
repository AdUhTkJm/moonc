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
  Return
  If
  Else
  Struct
  Pub
  Pubopen
  Puball
  Priv
  While
  For
  Mut

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
  Percent           // %
  PlusEq            // +=
  MinusEq           // -=
  StarEq            // *=
  SlashEq           // /=
  PercentEq         // %=
  Ques              // ?
  Bang              // !
  Comma             // ,
  Colon             // :
  ColonColon        // ::
  Assign            // =
  Eq                // ==
  Lt                // <
  Le                // <=
  Gt                // >
  Ge                // >=
  Ne                // !=
  Arrow             // ->
  Arrrow            // =>
  Dot               // .

  // Special
  EOF
  Unknown
  Newline
} derive(Eq, Hash)

pub impl Show for TokenType with to_string(self) -> String {
  match (self) {
    EOF => "<EOF>"
    Colon => "':'"
    ColonColon => "'::'"
    Comma => "','"
    Bang => "'!'"
    Ques => "'?'"
    Plus => "'+'"
    Minus => "'-'"
    Star => "'*'"
    Slash => "'/'"
    Percent => "'%'"
    PlusEq => "'+='"
    MinusEq => "'-='"
    StarEq => "'*='"
    SlashEq => "'/='"
    PercentEq => "'%='"
    LPar => "'('"
    RPar => "')'"
    LBracket => "'['"
    RBracket => "']'"
    Semicolon => "';'"
    LBrace => "'{'"
    RBrace => "'}'"
    Assign => "'='"
    Eq => "'=='"
    Le => "'<='"
    Lt => "'<'"
    Gt => "'>'"
    Ge => "'>='"
    Ne => "'!='"
    Arrow => "'->'"
    Arrrow => "'=>'"
    Dot => "'.'"
    Fn => "fn"
    Let => "let"
    Return => "return"
    If => "if"
    Else => "else"
    Struct => "struct"
    Pub => "pub"
    Pubopen => "pub(open)"
    Puball => "pub(all)"
    Priv => "priv"
    While => "while"
    For => "for"
    Mut => "mut"
    Str(_) => "string literal"
    FP(_) => "floating-point literal"
    Int(_) => "integer literal"
    Typename(_) => "type name"
    Ident(_) => "identifier"
    Unknown => "unknown"
    Newline => "newline"
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
