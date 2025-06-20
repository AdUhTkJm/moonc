///|
/// A list of all warnings that the compiler might output.
pub(all) enum Warning {
  WPubTest
  WUnknownAttribute(String)
}

impl Show for Warning with to_string(self) -> String {
  match self {
    WPubTest => "access modifiers have no effect on 'test' block"
    WUnknownAttribute(x) => "unknown attribute \{x}"
  }
}

impl Show for Warning with output(self, writer) -> Unit {
  writer.write_string(self.to_string())
}
