pub(all) struct Loc {
  filename: String
  charpos: Int
}

pub impl Show for Loc with to_string(self: Loc) -> String {
  let lines = env.content.get(self.filename).unwrap();
  let info = lines.find(self.charpos);
  return "\{self.filename}:\{info.line}:\{info.col}"
}

pub impl Show for Loc with output(self: Loc, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub fn Loc::new(filename: String, charpos: Int) -> Loc {
  return {
    filename: filename,
    charpos: charpos
  }
}

pub fn Loc::advance(self: Loc, x: Int) -> Loc {
  return {
    filename: self.filename,
    charpos: self.charpos + x
  }
}
