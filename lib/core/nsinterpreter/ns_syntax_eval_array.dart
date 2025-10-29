part of ns_syntax;

// 数组表达式求值：支持 split 与正则 match
extension NsSyntaxArrayEval on NsSyntax {
  List<String> _evalArray(List<NSToken> t) {
    final ts = _TS(_stripBlanks(t));
    if (ts.end || ts.peek().kind != NSTokenKind.keyword) {
      throw 'array expr: expected split or match';
    }
    final headKw = nsKeywords[ts.peek().value as int];

    if (headKw == 'split') {
      ts.next(); // 消费 'split'
      int depth = 0;
      int byIdx = -1;
      for (var i = ts.pos; i < ts.t.length; i++) {
        final tok = ts.t[i];
        if (tok.kind == NSTokenKind.operator) {
          final op = nsOperators[tok.value as int];
          if (op == '(') depth++;
          else if (op == ')') { if (depth > 0) depth--; }
        } else if (tok.kind == NSTokenKind.keyword && nsKeywords[tok.value as int] == 'by' && depth == 0) {
          byIdx = i; break;
        }
      }
      if (byIdx == -1) throw 'array expr: missing "by"';

      final leftToks = _stripBlanks(ts.t.sublist(ts.pos, byIdx));
      if (leftToks.isEmpty) throw 'array expr: empty subject for split';
      final subject = _isStringExpr(leftToks) ? _evalString(leftToks) : _toStringVal(_evalAuto(leftToks));

      final delimToks = _stripBlanks(ts.t.sublist(byIdx + 1));
      if (delimToks.isEmpty) throw 'array expr: empty delimiter after "by"';
      final delim = _isStringExpr(delimToks) ? _evalString(delimToks) : _toStringVal(_evalAuto(delimToks));

      return subject.split(delim);
    }

    if (headKw == 'match') {
      ts.next(); // 消费 'match'
      // 找顶层的 'with'
      int depth = 0;
      int withIdx = -1;
      for (var i = ts.pos; i < ts.t.length; i++) {
        final tok = ts.t[i];
        if (tok.kind == NSTokenKind.operator) {
          final op = nsOperators[tok.value as int];
          if (op == '(') depth++; else if (op == ')') { if (depth > 0) depth--; }
        } else if (tok.kind == NSTokenKind.keyword && nsKeywords[tok.value as int] == 'with' && depth == 0) {
          withIdx = i; break;
        }
      }
      if (withIdx == -1) throw 'array expr: missing "with"';

      // 左侧：待匹配字符串
      final subjectToks = _stripBlanks(ts.t.sublist(ts.pos, withIdx));
      if (subjectToks.isEmpty) throw 'array expr: empty subject for match';
      final subject = _isStringExpr(subjectToks) ? _evalString(subjectToks) : _toStringVal(_evalAuto(subjectToks));

      // 右侧：正则（regex 变量或字符串模式）
      final patternToks = _stripBlanks(ts.t.sublist(withIdx + 1));
      if (patternToks.isEmpty) throw 'array expr: empty pattern for match';

      RegExp regex;
      if (patternToks.length == 1 && patternToks.first.kind == NSTokenKind.ident) {
        final name = patternToks.first.value as String;
        final v = env[name];
        if (v is! RegExp) throw 'array expr: "$name" is not regex';
        regex = v;
      } else {
        final pat = _isStringExpr(patternToks) ? _evalString(patternToks) : _toStringVal(_evalAuto(patternToks));
        regex = RegExp(pat);
      }

      final m = regex.firstMatch(subject);
      if (m == null) return <String>[];
      final groups = <String>[];
      for (var i = 1; i <= m.groupCount; i++) {
        groups.add(m.group(i) ?? '');
      }
      return groups;
    }

    throw 'array expr: expected split or match';
  }

  // 变更：数组转字符串使用全角逗号 '，' 作为分隔符
  String _arrayToString(List<String> arr) => arr.map((e) => e.toString()).join(',');

  bool _isArrayExpr(List<NSToken> t) {
    final tt = _stripBlanks(t);
    if (tt.isEmpty) return false;
    final h = tt.first;
    if (h.kind == NSTokenKind.keyword) {
      final kw = nsKeywords[h.value as int];
      if (kw == 'split' || kw == 'match') return true; // 新增：识别 match
    }
    if (tt.length == 1 && h.kind == NSTokenKind.ident) {
      final name = h.value as String;
      final v = env[name];
      return v is List<String>;
    }
    return false;
  }
}