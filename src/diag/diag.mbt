pub struct Diag {
  from: Loc
  to: Loc
  msg: String
}

pub struct PosResult {
  line: Int
  col: Int
}

pub struct FileInfo {
  lines: Array[@string.View];
  accum: Array[Int]
}

pub struct DiagEnv {
  // Maps filenames to the code in it.
  content: Map[String, FileInfo]
  errors: Array[Diag]
};

let env: DiagEnv = { content: Map::new(), errors: [] };

///|
/// Records a diagnostic error for later reporting.
///
/// Parameters:
///
/// * `from` : The starting location of the error in the source code.
/// * `to` : The ending location of the error in the source code.
/// * `msg` : The error message describing what went wrong.
///
/// Example:
///
/// ```moonbit
/// test "error" {
///   let from = Loc::{ filename: "test.mbt", charpos: 0 }
///   let to = Loc::{ filename: "test.mbt", charpos: 5 }
///   @diag.error(from, to, "syntax error")
///   inspect(@diag.errcnt(), content="1")
/// }
/// ```
///
pub fn error(from: Loc, to: Loc, msg: String) -> Unit {
  env.errors.push({ from: from, to: to, msg: msg });
}

///|
/// Registers a source file with the diagnostic system for error reporting.
///
/// Preprocesses the source code to enable efficient character position to
/// line/column conversion. Splits the code into lines and builds cumulative
/// character offset arrays to support fast location lookups during error
/// reporting.
///
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

///|
/// Reports all recorded diagnostic errors to the console and returns whether
/// compilation succeeded.
///
/// Outputs each error with its location and message, followed by visual
/// indicators showing the error position in the source code. For errors with
/// known locations, displays the relevant source line with caret symbols (^)
/// pointing to the error location.
///
/// Returns `true` if no errors were recorded, `false` otherwise.
///
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

///| Reports the total amount of errors.
pub fn errcnt() -> Int {
  return env.errors.length();
}


///|
/// Converts a character position to line and column numbers within a file.
///
pub fn FileInfo::find(self: FileInfo, charpos: Int) -> PosResult {
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
