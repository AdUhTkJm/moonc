fn builtin(x: String) -> Name {
  { pack: Some("@builtin"), ns: None, name: x }
}

///|
/// Looks up a type with the given name in the current typing environment.
/// 
/// The type variables are not looked up; they're directly stuck into the type.
/// 
pub fn Env::lookup_type(self: Env, name: Name, tyvars: Array[Type]) -> Type {
  let name = self.resolve(name);
  if (name.standalone() && self.tyvars.contains(name.name)) {
    return self.tyvars[name.name];
  }
  if (self._structs.contains(name)) {
    return Struct(name, tyvars);
  }
  if (self._enums.contains(name)) {
    return Enum(name, tyvars);
  }
  if (self._abstracts.contains(name)) {
    return Abstract(name, tyvars);
  }
  Unknown
}

pub fn Env::new_local(self: Env, x: AST) -> Unit {
  guard x.kind is VarDecl(detail);
  if (x.ty is Weak(v)) {
    let ty = self.infer(detail.init);
    x.ty = ty; v.val = ty;
    self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty }
    return;
  }
  if (x.ty is Named(n, tyvars)) {
    let ty = self.lookup_type(n, tyvars);
    if (ty is Unknown) {
      @diag.error(x.from, x.to, "unknown type \{n}")
    }
    self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty }
    return;
  }
  self._locals[detail.name] = { name: detail.name, mutable: detail.mutable, ty: x.ty }
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

