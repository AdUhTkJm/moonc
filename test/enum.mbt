enum X {
  A
  B
  C
  D(Int)
}

fn print(x: X) -> Unit {
  println(match x {
    A => 1
    B => 2
    C => 3
    D(x) => x
  });
}

fn main {
  print(A);
  print(X::B);
  print(C);
  print(X::D(-2));
}