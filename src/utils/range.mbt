pub(all) struct Range {
  start: Int;
  stop: Int;
  step: Int;
}

pub fn Range::iter(self: Range) -> Iter[Int] {
  self.start.until(self.stop, step=self.step)
}

pub fn range(stop: Int) -> Range {
  { start: 0, stop: stop, step: 1 };
}
