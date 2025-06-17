fn main {
  let files = [];
  let args = ["test/fib.mbt"];// @env.args()[1:].to_array();
  @ArgParser.parse([
    // Specs go here
  ], fn (x) { files.push(x) }, "", args);

  // Currently only support a single file.
  if (files.length() > 1) {
    println("error: multiple files are not yet supported");
    return;
  } else if (files.length() == 0) {
    println("error: no input file");
    return;
  }

  let file = files[0];
  let content = match (try? @fs.read_file_to_string(file)) {
    Err(_) => {
      println("error: cannot open file \{file}\n");
      return;
    }
    Ok(content) => content
  }

  let lexer = @parse.Lexer::new(file, content);
  let tokens = lexer.lex();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  let parser = @parse.Parser::new(None, "<stdin>", tokens);
  let ast = parser.parse();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  let env = @sema.Env::new(ast);
  let checked = env.check();
  let _ = @diag.report();

  println(checked);
}
