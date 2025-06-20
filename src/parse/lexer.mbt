pub struct Lexer {
  mut loc: Int
  data: Array[Char]
  filename: String
}

pub fn Lexer::new(filename: String, code: String) -> Lexer {
  @diag.add_file(filename, code);
  return {
    loc: 0,
    data: (code + "\n\u0000").to_array(),
    filename: filename
  }
}

pub fn Lexer::lex(self: Lexer) -> Array[Token] {
  let tokens = [];
  while (self.has_next()) {
    tokens.push(self.next());
  }
  let tokens = merge_str(tokens);
  return tokens;
}

fn Lexer::ch(self: Lexer) -> Char {
  if (self.loc >= self.data.length()) {
    return '\u0000';
  }
  let ch = self.data[self.loc];
  self.loc += 1;
  return ch;
}

fn Lexer::peek(self: Lexer, i: Int) -> Char {
  if (self.loc + i >= self.data.length()) {
    return '\u0000';
  }
  return self.data[self.loc + i];
}

fn Lexer::advance(self: Lexer, i: Int) -> Unit {
  self.loc += i;
}

fn Lexer::check(self: Lexer, str: String) -> Bool {
  let arr = str.to_array();
  let len = arr.length();
  for i in 0..<len {
    if (self.peek(i) != arr[i]) {
      return false;
    }
  }
  self.advance(len);
  return true;
}

fn Lexer::retrace(self: Lexer) -> Unit {
  self.loc -= 1;
}

pub fn parse_int(digits: Array[Char], base: Int, from: @diag.Loc) -> Int {
  let str = String::from_array(digits);
  match (try? @strconv.parse_int(str, base=base)) {
    Ok(x) => x
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid int literal \{str} under base \{base}");
      0
    }
  }
}

pub fn parse_double(digits: Array[Char], from: @diag.Loc) -> Double {
  let str = String::from_array(digits);
  match (try? @strconv.parse_double(str)) {
    Ok(x) => x;
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid double: \{str}");
      0
    }
  }
}

pub fn parse_float(digits: Array[Char], from: @diag.Loc) -> Float {
  let str = String::from_array(digits);
  match (try? @strconv.parse_double(str)) {
    Ok(x) => x.to_float();
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid float: \{str}");
      0
    }
  }
}

fn parse_bigint(digits: Array[Char], base: Int) -> BigInt {
  let x = String::from_array(digits);
  if (base == 10) {
    return BigInt::from_string(x);
  }
  if (base == 16) {
    return BigInt::from_hex(x);
  }
  let base = BigInt::from_int(base);
  let mut result = BigInt::from_int(0);
  for i in digits {
    result = result * base + BigInt::from_int(i.to_int() - 48)
  }
  return result;
}

fn de_escape(loc: Loc, str_: String) -> String {
  let str = str_.to_array();
  let mut pos = 0;
  let mut loc = loc;

  let ch = () => {
    let c = str[pos];
    pos += 1;
    loc = loc.advance(1);
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
        if (ch() == '{') {
          for c = ch(); c != '}'; c = ch() {
            digits.push(c);
          }
          let unicode = parse_int(digits, 16, loc);
          current.push(Int::unsafe_to_char(unicode));
        } else {
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
      _ => {
        @diag.error(loc, loc.advance(1), "unknown escape sequence");
      }
      }
    }
    c => current.push(c);
    }
  }
  return String::from_array(current);
}

fn merge_str(tokens: Array[Token]) -> Array[Token] {
  if tokens.is_empty() {
    return tokens;
  }
  
  let result = [];
  let mut i = 0;
  
  while (i < tokens.length()) {
    let current = tokens[i]
    
    if (current.ty is RawStr(content)) {
      let mut merged = content;
      let loc = current.loc;
      let mut len = current.len;
      
      i += 1;
      while i < tokens.length() {
        match tokens[i].ty {
          RawStr(next_content) => {
            merged = merged + next_content;
            len += tokens[i].len;
            i += 1;
          }
          _ => break;
        }
      }
      
      result.push(Token::new(RawStr(merged), loc, len));
    }
    else {
      result.push(current);
      i += 1;
    }
  }
  
  result
}

