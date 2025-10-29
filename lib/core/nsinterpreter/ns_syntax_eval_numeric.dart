part of ns_syntax;

// 数值/布尔表达式求值（扩展方法形式）
extension NsSyntaxNumericEval on NsSyntax {

  bool _boolOr(_TS ts) {
    var v = _boolAnd(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('||')) {
        v = v || _boolAnd(ts);
      } else { ts.restore(s); break; }
    }
    return v;
  }

  bool _boolAnd(_TS ts) {
    var v = _boolNot(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('&&')) {
        v = v && _boolNot(ts);
      } else { ts.restore(s); break; }
    }
    return v;
  }

  bool _boolNot(_TS ts) {
    final s = ts.save();
    if (ts.matchOp('!')) {
      return !_boolPrimary(ts);
    }
    ts.restore(s);
    return _boolPrimary(ts);
  }

  bool _boolPrimary(_TS ts) {
    if (ts.end) throw 'bool expr: unexpected end';
    final t = ts.peek();

    if (t.kind == NSTokenKind.boolLit) {
      ts.next(); return t.value as bool;
    }
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String; ts.next();
      final v = env[name];
      if (v is bool) return v;
      throw "bool expr: unknown variable '$name'";
    }
    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      ts.next();
      final v = _boolOr(ts);
      if (!ts.matchOp(')')) throw "bool expr: missing ')'";
      return v;
    }

    // 比较（左边必须是整型表达式）
    final left = _intExpr(ts);
    final s = ts.save();
    if (ts.matchOp('=='))  return left == _intExpr(ts);
    if (ts.matchOp('!='))  return left != _intExpr(ts);
    if (ts.matchOp('>='))  return left >= _intExpr(ts);
    if (ts.matchOp('<='))  return left <= _intExpr(ts);
    if (ts.matchOp('>'))   return left > _intExpr(ts);
    if (ts.matchOp('<'))   return left < _intExpr(ts);
    ts.restore(s);
    throw "bool expr: unexpected '${_tokStr(t)}'";
  }

  int _intExpr(_TS ts) {
    var v = _intTerm(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('+'))       { v = v + _intTerm(ts); }
      else if (ts.matchOp('-'))  { v = v - _intTerm(ts); }
      else { ts.restore(s); break; }
    }
    return v;
  }

  int _intTerm(_TS ts) {
    var v = _intFactor(ts);
    while (!ts.end) {
      final s = ts.save();
      if (ts.matchOp('*'))       { v = v * _intFactor(ts); }
      else if (ts.matchOp('/'))  { 
        final r = _intFactor(ts);
        if (r == 0) throw 'int expr: division by zero';
        v = v ~/ r;
      }
      else if (ts.matchOp('%'))  { v = v % _intFactor(ts); }
      else { ts.restore(s); break; }
    }
    return v;
  }

  int _intFactor(_TS ts) {
    if (ts.end) throw 'int expr: unexpected end';
    final t = ts.peek();

    // 新增：len <arrayVar>，返回数组长度
    if (t.kind == NSTokenKind.keyword && nsKeywords[t.value as int] == 'len') {
        ts.next(); // 消费 'len'
        if (ts.end) throw 'len: expected array identifier';
        final id = ts.peek();
        if (id.kind != NSTokenKind.ident) throw 'len: expected array identifier';
        final name = id.value as String;
        ts.next(); // 消费标识符
        final v = env[name];
        if (v is List<String>) return v.length;
        throw 'len: "$name" is not an array';
    }

    if (t.kind == NSTokenKind.intLit) {
      ts.next(); return t.value as int;
    }
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String; ts.next();
      final v = env[name];
      if (v is int) return v;
      throw "int expr: unknown variable '$name'";
    }
    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      ts.next();
      final v = _intExpr(ts);
      if (!ts.matchOp(')')) throw "int expr: missing ')'";
      return v;
    }
    // 一元负号
    final s = ts.save();
    if (ts.matchOp('-')) {
      return -_intFactor(ts);
    }
    ts.restore(s);

    throw "int expr: unexpected '${_tokStr(t)}'";
  }
}