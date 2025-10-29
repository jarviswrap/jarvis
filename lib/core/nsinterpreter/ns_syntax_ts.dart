part of ns_syntax;

// TokenStream：顺序读取 + 回退点
class _TS {
  final List<NSToken> t;
  int pos = 0;
  _TS(this.t);

  bool get end => pos >= t.length;
  NSToken peek() => t[pos];
  NSToken next() => t[pos++];

  int save() => pos;
  void restore(int p) => pos = p;

  bool matchOp(String op) {
    if (end) return false;
    final tok = peek();
    if (tok.kind == NSTokenKind.operator && nsOperators[tok.value as int] == op) {
      pos++;
      return true;
    }
    return false;
  }
}

// 便于错误提示的 token 字符串
String _tokStr(NSToken t) {
  switch (t.kind) {
    case NSTokenKind.keyword:  return nsKeywords[t.value as int];
    case NSTokenKind.operator: return nsOperators[t.value as int];
    case NSTokenKind.type:     return nsTypes[t.value as int];
    case NSTokenKind.ident:    return t.value.toString();
    case NSTokenKind.intLit:   return (t.value as int).toString();
    case NSTokenKind.boolLit:  return (t.value as bool) ? 'true' : 'false';
    case NSTokenKind.stringLit: return t.value as String;
    case NSTokenKind.blank:    return ' ';
    case NSTokenKind.comment:  return t.value.toString();
  }
}