enum X {
  A
  B
  C
  D(Int)
}

fn main {
  let _ = A;
  let _ = D(3);
  let _ = X::B;
  let _ = X::D(1 - 2);
}