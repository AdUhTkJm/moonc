pub fn make() -> (Int) -> Int {
  let mut count = 0;
  fn (x) {
    count += x;
    count;
  }
}
