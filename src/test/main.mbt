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

  let parser = @parse.Parser::new(file, tokens);
  let ast = parser.parse();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  println(ast);
  // typing(ast);
}

pub fn typing(ast: @parse.AST) -> Unit {
  let file = "corelib/builtin.mbti";
  let lexer = @parse.Lexer::new(file, read(file));
  let tokens = lexer.lex();
  let good = @diag.report();
  if (not(good)) {
    return;
  }
  
  let pack = @parse.Parser::load_mbti(file, tokens);

  let env = @sema.Env::new(ast);
  env.load(pack);
  let ast = env.check();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  println(ast);
}

fn main {
  let files = [];
  let args = @env.args()[1:].to_array();
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
