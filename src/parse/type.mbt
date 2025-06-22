pub(all) enum Type {
  Named(Name, Array[Type])
  Struct(Name, Array[Type])
  Enum(Name, Array[Type])
  Abstract(Name, Array[Type])
  FixedArray(Type)
  Function(Array[Type], Type)
  Tuple(Array[Type])
  Typevar(Typevar)
  Int
  Float
  Unit
  Double
  String
  Bool
  Char
  Option(Type)
  Unknown
  Long
  Weak(Ref[Type])
  MayError(Type)
  HasError(Type, Type)
  VirtualBase(Type)
  Error
}

pub impl Show for Type with to_string(self) -> String {
  match (self) {
    Int => "Int"
    Double => "Double"
    Float => "Float"
    Unit => "Unit"
    Bool => "Bool"
    Char => "Char"
    String => "String"
    Error => "Error"
    Long => "Long"
    Named(x, []) | Struct(x, []) | Enum(x, []) | Abstract(x, []) => x.to_string()
    Named(x, arr) | Struct(x, arr) | Enum(x, arr) | Abstract(x, arr) => {
      let s = arr.map(Type::to_string).join(", ")
      "\{x}[\{s}]"
    }
    FixedArray(x) => "FixedArray[\{x}]"
    Weak(x) => "'weak(\{x.val})"
    Unknown => "?"
    Tuple(arr) => {
      let s = arr.map(Type::to_string).join(", ")
      "(\{s})"
    }
    Option(x) => "\{x}?"
    Function(args, ret) => {
      let s = args.map(Type::to_string).join(", ")
      "((\{s}) -> \{ret})"
    }
    Typevar(v) => "\{v}"
    HasError(x, y) => "(\{x} raise \{y})"
    MayError(x) => "(\{x} raise?)"
    VirtualBase(x) => "(&\{x})"
  }
}

pub impl Show for Type with output(self, writer) -> Unit {
  writer.write_string(self.to_string());
}

pub fn Type::verbose(self: Type) -> String {
  match self {
    Struct(_) => "struct \{self.to_string()}"
    Enum(_) => "enum \{self.to_string()}"
    Abstract(_) => "abstract type \{self.to_string()}"
    Named(_) => "unresolved user-defined type \{self.to_string()}"
    Unknown => "unknown type"
    _ => self.to_string()
  }
}

pub fn Type::map(self: Type, f: (Type) -> Type) -> Type {
  let mapper = (x: Type) => { x.map(f) }
  f(match self {
    Option(x) => Option(x.map(f))
    Tuple(arr) => Tuple(arr.map(mapper))
    Function(args, ret) => Function(args.map(mapper), ret.map(f))
    FixedArray(x) => FixedArray(x.map(f))
    Enum(name, arr) => Enum(name, arr.map(mapper))
    Struct(name, arr) => Struct(name, arr.map(mapper))
    Named(name, arr) => Named(name, arr.map(mapper))
    Abstract(name, arr) => Abstract(name, arr.map(mapper))
    Weak(x) => Weak({ val: x.val.map(f) })
    HasError(x, y) => HasError(x.map(f), y.map(f))
    MayError(x) => MayError(x.map(f))
    VirtualBase(x) => VirtualBase(x.map(f))
    Unknown | Int | Double | Float |
    Char | Bool | Typevar(_) | Unit |
    String | Error | Long => self
  })
}

///|
/// Removes all `weak` types, replacing them with their underlying type.
/// 
pub fn Type::deweak(self: Type) -> Type {
  self.map((x) => match x {
    Weak(x) => x.val;
    c => c
  });
}

///|
/// Weaken all `Unknown` types to `Weak(Unknown)` for type inference.
/// 
pub fn Type::weaken(self: Type) -> Type {
  self.map((x) => match x {
    Unknown => Type::weak()
    c => c
  })
}

///|
/// Constructs a weak type.
/// 
pub fn Type::weak() -> Type {
  Weak(Ref::new(Unknown))
}

///|
/// Gets the full name (package, namespace and name) of this type.
/// 
pub fn Type::name(self: Type) -> Option[Name] {
  fn builtin(x) {
    Some(Name::unqualified(Some("builtin"), x))
  }
  match self {
    Weak(a) => a.val.name()
    Long => builtin("Long")
    Char => builtin("Char")
    String => builtin("String")
    Double => builtin("Double")
    Unit => builtin("Unit")
    Float => builtin("Float")
    Int => builtin("Int")
    Bool => builtin("Bool")
    Unknown => None
    Option(_) => builtin("Option")
    Typevar(_) => None
    Tuple(_) => None
    Function(_) => None
    FixedArray(_) => builtin("FixedArray")
    Enum(x, _) => Some(x)
    Struct(x, _) => Some(x)
    Named(x, _) => Some(x)
    Abstract(x, _) => Some(x)
    Error => builtin("Error")
    HasError(x, _) => x.name()
    MayError(x) => x.name()
    VirtualBase(x) => x.name()
  }
}

pub fn Type::resolve_self(self: Type, ns: String?) -> Type {
  if (ns is None) {
    return self;
  }
  guard ns is Some(ns);
  self.map((ty) => match ty {
    Named({ name: "Self", pack, ns: None }, args) =>
      Named({ name: ns, pack, ns: None }, args)
    c => c
  });
}
