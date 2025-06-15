fn main {
  let lexer = @parse.Lexer::new("<stdin>",
#|fn main {
#|  let x = 2;
#|}
  );
  let tokens = lexer.lex();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  let parser = @parse.Parser::new(tokens);
  let ast = parser.parse();
  let good = @diag.report();
  if (not(good)) {
    return;
  }

  println(ast);
}
