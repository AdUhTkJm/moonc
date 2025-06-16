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

priv struct Env {
  mut counter: Int
}

fn Env::new() -> Env {
  {
    counter: 0
  }
}

let env: Env = Env::new();

pub fn count() -> Int {
  env.counter += 1;
  return env.counter;
}

pub fn count_reset() -> Unit {
  env.counter = 0;
}