pub fn Env::unify(self: Env, x: Type, y: Type, from: Loc, to: Loc) -> Type {
  println("unifying \{x.verbose()} with \{y.verbose()}")
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
        x.eachi(fn (i, z) { self.unify(z, y[i], from, to) |> ignore });
      }
      Tuple(x)
    }
    (a, Named(b, arr)) | (Named(b, arr), a) => {
      self.unify(a, self.lookup_type(b, arr), from, to);
    }
    (FixedArray(x), FixedArray(y)) => self.unify(x, y, from, to);
    (Struct(name, arr), Struct(name2, arr2)) |
    (Abstract(name, arr), Struct(name2, arr2)) |
    (Struct(name, arr), Abstract(name2, arr2)) => {
      let name = self.resolve(name);
      let name2 = self.resolve(name2);
      if (name != name2) {
        @diag.error(from, to, "structs do not have the same name");
      } else {
        for i, v in arr {
          self.unify(v, arr2[i], from, to) |> ignore;
        }
      }
      Struct(name, arr)
    }
    (Typevar(a), b) | (b, Typevar(a)) => {
      if (self.tyvars.contains(a.name)) {
        // TODO: check `a.extend` are correctly implemented
        return self.unify(self.tyvars[a.name], b, from, to);
      }
      println("unknown typevar")
      panic();
    }
    _ => {
      @diag.error(from, to, "cannot unify \{x.verbose()} with \{y.verbose()}");
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
      self.unify(self.infer(cond), Bool, cond.from, cond.to) |> ignore;
      if (other is Some(other)) {
        self.unify(self.infer(other), Unit, other.from, other.to) |> ignore;
      }
      Unit
    }
    Binary(kind, l, r) => {
      self.unify(self.infer(l), self.infer(r), x.from, x.to) |> ignore;
      match kind {
        And | Or | Lt | Le | Eq | Ne => Bool
        Assign => Unit
        _ => l.ty
      }
    }
    VarDecl(detail) => {
      x.ty = self.unify(x.ty, self.infer(detail.init), x.from, x.to);
      self.new_local(x);
      Unit
    }
    VarRef(name) => {
      if (name.ns is None && name.pack is None) {
        if (self._locals.contains(name.name)) {
          x.ty = self.unify(x.ty, self.get_local(name.name), x.from, x.to);
          return x.ty;
        }
        if (self._fns.contains(name)) {
          x.ty = self.unify(x.ty, self._fns[name].ty, x.from, x.to);
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
        x.ty = self.unify(x.ty, Unit, x.from, x.to);
        Unit
      } else {
        let ty = self.infer(arr.last().unwrap());
        x.ty = self.unify(x.ty, ty, x.from, x.to);
        x.ty
      }
    }
    FnDecl(detail) => {
      let env = { ..self.clone(), curr_fn: Some(detail.name) };
      let tys = if (x.ty is Function(tys, _)) { tys } else { [] };
      fn get(i) { if (i >= tys.length()) { Type::Unknown } else { tys[i] } }
      detail.params.eachi(fn (i, param) {
        env.add_local(param, get(i))
      });
      for tyvar in detail.tyvars {
        env.tyvars[tyvar.name] = Type::weak();
        env.tyvar_traits[tyvar.name] = tyvar.extend;
      }
      guard self._fns[detail.name].ty is Function(_, ret);
      self.unify(ret, env.infer(detail.body), x.from, x.to) |> ignore;
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
          params.eachi(fn (i, t) { args[i].ty = self.unify(argtys[i], t, args[i].from, args[i].to) });
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
      cond.ty = self.unify(self.infer(cond), Bool, cond.from, cond.to);
      let t1 = self.infer(body);
      if (other is Some(z)) {
        let t2 = self.infer(z);
        let t = self.unify(t1, t2, x.from, x.to);
        body.ty = t; z.ty = t;
        t
      } else {
        body.ty = self.unify(t1, Unit, body.from, body.to);
        Unit
      }
    }
    Return(val) => {
      if (self.curr_fn is Some(name)) {
        guard self._fns[name].ty is Function(_, ret);
        x.ty = self.unify(ret, if (val is Some(val)) { self.infer(val) } else { Unit }, x.from, x.to);
        Unit
      } else {
        @diag.error(x.from, x.to, "return type mismatch");
        Unit
      }
    }
    For(starts, stop, steps, body, exit) => {
      let env = { ..self.clone(), curr_for: Some(x) };
      let vars = Set::new();
      for init in starts {
        let (_var, init) = init;
        vars.add(_var);
        env.add_local(_var, self.infer(init));
      }
      self.unify(env.infer(stop), Bool, stop.from, stop.to) |> ignore;
      for step in steps {
        let (_var, init) = step;
        if (not(vars.contains(_var))) {
          @diag.error(init.from, init.to, "unknown induction variable: \{_var}");
        } else {
          init.ty = self.unify(env._locals[_var].ty, env.infer(init), init.from, init.to);
        }
      }
      body.ty = self.unify(env.infer(body), Unit, body.from, body.to);
      // TODO: break-carried result
      if (exit is Some(exit)) {
        exit.ty = env.infer(exit);
      }
      Unit
    }
    ForIn(vars, list, body, exit) => {
      if (vars.length() >= 3) {
        @diag.error(x.from, x.to, "for .. in supports at most 2 variables");
        return Unit;
      }

      // Work out the type of variables.
      let env = { ..self.clone(), curr_for: Some(x) };
      let lty = self.infer(list);
      let lname = lty.name();
      if (lname is None) {
        @diag.error(list.from, list.to, "must have a proper iter() method");
        return Unit;
      }

      guard lname is Some(lname);
      let mut good = true;
      if (vars.length() == 1) {
        if (self.method_ty(lname, "iter") is Some(Function(args, ret)) && args.length() == 1) {
          self.unify(args[0], lty, list.from, list.to) |> ignore;
          let t = Type::weak();
          let itert: Type = Struct(builtin("Iter"), [t]);
          self.unify(ret, itert, list.from, list.to) |> ignore;
          env.add_local(vars[0], t.deweak());
        } else {
          good = false;
          @diag.error(list.from, list.to, "must have a proper iter() method");
        }
      }
      if (vars.length() == 2) {
        if (self.method_ty(lname, "iter2") is Some(Function(args, ret)) && args.length() == 1) {
          self.unify(args[0], lty, list.from, list.to) |> ignore;
          let p = Type::weak();
          let q = Type::weak();
          let iter2: Type = Struct(builtin("Iter2"), [p, q]);
          self.unify(ret, iter2, list.from, list.to) |> ignore;
          env.add_local(vars[0], p);
          env.add_local(vars[1], q);
        } else {
          good = false;
          @diag.error(list.from, list.to, "must have a proper iter() method");
        }
      }

      // Infer body.
      if (good) {
        let _ = env.infer(body);
        if (exit is Some(exit)) {
          exit.ty = env.infer(exit);
        }
      }

      Unit
    }
    Continue(arr) => {
      // Continue skips the `steps` parts.
      if (self.curr_for is None) {
        @diag.error(x.from, x.to, "continue found outside loop");
        return Unit;
      }
      let mut tys = [];
      if (self.curr_for is Some({ kind: For(starts, _, _, _, _), ..})) {
        tys = starts.map(x => self._locals[x.0].ty);
      } else if (self.curr_for is Some({ kind: ForIn(starts, _, _, _), .. }) ) {
        println(x);
        tys = starts.map(x => self._locals[x].ty)
      }

      if (arr.length() > tys.length()) {
        @diag.error(x.from, x.to, "continue has more results than needed");
        return Unit;
      }
      arr.eachi((i, expr) => {
        expr.ty = self.unify(self.infer(expr), tys[i], expr.from, expr.to);
      });
      Unit
    }
    IncRange(begin, end) | ExcRange(begin, end) => {
      // Verify `begin` and `end` have the same type.
      let bty = self.infer(begin);
      let ety = self.infer(end);
      self.unify(bty, ety, x.from, x.to) |> ignore;

      // They must both be either Int or Int64.
      let deweak = bty.deweak();
      if (not(deweak is Int || deweak is Long)) {
        @diag.error(x.from, x.to, "range expression not supported for this type");
      }

      Struct(builtin("Iter"), [Int]);
    }
    // View(_) => ...
    // Fnalias(_) => ...
    // Typealias(_) => ...
    // TupleAccess(_) => ...
    // Is(_) => ...
    // ArrAccess(_) => ...
    // Match(_) => ...
    // For(_) => ...
    // While(_) => ...
    // Break(_) => ...
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
    _ => {
      println(x);
      panic()
    }
  }
  x.ty = ty;
  ty
}

pub fn Env::check(self: Env) -> AST {
  self.infer(self.ast) |> ignore;
  self.ast.map(fn (x) { { ..x, ty: x.ty.deweak() } });
}
