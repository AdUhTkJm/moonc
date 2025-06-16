priv struct Diag {
  from: Loc
  to: Loc
  msg: String
}

priv struct PosResult {
  line: Int
  col: Int
}

priv struct FileInfo {
  lines: Array[@string.View];
  accum: Array[Int]
}

priv struct DiagEnv {
  // Maps filenames to the code in it.
  content: Map[String, FileInfo]
  errors: Array[Diag]
};

let env: DiagEnv = { content: Map::new(), errors: [] };

pub fn error(from: Loc, to: Loc, msg: String) -> Unit {
  env.errors.push({ from: from, to: to, msg: msg });
}

pub fn add_file(filename: String, code: String) -> Unit {
  let lines = code.split("\n");
  let len = lines.map(fn (x) { x.length() });
  let mut count = -1;
  let accum = fn(x) {
    let w = count;
    // Account for the '\n' removed above.
    count += x + 1;
    return w;
  };
  let total = len.map(accum);
  env.content[filename] = {
    lines: lines.collect(),
    accum: total.collect()
  };
}

pub fn report() -> Bool {
  if (env.errors.is_empty()) {
    return true;
  }
  
  for diag in env.errors {
    println("\{diag.from}: error: \{diag.msg}")
    if (diag.from.unknown || diag.to.unknown) {
      continue;
    }
    
    let file = env.content.get(diag.from.filename).unwrap();
    let frominfo = file.find(diag.from.charpos);
    let toinfo = file.find(diag.to.charpos);
    if (frominfo.line > toinfo.line) {
      println("  <EOF>");
      println("  ^^^^^");
    }

    let line = file.lines[frominfo.line - 1];
    let col = frominfo.col;
    let space = String::make(col - 1, ' ');
    let sign = if (frominfo.line != toinfo.line) {
      // Only show the line on `from`.
      line.length() + 1 - col;
    } else {
      @math.maximum(toinfo.col - col, 1);
    }
    println("  \{line}");
    println("  \{space}\{String::make(sign, '^')}");
  }
  return false;
}

pub fn errcnt() -> Int {
  return env.errors.length();
}

fn FileInfo::find(self: FileInfo, charpos: Int) -> PosResult {
  let result = self.accum.binary_search(charpos);
  let x = match result {
    Err(x) => x
    Ok(x) => x
  };
  if (x - 1 >= self.accum.length()) {
    // Probably an EOF or similar.
    return { line: self.accum.length(), col: 1 };
  }
  return { line: x, col: charpos - self.accum[x - 1] };
}
