part of ns_syntax;

// 字符串表达式求值（扩展方法形式）
extension NsSyntaxStringEval on NsSyntax {
  bool _isStringExpr(List<NSToken> t) {
    for (final x in t) {
      if (x.kind == NSTokenKind.stringLit) return true;
      if (x.kind == NSTokenKind.ident) {
        final name = x.value as String;
        final v = env[name];
        if (v is String) return true;
        if (v is List<String>) return true; // 新增：数组变量也视为字符串表达式
      }
    }
    return false;
  }

  String _evalString(List<NSToken> t) {
    final ts = _TS(_stripBlanks(t));
    final v = _strExpr(ts);
    if (!ts.end) throw "string expr: unexpected '${_tokStr(ts.peek())}'";
    return v;
  }

  String _strExpr(_TS ts) {
    var s = _strFactor(ts);
    while (!ts.end) {
      final saved = ts.save();
      if (ts.matchOp('+')) {
        s = s + _strFactor(ts);
      } else {
        ts.restore(saved); break;
      }
    }
    return s;
  }

  String _strFactor(_TS ts) {
    if (ts.end) throw 'string expr: unexpected end';
    final t = ts.peek();

    // 字符串字面量
    if (t.kind == NSTokenKind.stringLit) {
      ts.next();
      return t.value as String;
    }

    // 括号（整体消费）
    if (t.kind == NSTokenKind.operator && nsOperators[t.value as int] == '(') {
      final start = ts.pos;
      int depth = 0;
      int i = start;
      while (i < ts.t.length) {
        final tok = ts.t[i];
        if (tok.kind == NSTokenKind.operator) {
          final op = nsOperators[tok.value as int];
          if (op == '(') { depth++; }
          else if (op == ')') {
            depth--;
            if (depth == 0) break;
          }
        }
        i++;
      }
      if (i >= ts.t.length || ts.t[i].kind != NSTokenKind.operator || nsOperators[ts.t[i].value as int] != ')') {
        throw "string expr: missing ')'";
      }
      final inside = _stripBlanks(ts.t.sublist(start + 1, i));
      final val = _isStringExpr(inside) ? _evalString(inside) : _toStringVal(_evalAuto(inside));
      ts.pos = i + 1;
      return val;
    }

    // 标识符：变量（string 直接用，int/bool/array 转字符串）
    if (t.kind == NSTokenKind.ident) {
      final name = t.value as String;
      ts.next();
      final v = env[name];
      if (v is String) return v;
      if (v is int || v is bool) return _toStringVal(v);
      if (v is List<String>) return _arrayToString(v); // 新增：数组参与拼接
      throw "string expr: unknown variable '$name'";
    }

    // 其他：直到顶层 +
    final startPos = ts.pos;
    int depth = 0;
    int i = startPos;
    while (i < ts.t.length) {
      final tok = ts.t[i];
      if (tok.kind == NSTokenKind.operator) {
        final op = nsOperators[tok.value as int];
        if (op == '(') {
          depth++;
        } else if (op == ')') {
          if (depth == 0) break;
          depth--;
        } else if (op == '+' && depth == 0) {
          break;
        }
      }
      i++;
    }
    final sub = _stripBlanks(ts.t.sublist(startPos, i));
    ts.pos = i;
    final val = _evalAuto(sub);
    return _toStringVal(val);
  }

  String _toStringVal(dynamic v) {
    if (v is String) return v;
    if (v is int) return v.toString();
    if (v is bool) return v ? 'true' : 'false';
    if (v is List<String>) return _arrayToString(v); // 保持使用统一的数组到字符串格式
    throw 'string expr: unsupported value';
  }
}