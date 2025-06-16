fn main {
  let argv = ["src/parse/ast.mbt"];
  let files = [];
  @ArgParser.parse([
    // Specs go here
  ], fn (x) { files.push(x) }, "", argv);

  // Currently only support a single file.
  if (files.length() != 1) {
    println("error: multiple files are not yet supported");
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

  println(ast);
}
