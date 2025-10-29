part of ns_syntax;

// 正则表达式求值：将字符串模式编译为 RegExp；也支持从已有 regex 变量拷贝
extension NsSyntaxRegexEval on NsSyntax {
  RegExp _evalRegex(List<NSToken> t) {
    final ts = _TS(_stripBlanks(t));
    if (ts.end) throw 'regex expr: empty';

    // 直接引用已有 regex 标识符
    if (ts.t.length == 1 && ts.peek().kind == NSTokenKind.ident) {
      final name = ts.peek().value as String;
      final v = env[name];
      if (v is RegExp) return v;
      throw 'regex expr: "$name" is not regex';
    }

    // 否则作为字符串表达式求值后编译
    final pat = _isStringExpr(ts.t) ? _evalString(ts.t) : _toStringVal(_evalAuto(ts.t));
    return RegExp(pat);
  }
}