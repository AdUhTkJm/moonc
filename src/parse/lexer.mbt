pub struct Lexer {
  mut line: Int
  mut loc: Int
  data: Array[Char]
  filename: String
}

pub fn Lexer::new(filename: String, code: String) -> Lexer {
  @diag.add_file(filename, code);
  return {
    line: 0,
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
  let len = str.char_length();
  let arr = str.to_array();
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

pub fn parse_hex(digits: Array[Char], from: @diag.Loc) -> Int {
  let str = String::from_array(digits);
  match (try? @strconv.parse_int(str, base=16)) {
    Ok(x) => x
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid hex-literal: \{str}");
      0
    }
  }
}

pub fn parse_oct(digits: Array[Char], from: @diag.Loc) -> Int {
  let str = String::from_array(digits);
  match (try? @strconv.parse_int(str, base=8)) {
    Ok(x) => x
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid oct-literal: \{str}");
      0
    }
  }
}

pub fn parse_dec(digits: Array[Char], from: @diag.Loc) -> Int {
  let str = String::from_array(digits);
  match (try? @strconv.parse_int(str, base=10)) {
    Ok(x) => x
    Err(_) => {
      @diag.error(from, from.advance(digits.length()), "invalid int literal: \{str}");
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
      '\\' => {
        let next = self.ch();
        match next {
          'n'  => result.push('\n')
          't'  => result.push('\t')
          'r'  => result.push('\r')
          '\\' => result.push('\\')
          '"'  => result.push('"')
          '\'' => result.push('\'')
          '0'  => result.push('\u0000')
          'u'  => {
            let digits = [];
            for i in 0..<4 {
              let c = self.ch();
              if (not(c is ('0'..='9' | 'a'..='f' | 'A'..='F'))) {
                @diag.error(loc, loc.advance(i), "unexpected unicode escape sequence");
                break;
              }
              digits.push(c);
            }
            let unicode = parse_hex(digits, loc);
            result.push(Int::unsafe_to_char(unicode));
          }
          _ => {
            @diag.error(loc, loc.advance(1), ("unknown escape sequence"));
          }
        }
      }
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
      Token::new(Lt, loc, 1)
    }
    '>' => {
      if (self.check("=")) {
        return Token::new(Ge, loc, 2);
      }
      Token::new(Gt, loc, 1)
    }
    ':' => {
      if (self.check(":")) {
        return Token::new(ColonColon, loc, 2);
      }
      Token::new(Colon, loc, 1)
    }

    'a'..='z' | '_' => {
      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_'); c = self.ch() {
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
    'A'..='Z' => {
      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_'); c = self.ch() {
        name.push(c);
      }
      self.retrace();
      Token::new(Typename(String::from_array(name)), loc, name.length());
    }
    '\n' => { self.line += 1; Token::new(Newline, loc.advance(-1), 0) }
    ' ' | '\r' | '\t' => self.next()
    '0'..='9' => {
      let octal = (c == '0');
      let digits = [c];
      let next = self.ch();

      if (next == 'x' || next == 'X') {
        digits.push(next);
        for c = self.ch(); c is ('0'..='9' | 'a'..='f' | 'A'..='F'); c = self.ch() {
          digits.push(c);
        }
        self.retrace();
        let mut fp = false;
        let next = self.peek(0);
        if (next == '.') {
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
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }
        if (fp) {
          let vf = parse_double(digits, loc);
          return Token::new(Double(vf), loc, digits.length());
        }
        let vi = parse_hex(digits, loc);
        return Token::new(Int(vi), loc, digits.length());
      } else if (next is ('0'..='9' | '.' | 'e' | 'E')) {
        if (not(next is ('.' | 'e' | 'E'))) {
          digits.push(next);
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
        }

        self.retrace();
        let next = self.peek(0);
        let mut fp = false;
        // A floating point.
        if (next == '.') {
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
          // Also allow '+' and '-'.
          if (self.peek(0) is ('+' | '-')) {
            digits.push(self.ch());
          }
          for c = self.ch(); c is ('0'..='9'); c = self.ch() {
            digits.push(c);
          }
          self.retrace();
        }
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }
        if (fp) {
          let vf = parse_double(digits, loc);
          return Token::new(Double(vf), loc, digits.length());
        }
        let vi = @utils.ite(octal, parse_oct, parse_dec)(digits, loc);
        return Token::new(Int(vi), loc, digits.length());
      } else {
        // A single character.
        self.retrace();
        return Token::new(Int(parse_dec([c], loc)), loc, 1);
      }
    }
    '.' => {
      let digits = [c];
      let next = self.peek(0);
      if (next is '0'..='9') {
        digits.push(next);
        for c = self.ch(); c is ('0'..='9'); c = self.ch() {
          digits.push(c);
        }
        self.retrace();
        // Check suffix
        if (self.peek(0) == 'f' || self.peek(0) == 'F') {
          self.ch() |> ignore;
          let vf = parse_float(digits, loc);
          return Token::new(Float(vf), loc, digits.length());
        }
        let vf = parse_double(digits, loc);
        return Token::new(Double(vf), loc, digits.length());
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