pub fn Lexer::read_str(self: Lexer) -> String {
  let loc = @diag.Loc::new(self.filename, self.loc - 1);
  let result = [];
  while true {
    let c = self.ch();
    match c {
      '\u0000' => {
        @diag.error(loc, loc.advance(1), "unterminated string literal");
        break;
      }
      '"' => {
        // Check if the quote is escaped
        if (result.ends_with(['\\'])) {
          // It could be an escaped backslash (\\") or an actual escape (\")
          // We need to check how many backslashes precede this quote
          let mut slash = 0;
          for ch in result.rev_iter() {
            if ch == '\\' {
              slash += 1;
            } else {
              break;
            }
          }
          if slash % 2 == 1 {
            result.push('"'); // Escaped
            continue;
          }
          // Not escaped
          break;
        }
        break;
      }
      // Other escape characters are left for parser.
      _ => {
        result.push(c);
      }
    }
  }
  String::from_array(result)
}

pub fn Lexer::next(self: Lexer) -> Token {
  let loc = @diag.Loc::new(self.filename, self.loc);
  let c = self.ch();
  match c {
    '{' => Token::new(LBrace, loc, 1)
    '}' => Token::new(RBrace, loc, 1)
    '(' => Token::new(LPar, loc, 1)
    ')' => Token::new(RPar, loc, 1)
    '[' => Token::new(LBracket, loc, 1)
    ']' => Token::new(RBracket, loc, 1)
    ',' => Token::new(Comma, loc, 1)
    ';' => Token::new(Semicolon, loc, 1)
    '?' => Token::new(Ques, loc, 1)
    '~' => Token::new(Tilde, loc, 1)
    
    '+' => {
      if (self.check("=")) {
        return Token::new(PlusEq, loc, 2);
      }
      Token::new(Plus, loc, 1) 
    }
    '-' => {
      if (self.check(">")) {
        return Token::new(Arrow, loc, 2);
      }
      if (self.check("=")) {
        return Token::new(MinusEq, loc, 2);
      }
      Token::new(Minus, loc, 1)
    }
    '*' => {
      if (self.check("=")) {
        return Token::new(StarEq, loc, 2);
      }
      Token::new(Star, loc, 1) 
    }
    '/' => {
      if (self.check("/")) {
        for c = self.ch(); not(c is '\n'); c = self.ch() { }
        self.retrace();
        return self.next();
      }
      if (self.check("=")) {
        return Token::new(SlashEq, loc, 2);
      }
      Token::new(Slash, loc, 1)
    }
    '%' => {
      if (self.check("=")) {
        return Token::new(PercentEq, loc, 2);
      }
      Token::new(Percent, loc, 1)
    }
    '=' => {
      if (self.check("=")) {
        return Token::new(Eq, loc, 2);
      }
      if (self.check(">")) {
        return Token::new(Arrrow, loc, 2);
      }
      Token::new(Assign, loc, 1)
    }
    '<' => {
      if (self.check("=")) {
        return Token::new(Le, loc, 2);
      }
      if (self.check("<")) {
        return Token::new(Lsh, loc, 2);
      }
      Token::new(Lt, loc, 1)
    }
    '>' => {
      if (self.check("=")) {
        return Token::new(Ge, loc, 2);
      }
      if (self.check(">")) {
        return Token::new(Rsh, loc, 2);
      }
      Token::new(Gt, loc, 1)
    }
    ':' => {
      if (self.check(":")) {
        return Token::new(ColonColon, loc, 2);
      }
      Token::new(Colon, loc, 1)
    }
    '!' => {
      if (self.check("=")) {
        return Token::new(Ne, loc, 2);
      }
      Token::new(Bang, loc, 1)
    }
    '&' => {
      if (self.check("=")) {
        return Token::new(AndEq, loc, 2);
      }
      if (self.check("&")) {
        return Token::new(Logand, loc, 2);
      }
      Token::new(Bitand, loc, 1)
    }
    '|' => {
      if (self.check("=")) {
        return Token::new(OrEq, loc, 2);
      }
      if (self.check("|")) {
        return Token::new(Logor, loc, 2);
      }
      if (self.check(">")) {
        return Token::new(Pipe, loc, 2);
      }
      Token::new(Bitor, loc, 1)
    }
    '^' => {
      if (self.check("=")) {
        return Token::new(XorEq, loc, 2);
      }
      Token::new(Xor, loc, 1)
    }


    '\'' => {
      let ch = self.ch();
      let mut tok = Token::new(Char(ch), loc, 3);
      if (ch == '\\') {
        tok = match self.ch() {
          'n' => Token::new(Char('\n'), loc, 4)
          't' => Token::new(Char('\t'), loc, 4)
          'r' => Token::new(Char('\r'), loc, 4)
          '0' => Token::new(Char('\u0000'), loc, 4)
          '\\'=> Token::new(Char('\\'), loc, 4)
          '\''=> Token::new(Char('\''), loc, 4)
          '"' => Token::new(Char('"'), loc, 4)
          'b' => Token::new(Char('\b'), loc, 4)
          'u' => {
            let digits = [];
            if (self.ch() == '{') {
              for c = self.ch(); c != '}'; c = self.ch() {
                digits.push(c);
              }
              let unicode = parse_int(digits, 16, loc);
              Token::new(Char(Int::unsafe_to_char(unicode)), loc, 3 + digits.length());
            } else {
              self.retrace();
              for i in 0..<4 {
                let c = self.ch();
                if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
                  @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
                  break;
                }
                digits.push(c);
              }
              let unicode = parse_int(digits, 16, loc);
              Token::new(Char(Int::unsafe_to_char(unicode)), loc, 7);
            }
          }
          'x' => {
            let digits = [];
            for i in 0..<2 {
              let c = self.ch();
              if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
                @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
                break;
              }
              digits.push(c);
            }
            let unicode = parse_int(digits, 16, loc);
            Token::new(Char(Int::unsafe_to_char(unicode)), loc, 7);
          }
          _ => {
            @diag.error(loc, loc.advance(3), "unknown escape sequence");
            Token::new(Char(' '), loc, 4)
          }
        }
      }
      if (self.ch() != '\'') {
        @diag.error(loc, loc.advance(3), "unterminated char literal");
      }
      tok;
    }

    'a'..='z' | '_' => {
      // Expect a byte-char literal: b'c'
      if (c == 'b' && self.check("'")) {
        self.retrace();
        let ch = self.next();
        guard ch.ty is Char(x);
        let w = x.to_int();
        if (w > 255 || w < 0) {
          @diag.error(ch.loc, ch.loc.advance(ch.len), "invalid byte literal with value \{w}");
        }
        return Token::new(Byte(w.to_byte()), loc, ch.len + 1);
      }

      // Expect a byte-string: b"str"
      if (c == 'b' && self.check("\"")) {
        // Use UTF-8, e.g. b"我" == 0xe6 88 91
        self.retrace();
        let str = self.next();

        // Don't worry about f-strings. They aren't handled in lexer.
        guard str.ty is Str(x);
        return Token::new(ByteStr(@encoding.encode(@encoding.UTF8, de_escape(loc, x))), loc, str.len + 1);
      }

      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_' | '0'..='9'); c = self.ch() {
        name.push(c);
      }
      self.retrace();
      let str = String::from_array(name);
      match str {
        "let" => Token::new(Let, loc, 3)
        "fn" => Token::new(Fn, loc, 2)
        "return" => Token::new(Return, loc, 6)
        "if" => Token::new(If, loc, 2)
        "else" => Token::new(Else, loc, 4)
        "struct" => Token::new(Struct, loc, 6)
        "while" => Token::new(While, loc, 5)
        "for" => Token::new(For, loc, 3)
        "mut" => Token::new(Mut, loc, 3)
        "enum" => Token::new(Enum, loc, 4)
        "trait" => Token::new(Trait, loc, 5)
        "impl" => Token::new(Impl, loc, 4)
        "with" => Token::new(With, loc, 4)
        "match" => Token::new(Match, loc, 5)
        "extern" => Token::new(Extern, loc, 6)
        "type" => Token::new(Type, loc, 4)
        "true" => Token::new(True, loc, 4)
        "false" => Token::new(False, loc, 5)
        "break" => Token::new(Break, loc, 5);
        "continue" => Token::new(Continue, loc, 8);
        "try" => Token::new(Try, loc, 3)
        "priv" => Token::new(Priv, loc, 4)
        "in" => Token::new(In, loc, 2)
        "derive" => Token::new(Derive, loc, 6)
        "is" => Token::new(Is, loc, 2)
        "as" => Token::new(As, loc, 2)
        "typealias" => Token::new(Typealias, loc, 9)
        "fnalias" => Token::new(Fnalias, loc, 7)
        "guard" => Token::new(Guard, loc, 5)
        "raise" => Token::new(Raise, loc, 5)
        "test" => Token::new(Test, loc, 4)
        "const" => Token::new(Const, loc, 5)
        "suberror" => Token::new(Suberror, loc, 8)
        "loop" => Token::new(Loop, loc, 4)
        "pub" => {
          if (self.check("(all)")) {
            return Token::new(Puball, loc, 8);
          }
          if (self.check("(open)")) {
            return Token::new(Pubopen, loc, 9);
          }
          Token::new(Pub, loc, 3)
        }
        _ => Token::new(Ident(str), loc, name.length());
      }
    }
    'A'..='Z' | '@' => {
      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_' | '0'..='9'); c = self.ch() {
        name.push(c);
      }
      self.retrace();
      let name = String::from_array(name)
      let kind = match c {
        'A'..='Z' => Typename(name);
        '@' => Packname(name);
        _ => panic()
      }
      Token::new(kind, loc, name.length());
    }
    '#' => {
      if (self.check("|")) {
        let content = []
        for c = self.ch(); not(c is '\n'); c = self.ch() { content.push(c); }
        content.push('\n');
        return Token::new(RawStr(String::from_array(content)), loc, content.length());
      }
      let name = [c];
      // Note that it's different from above: it also accepts '.'
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_' | '.' | '0'..='9'); c = self.ch() {
        name.push(c);
      }
      self.retrace();
      let name = String::from_array(name)
      Token::new(Attribute(name), loc, name.length());
    }
    '\n' => { Token::new(Newline, loc.advance(-1), 0) }
    ' ' | '\r' | '\t' => self.next()
    '0'..='9' => {
      let mut base = 10;
      let digits = [c];
      let next = self.ch();

      if ((c == '0') && (next == 'x' || next == 'X')) {
        base = 16;

        digits.clear(); // Remove '0x'
        for c = self.ch(); c is ('0'..='9' | 'a'..='f' | 'A'..='F' | '_'); c = self.ch() {
          if (c != '_') {
            digits.push(c);
          }
        }
        self.retrace();
        let mut fp = false;
        let next = self.peek(0);
        // Guard for things like 0..=4, which would be parsed as (0.) . = 4
        if (next == '.' && self.peek(1) != '.') {
          fp = true;
          digits.push(self.ch());
          for c = self.ch(); c is ('0'..='9' | 'a'..='f' | 'A'..='F'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }
        // Also check for p(+|-)?\d+
        let next = self.peek(0);
        if (next == 'p' || next == 'P') {
          fp = true;
          digits.push(self.ch());
          // Also allow '+' and '-'.
          if (self.peek(0) is ('+' | '-')) {
            digits.push(self.ch());
          }
          for c = self.ch(); c is ('0'..='9' | 'a'..='f' | 'A'..='F'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }

        // Suffix F for float
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }

        if (fp) {
          let vf = parse_double(digits, loc);
          return Token::new(Double(vf, String::from_array(digits)), loc, digits.length());
        }
        // fallthrough to suffix parsing
      } else if (c == '0' && next == 'o') {
        base = 8;

        digits.clear(); // Remove '0o'
        for c = self.ch(); c is ('0'..='7' | '_'); c = self.ch() {
          if (c != '_') {
            digits.push(c);
          }
        }
        self.retrace();
        // No floating point possible.
        // fallthrough to suffix parsing
      } else if (c == '0' && next == 'b') {
        base = 2;

        digits.clear(); // Remove '0b'
        for c = self.ch(); c is ('0'..='7' | '_'); c = self.ch() {
          if (c != '_') {
            digits.push(c);
          }
        }
        self.retrace();
        // No floating point possible.
      } else {
        let mut fp = next is ('.' | 'e' | 'E');

        if (not(fp) && next is ('0'..='9')) {
          digits.push(next);
          for c = self.ch(); c is ('0'..='9' | '_'); c = self.ch() {
            if (c != '_') {
              digits.push(c);
            }
          }
        }

        self.retrace();
        let next = self.peek(0);
        // A floating point.
        // Similarly guard against ranges as 0..=4.
        if (next == '.' && self.peek(1) != '.') {
          fp = true;
          digits.push(self.ch());
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }

        let next = self.peek(0);
        if (next == 'e' || next == 'E') {
          fp = true;
          digits.push(self.ch());
          // Also allow '+' and '-'.
          if (self.peek(0) is ('+' | '-')) {
            digits.push(self.ch());
          }
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }

        // Suffix F for float
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }

        if (fp) {
          let vf = parse_double(digits, loc);
          return Token::new(Double(vf, String::from_array(digits)), loc, digits.length());
        }
      }

      // Suffix N for bigint
      if (self.peek(0) == 'n' || self.peek(0) == 'N') {
        self.ch() |> ignore;
        let vi = BigInt::from_string(String::from_array(digits));
        return Token::new(Int(vi, { signed: true, len: -1 }), loc, digits.length());
      }

      // Suffix U for unsigned
      let mut signed = false;
      if (self.peek(0) == 'u' || self.peek(0) == 'U') {
        self.ch() |> ignore;
        signed = true;
      }
      
      // Suffix L for int64
      let mut len = 32;
      if (self.peek(0) == 'l' || self.peek(0) == 'L') {
        self.ch() |> ignore;
        len = 64;
      }

      return Token::new(Int(parse_bigint(digits, base), { signed, len }), loc, digits.length());
    }
    '.' => {
      if (self.check(".=")) {
        return Token::new(IncRange, loc, 3);
      }
      if (self.check(".<")) {
        return Token::new(ExcRange, loc, 3);
      }
      if (self.check(".")) {
        return Token::new(Expand, loc, 2);
      }
      
      let digits = [c];
      let next = self.peek(0);
      if (next is '0'..='9') {
        for c = self.ch(); c is ('0'..='9'); c = self.ch() {
          digits.push(c);
        }
        self.retrace();
        
        // Check exponent.
        let next = self.peek(0);
        if (next == 'e' || next == 'E') {
          digits.push(self.ch());
          // Also allow '+' and '-'.
          if (self.peek(0) is ('+' | '-')) {
            digits.push(self.ch());
          }
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
          println("after e: \{digits}");
          self.retrace();
        }

        // Check suffix
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }
        let vf = parse_double(digits, loc);
        return Token::new(Double(vf, String::from_array(digits)), loc, digits.length());
      } else {
        return Token::new(Dot, loc, 1);
      }
    }
    '"' => {
      let str = self.read_str();
      return Token::new(Str(str), loc, str.length() + 2);
    }
    _ => {
      @diag.error(loc, loc.advance(1), "unrecognized character: \{c}");
      self.next()
    }
  }
}

pub fn Lexer::has_next(self: Lexer) -> Bool {
  return self.loc < self.data.length() - 1 && self.peek(1) != '\u0000';
}
