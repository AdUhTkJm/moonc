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
  for i in @utils.range(len) {
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

pub fn Lexer::next(self: Lexer) -> Token {
  let loc = @diag.Loc::new(self.filename, self.loc);
  let c = self.ch();
  match c {
    '+' => Token::new(Plus, loc, 1) 
    '-' => Token::new(Minus, loc, 1)
    '*' => Token::new(Star, loc, 1)
    '{' => Token::new(LBrace, loc, 1)
    '}' => Token::new(RBrace, loc, 1) 
    '(' => Token::new(LPar, loc, 1)
    ')' => Token::new(RPar, loc, 1)
    ',' => Token::new(Comma, loc, 1)
    ';' => Token::new(Semicolon, loc, 1)
    ':' => Token::new(Colon, loc, 1)
    '/' => {
      if (self.check("/")) {
        for c = self.ch(); not(c is '\n'); c = self.ch() { }
        self.retrace();
        return self.next();
      }
      Token::new(Slash, loc, 1)
    }
    '=' => {
      if (self.check("=")) {
        self.advance(1);
        return Token::new(Eq, loc, 2);
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
      let digits = [c];
      if (self.peek(1) == 'x') {
        digits.push(self.ch());
      }
      for c = self.ch(); c is '0'..='9'; c = self.ch() {
        digits.push(c);
      }
      // We're one step away.
      self.retrace();
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
  return self.loc < self.data.length() - 1 && self.peek(1) != '\u0000';
}
