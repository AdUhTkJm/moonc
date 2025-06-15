fn main {
  let lexer = @parse.Lexer::new("<stdin>",
#|fn fib(x: Int) {
#|  if (x < 1) {
#|    return 1
#|  }
#|  fib(x - 1) + fib(x - 2)
#|}
#|
#|fn main {
#|  let x = 2 + 4 * (6 - 5);
#|  let _ = fib(x);
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
