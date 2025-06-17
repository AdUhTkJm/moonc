///| A rebinding of the builtin Map.
/// 
/// This is needed because the method `op_get` of `@builtin.Map` has been deprecated,
/// and I hope to avoid breaking changes.
/// 
/// When the change to builtin Map is made, this file will be made redundant.
pub type Map[K,V](@builtin.Map[K,V]);

pub fn[K: Eq + Hash, V] Map::new() -> Map[K, V] {
  return {};
}

pub fn[K: Eq + Hash, V] Map::from_array(x: Array[(K, V)]) -> Map[K, V] {
  return @builtin.Map::from_array(x);
}

pub fn[K: Eq + Hash, V] Map::op_set(self: Map[K, V], x: K, y: V) -> Unit {
  self._.op_set(x, y);
}

pub fn[K: Eq + Hash, V] Map::op_get(self: Map[K, V], x: K) -> V {
  self._.get(x).unwrap();
}

pub fn[K: Eq + Hash, V] Map::get(self: Map[K, V], x: K) -> V? {
  self._.get(x);
}

pub fn[K: Eq + Hash, V] Map::remove(self: Map[K, V], x: K) -> Unit {
  self._.remove(x);
}

pub fn[K: Eq + Hash, V] Map::size(self: Map[K, V]) -> Int {
  self._.size();
}

pub fn[K: Eq + Hash, V] Map::to_array(self: Map[K, V]) -> Array[(K, V)] {
  self._.to_array();
}

pub fn[K: Eq + Hash, V] Map::iter(self: Map[K, V]) -> Iter[(K, V)] {
  self._.iter();
}
