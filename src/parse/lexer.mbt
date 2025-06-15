pub struct Lexer {
  mut line: Int
  mut loc: Int
  data: String
  filename: String
}

pub fn Lexer::new(filename: String, code: String) -> Lexer {
  @diag.add_file(filename, code);
  return {
    line: 0,
    loc: 0,
    data: code + "\n\u0000",
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
  if (self.loc >= self.data.char_length()) {
    return '\u0000';
  }
  let ch = String::char_at(self.data, self.loc);
  self.loc += 1;
  return ch;
}

fn Lexer::peek(self: Lexer, i: Int) -> Char {
  if (self.loc + i >= self.data.char_length()) {
    return '\u0000';
  }
  return String::char_at(self.data, self.loc + i);
}

pub fn Lexer::next(self: Lexer) -> Token {
  let loc = @diag.Loc::new(self.filename, self.loc);
  let c = self.ch();
  match c {
    '+' => Token::new(Plus, loc, 1) 
    '-' => Token::new(Minus, loc, 1)
    '*' => Token::new(Star, loc, 1)
    '/' => Token::new(Slash, loc, 1)
    '{' => Token::new(LBrace, loc, 1)
    '}' => Token::new(RBrace, loc, 1) 
    '(' => Token::new(LPar, loc, 1)
    ')' => Token::new(RPar, loc, 1)
    ',' => Token::new(Comma, loc, 1)
    ';' => Token::new(Semicolon, loc, 1)
    ':' => Token::new(Colon, loc, 1)
    '=' => Token::new(Eq, loc, 1)
    'a'..='z' | '_' => {
      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_'); c = self.ch() {
        name.push(c);
      }
      let str = String::from_array(name);
      match str {
        "let" => Token::new(Let, loc, 3)
        "fn" => Token::new(Fn, loc, 2)
        _ => Token::new(Ident(str), loc, name.length());
      }
    }
    'A'..='Z' => {
      let name = [c];
      for c = self.ch(); c is ('a'..='z' | 'A' ..= 'Z' | '_'); c = self.ch() {
        name.push(c);
      }
      Token::new(Typename(String::from_array(name)), loc, name.length());
    }
    '\n' => { self.line += 1; self.next() }
    ' ' | '\r' | '\t' => self.next()
    '0'..='9' => {
      let digits = [c];
      if (self.peek(1) == 'x') {
        digits.push(self.ch());
      }
      for c = self.ch(); c is ('0'..='9' | 'x'); c = self.ch() {
        digits.push(c);
      }
      let str = String::from_array(digits);
      match (try? @strconv.parse_int(str)) {
        Ok(x) => Token::new(Int(x), loc, digits.length());
        Err(_) => {
          @diag.error(loc, loc.advance(digits.length()), "invalid int literal: \{str}");
          Token::new(Int(0), loc, digits.length());
        };
      }
    }
    _ => {
      @diag.error(loc, loc.advance(1), "unrecognized character: \{c}");
      self.next()
    }
  }
}

pub fn Lexer::has_next(self: Lexer) -> Bool {
  return self.loc < self.data.length() - 1 && self.data.char_at(self.loc + 1) != '\u0000';
}
