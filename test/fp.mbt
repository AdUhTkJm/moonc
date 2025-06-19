fn main {
  let _ = 000.2;
  let _ = 1.;
  let _ = .1;
  let _ = 1e+8;
  let _ = 1e-9;
  let _ = 1e3;
  let _ = 1.e+8;
  let _ = .1e-8;
  let _ = .2e2;
  let _ = 2.e2;
  let _ = 2.2e2;
  let _ = 0x1;
  let _ = 07;
  let _ = 0xaa;
  // // These things here can only be parsed after @strconv.parse_double is enhanced.
  // let _ = 0x00000.22p+6;
  // let _ = 0x1.3eb8p+8;
  // let _ = 0x1.p1;
  // let _ = 0x1.p-2;
}