fn read(file: String) -> String {
  match (try? @fs.read_file_to_string(file)) {
    Err(_) => {
      println("error: cannot open file \{file}\n");
      ""
    }
    Ok(content) => content
  }
}

fn parse(file: String, content: String) -> Unit {
  let lexer = @parse.Lexer::new(file, content);
  let tokens = lexer.lex();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  let parser = @parse.Parser::new(None, file, tokens);
  let ast = parser.parse();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  let _ = @sema.Env::new(ast);
  println(ast);
}

fn main {
  let files = [];
  // let args = @env.args()[1:].to_array();
  let args = ["/home/aduhtkjm/moonbit/moonc/corelib/int64_js.mbt"];
  @ArgParser.parse([
    // Specs go here
  ], fn (x) { files.push(x) }, "", args);
  
  if (files.length() == 0) {
    println("error: no input file");
    return;
  }

  for f in files {
    parse(f, read(f));
  }
}
