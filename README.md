# AdUhTkJm/moonc

This is aimed to be a Moonbit compiler written in Moonbit. As Moonbit syntax is highly unstable, and I'm only developing this on my own, the project might fall behind. I would welcome for your valuable contribution to maintain this bootstrapping compiler.

This can also be a usable package to manipulate Moonbit code, which is published on [mooncakes](mooncakes.io).

For current implementation progress, see [Progress](#Progress) section.

# Introduction

## Parsing

The lexer and parser are handwritten and are recursive-descent. Some errors are not detected by parser and are delayed to the semantics analysis stage (which hasn't begun yet).

The range of supported syntax are quite limited currently.

To use the lexer, simply write

```mbt
let lexer = @parse.Lexer::new(filename, code_in_the_file);
let tokens = lexer.lex();
let good = @diag.report();
if (not(good)) {
  return;
}
```

All errors in lexing will be reported to the `@diag` package. Calling `report` will print all errors, and return `false` if there are any errors, and `true` otherwise.

The `lex` method returns a list of tokens. Each token carries a token type (for example, LPar for `(`, RBrace for `}`, and Int(3) for `3`), a location in the source file (which is why the file name is needed), and its length (for `@diag` to pretty-print).

Similarly, for parser:

```mbt
let parser = @parse.Parser::new(filename, tokens);
let ast = parser.parse();
let good = @diag.report();
if (not(good)) {
  return;
}
```

The `parse()` method returns an AST. In the `@parse` package, simple tools are used to manipulate it, for example the `map` function that traverses through the whole tree. When you call `to_string()` on it, the AST will show in Moonbit code form, so that you can easily convert code to AST and convert it back.

As an example, given the following code (see the `test` folder):

```mbt
fn fib(x: Int) -> Int {
  if (x < 1) {
    return 1
  }
  fib(x - 1) + fib(x - 2)
}

fn main {
  let x = 2 + 4 * (6 - 5);
  let _ = fib(x);
}
```

After feeding it to lexer and then parser, and printing the AST, what you get back is

```mbt
{
  fn fib(x) {
    if (x < 1) {
      return 1;
    };
    (fib((x - 1)) + fib((x - 2)));
  };
  fn main {
    let x = (2 + (4 * (6 - 5)));
    let _ = fib(x);
  };
}
```

The outer braces are due to a `Block` node that encloses the whole file, which might need special treatment.

## Type checking

Type checking support is currently very limited. Though it now has the capability of parsing and loading `.mbti` files, not all AST types are supported for typing.

It can give types to basic language constructs, including literals, loops, arrays and enums. It also supports some pattern matching features. Some advanced structures are not yet covered.

# Progress

Currently the compiler is able to parse itself in entirety, and it can also parse most files in `core/builtin`.
