pub fn[T] any(arr: Array[T], f: (T) -> Bool) -> Bool {
  for x in arr {
    if (f(x)) {
      return true;
    }
  }
  return false;
}
