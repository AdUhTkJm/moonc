pub fn Env::lookup_type(self: Env, name: Name, tyvars: Array[Type]) -> Type {
  if (self._structs.contains(name)) {
    Struct(name, tyvars)
  } else if (self._enums.contains(name)) {
    Enum(name, tyvars)
  } else {
    Unknown
  }
}

pub fn Env::new_local(self: Env, x: AST) -> Type {
  guard x.kind is VarDecl(detail);
  if (x.ty is Weak(v)) {
    let ty = self.infer(detail.init);
    x.ty = ty; v.val = ty;
    self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty }
    return ty;
  }
  if (x.ty is Named(n, tyvars)) {
    let ty = self.lookup_type(n, tyvars);
    if (ty is Unknown) {
      @diag.error(x.from, x.to, "unknown type \{n}")
    }
    self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty }
    return ty;
  }
  self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty: x.ty }
  x.ty;
}

pub fn Env::add_local(self: Env, name: String, ty: Type) -> Unit {
  self._locals[name] = { name, mutable: false, ty };
}

pub fn Env::get_local(self: Env, x: String) -> Type {
  self._locals[x].ty
}

pub fn Env::get_local_opt(self: Env, x: String) -> Type? {
  self._locals.get(x).map(fn (x) { x.ty })
}

pub fn unify(x: Type, y: Type, from: Loc, to: Loc) -> Type {
  match (x, y) {
    (Weak(x), Weak(y)) => {
      if (not(x.val is Unknown) && not(y.val is Unknown)) {
        @diag.error(from, to, "type \{x} is not \{y}");
        Unknown
      } else if (not(x.val is Unknown)) {
        x.val = x.val.deweak();
        y.val = x.val;
        x.val
      } else {
        y.val = y.val.deweak();
        x.val = y.val;
        y.val
      }
    }
    (Weak(x), y) | (y, Weak(x)) => {
      x.val = y.deweak();
      x.val
    }
    (Int, Int) => Int
    (Float, Float) => Float
    (Bool, Bool) => Bool
    (Unit, Unit) => Unit
    (Tuple(x), Tuple(y)) => {
      if (x.length() != y.length()) {
        @diag.error(from, to, "tuples don't have the same size");
      } else {
        x.eachi(fn (i, z) { unify(z, y[i], from, to) |> ignore });
      }
      Tuple(x)
    }
    (FixedArray(x), FixedArray(y)) => unify(x, y, from, to);
    _ => {
      @diag.error(from, to, "cannot unify type \{x} with \{y}");
      Unknown
    }
  }
}

pub fn Env::infer(self: Env, x: AST) -> Type {
  let ty: Type = match x.kind {
    Unit | Leaf => Unit
    Int(_) => Int
    Bool(_) => Bool
    Char(_) => Char
    Float(_) => Float
    Double(_) => Double
    Str(_) => String
    Guard(cond, other) => {
      unify(self.infer(cond), Bool, cond.from, cond.to) |> ignore;
      if (other is Some(other)) {
        unify(self.infer(other), Unit, other.from, other.to) |> ignore;
      }
      Unit
    }
    Binary(kind, l, r) => {
      unify(self.infer(l), self.infer(r), x.from, x.to) |> ignore;
      match kind {
        And | Or | Lt | Le | Eq | Ne => Bool
        Assign => Unit
        _ => l.ty
      }
    }
    VarDecl(detail) => {
      x.ty = unify(x.ty, self.infer(detail.init), x.from, x.to);
      self.new_local(x);
    }
    VarRef(name) => {
      if (name.namespace is None && name.pack is None) {
        if (self._locals.contains(name.name)) {
          x.ty = unify(x.ty, self.get_local(name.name), x.from, x.to);
          return x.ty;
        }
        if (self._fns.contains(name)) {
          x.ty = unify(x.ty, self._fns[name].ty, x.from, x.to);
          return x.ty;
        }
      }
      @diag.error(x.from, x.to, "unknown identifier: \{name}");
      Unknown
    }
    Block(arr) => {
      for c in arr[:arr.length() - 1] {
        c.ty = self.infer(c);
      }
      if (arr.length() == 0) {
        x.ty = unify(x.ty, Unit, x.from, x.to);
        Unit
      } else {
        let ty = self.infer(arr.last().unwrap());
        x.ty = unify(x.ty, ty, x.from, x.to);
        x.ty
      }
    }
    FnDecl(detail) => {
      let env = self.clone();
      let tys = if (x.ty is Function(tys, _)) { tys } else { [] };
      fn get(i) { if (i >= tys.length()) { Type::Unknown } else { tys[i] } }
      detail.params.eachi(fn (i, param) {
        env.add_local(param, get(i))
      });
      env.curr_fn = Some(detail.name);
      guard self._fns[detail.name].ty is Function(_, ret);
      unify(ret, env.infer(detail.body), x.from, x.to) |> ignore;
      x.ty
    }
    Call(func, args, _named) => {
      // how to deal with named?
      let fty = self.infer(func);
      let argtys = args.map(fn (x) { self.infer(x) });
      if (fty is Function(params, ret)) {
        if (argtys.length() != params.length()) {
          @diag.error(x.from, x.to, "expected \{params.length()} arguments, but got \{argtys.length()}");
        } else {
          params.eachi(fn (i, t) { args[i].ty = unify(argtys[i], t, args[i].from, args[i].to) });
        }
        ret
      } else if (fty is Weak(x)) {
        x.val = Function(argtys, Type::weak());
        x.val
      } else {
        @diag.error(x.from, x.to, "calling a non-function type \{fty}");
        Unit
      }
    }
    If(cond, body, other) => {
      cond.ty = unify(self.infer(cond), Bool, cond.from, cond.to);
      let t1 = self.infer(body);
      if (other is Some(z)) {
        let t2 = self.infer(z);
        let t = unify(t1, t2, x.from, x.to);
        body.ty = t; z.ty = t;
        t
      } else {
        body.ty = unify(t1, Unit, body.from, body.to);
        Unit
      }
    }
    Return(val) => {
      if (self.curr_fn is Some(name)) {
        guard self._fns[name].ty is Function(_, ret);
        x.ty = unify(ret, if (val is Some(val)) { self.infer(val) } else { Unit }, x.from, x.to);
        Unit
      } else {
        @diag.error(x.from, x.to, "return type mismatch");
        Unit
      }
    }
    // View(_) => ...
    // Fnalias(_) => ...
    // Typealias(_) => ...
    // TupleAccess(_) => ...
    // Is(_) => ...
    // ArrAccess(_) => ...
    // ExcRange(_) => ...
    // IncRange(_) => ...
    // Match(_) => ...
    // ForIn(_) => ...
    // For(_) => ...
    // While(_) => ...
    // Break(_) => ...
    // Continue(_) => ...
    // Arr(_) => ...
    // Fstr(_) => ...
    // ThisCall(_) => ...
    // FieldRef(_) => ...
    // Unary(_) => ...
    // BinaryInplace(_) => ...
    // EnumConstr(_) => ...
    // EnumDecl(_) => ...
    // GlobalDecl(_) => ...
    // TupleMake(_) => ...
    // TupleDecl(_) => ...
    // ParamDecl(_) => ...
    // StructModif(_) => ...
    // StructInit(_) => ...
    // StructDecl(_) => ...
    // ImplDecl(_) => ...
    _ => panic()
  }
  x.ty = ty;
  ty
}

pub fn Env::check(self: Env) -> AST {
  self.infer(self.ast) |> ignore;
  self.ast.map(fn (x) { { ..x, ty: x.ty.deweak() } });
}
