///|
/// Type of int literal. Here `len` is the number of bits inside the int.
/// 
/// For bigint with arbitrary precision, we use `len = -1`.
/// 
pub(all) struct IntTy {
  len: Int
  signed: Bool
} derive(Eq)

pub(all) enum TokenType {
  // Literals
  Ident(String)         // [a-z_][\w_\d]*
  Typename(String)      // [A-Z][\w_\d]*
  Int(BigInt,IntTy)     // [\d]+
  Double(Double,String) // Double literal, along with the original string
  Float(Float)          // Float literal
  Str(String)           // "[^"]*"
  RawStr(String)        // #|.*
  Char(Char)            // '?'
  Packname(String)      // @[\w\d_]+
  Attribute(String)     // #[\w\d_]+
  Byte(Byte)            // b'?'
  ByteStr(Bytes)        // b"str"

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
  Enum
  Trait
  Impl
  With
  Match
  Extern
  Type
  Break
  Continue
  True
  False
  In
  Try
  Derive
  Is
  Typealias
  Fnalias
  As
  Guard
  Raise
  Test
  Const
  Suberror
  Loop

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
  IncRange          // ..=
  ExcRange          // ..<
  Bitand            // &
  Bitor             // |
  Xor               // ^
  Logand            // &&
  Logor             // ||
  AndEq             // &=
  OrEq              // |=
  XorEq             // ^=
  Expand            // ..
  Pipe              // |>
  Hash              // #
  Tilde             // ~
  Lsh               // <<
  Rsh               // >>

  // Special
  EOF
  Unknown
  Newline
} derive(Eq)

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
    IncRange => "'..='"
    ExcRange => "'..<'"
    Bitand => "'&'"
    Bitor => "'|'"
    Xor => "'^'"
    Logand => "'&&'"
    Logor => "'||'"
    AndEq => "'&='"
    OrEq => "'|='"
    XorEq => "'^='"
    Expand => "'..'"
    Pipe => "'|>'"
    Hash => "'#'"
    Tilde => "'~'"
    Lsh => "'<<'"
    Rsh => "'>>'"
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
    Enum => "enum"
    Trait => "trait"
    Match => "match"
    Impl => "impl"
    With => "with"
    Extern => "extern"
    Type => "type"
    Break => "break"
    Continue => "continue"
    True => "true"
    False => "false"
    In => "in"
    Try => "try"
    Derive => "derive"
    Is => "is"
    Typealias => "typealias"
    Fnalias => "fnalias"
    As => "as"
    Guard => "guard"
    Raise => "raise"
    Test => "test"
    Const => "const"
    Suberror => "suberror"
    Loop => "loop"
    Str(x) => "string literal \"\{x}\""
    RawStr(x) => "raw string literal \"\{x}\""
    Double(_, str) => "double literal \{str}"
    Float(x) => "float literal \{x}"
    Int(x, _) => "int literal \{x}"
    Typename(x) => "type name '\{x}'"
    Ident(x) => "identifier '\{x}'"
    Char(x) => "char '\{x}'"
    Packname(x) => "package name '\{x}'"
    Attribute(x) => "attribute name '\{x}'"
    Byte(x) => "byte literal \{x}"
    ByteStr(x) => "byte string \{x}"
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
    (Double(_), Double(_)) => true
    (Float(_), Float(_)) => true
    (Str(_), Str(_)) => true
    (Char(_), Char(_)) => true
    (Packname(_), Packname(_)) => true
    (Attribute(_), Attribute(_)) => true
    _ => false
  }
}

pub fn Token::is_any(self: Token, tys: Array[TokenType]) -> Bool {
  return @utils.any(tys, fn (ty) { self.isa(ty) });
}
