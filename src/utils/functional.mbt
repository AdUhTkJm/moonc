pub fn[T] any(arr: Array[T], f: (T) -> Bool) -> Bool {
  for x in arr {
    if (f(x)) {
      return true;
    }
  }
  return false;
}

pub fn[T] ite(x: Bool, a: T, b: T) -> T {
  if (x) { a } else { b }
}
