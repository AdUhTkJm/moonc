fn fib(x: Int) -> Int {
  if (x < 1) {
    return 1
  }
  fib(x - 1) + fib(x - 2)
}

fn main {
  let x = 2 + 4 * (6 - 5);
  let _ = x |> fib;
}
