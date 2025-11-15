import 'package:flutter/material.dart';

class LexResult {
  final NSToken token;
  final int nextIndex; // 消费到的下一个字符位置
  const LexResult(this.token, this.nextIndex);
}

typedef LexHandler = LexResult? Function(String line, int start);

// 增强枚举：为每个 TokenKind 提供解析器（构造参数）
enum NSTokenKind {
  // 按定义顺序作为词法优先级
  blank(_lexBlank),
  comment(_lexComment),
  stringLit(_lexString),
  intLit(_lexInt),
  keyword(_lexKeyword),
  type(_lexType),
  boolLit(_lexBool),
  ident(_lexIdent),
  operator(_lexOperator),
  ;

  final LexHandler parseAt;
  const NSTokenKind(this.parseAt);

  // 词法解析顺序：直接使用枚举定义顺序
  static List<NSTokenKind> get lexOrder => NSTokenKind.values;
}

// ====== 解析器实现（顶层私有函数） ======
LexResult? _lexBlank(String line, int start) {
  if (start >= line.length) return null;
  int i = start;
  while (i < line.length) {
    final c = line.codeUnitAt(i);
    if (!_isBlank(c)) break;
    i++;
  }
  if (i > start) {
    return LexResult(NSToken(NSTokenKind.blank, line.substring(start, i)), i);
  }
  return null;
}

LexResult? _lexComment(String line, int start) {
  if (start >= line.length) return null;
  final c = line.codeUnitAt(start);
  if (c == 35) { // '#'
    return LexResult(NSToken(NSTokenKind.comment, line.substring(start)), line.length);
  }
  return null;
}

LexResult? _lexString(String line, int start) {
  if (start >= line.length) return null;
  if (line.codeUnitAt(start) != 34) return null; // '"'
  int i = start + 1; // 跳过开引号
  final buf = StringBuffer();
  while (i < line.length) {
    final cc = line.codeUnitAt(i);
    if (cc == 34) { i++; break; } // 结束引号
    if (cc == 92 && i + 1 < line.length) { // 反斜杠转义
      final esc = line[i + 1];
      switch (esc) {
        case 'n': buf.write('\n'); break;
        case 't': buf.write('\t'); break;
        case 'r': buf.write('\r'); break;
        case '"': buf.write('"'); break;
        case '\\': buf.write('\\'); break;
        default: buf.write(esc); break;
      }
      i += 2; continue;
    }
    buf.write(String.fromCharCode(cc));
    i++;
  }
  return LexResult(NSToken(NSTokenKind.stringLit, buf.toString()), i);
}

LexResult? _lexInt(String line, int start) {
  if (start >= line.length) return null;
  final c0 = line.codeUnitAt(start);
  if (!_isDigit(c0)) return null;
  int i = start + 1;
  while (i < line.length && _isDigit(line.codeUnitAt(i))) i++;
  final word = line.substring(start, i);
  return LexResult(NSToken(NSTokenKind.intLit, int.parse(word)), i);
}

LexResult? _lexKeyword(String line, int start) {
  final r = _parseWord(line, start);
  if (r == null) return null;
  final lower = r.word.toLowerCase();
  final kwIdx = nsKeywords.indexOf(lower);
  if (kwIdx != -1) {
    return LexResult(NSToken(NSTokenKind.keyword, kwIdx), r.nextIndex);
  }
  return null;
}

LexResult? _lexType(String line, int start) {
  final r = _parseWord(line, start);
  if (r == null) return null;
  final lower = r.word.toLowerCase();
  final typeIdx = nsTypes.indexOf(lower);
  if (typeIdx != -1) {
    return LexResult(NSToken(NSTokenKind.type, typeIdx), r.nextIndex);
  }
  return null;
}

LexResult? _lexBool(String line, int start) {
  final r = _parseWord(line, start);
  if (r == null) return null;
  final lower = r.word.toLowerCase();
  if (lower == 'true' || lower == 'false') {
    return LexResult(NSToken(NSTokenKind.boolLit, lower == 'true'), r.nextIndex);
  }
  return null;
}

LexResult? _lexIdent(String line, int start) {
  final r = _parseWord(line, start);
  if (r == null) return null;
  return LexResult(NSToken(NSTokenKind.ident, r.word), r.nextIndex);
}

LexResult? _lexOperator(String line, int start) {
  if (start >= line.length) return null;
  int i = start;
  String? op;
  if (i + 1 < line.length) {
    final two = line.substring(i, i + 2);
    if (two == '>=' || two == '<=' || two == '==' || two == '!=' || two == '&&' || two == '||' || two == '->') {
      op = two; i += 2;
    }
  }
  if (op == null) {
    final ch = String.fromCharCode(line.codeUnitAt(i));
    const singles = ['+', '-', '*', '/', '%', '(', ')', '=', '>', '<', '!'];
    if (singles.contains(ch)) { op = ch; i++; }
  }
  if (op != null) {
    final idx = nsOperators.indexOf(op);
    return LexResult(NSToken(NSTokenKind.operator, idx), i);
  }
  return null;
}

// ====== 通用词法辅助 ======
class _WordParse {
  final String word;
  final int nextIndex;
  const _WordParse(this.word, this.nextIndex);
}

_WordParse? _parseWord(String line, int start) {
  if (start >= line.length) return null;
  final c0 = line.codeUnitAt(start);
  if (!_isIdentStart(c0)) return null;
  int i = start + 1;
  while (i < line.length && _isIdentChar(line.codeUnitAt(i))) i++;
  return _WordParse(line.substring(start, i), i);
}

bool _isBlank(int c) => c == 9 || c == 32;
bool _isDigit(int c) => c >= 48 && c <= 57;
bool _isIdentStart(int c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95;
bool _isIdentChar(int c) => _isIdentStart(c) || _isDigit(c);

const List<String> nsTypes = ['int', 'bool', 'string', 'array', 'file', 'regex']; // 新增 regex

const List<String> nsKeywords = [
  'let',
  'set',
  'print',
  'if',
  'else',
  'end',
  'while',
  'break',
  'continue',
  'split',
  'by',
  'await',
  'open',
  'close',
  'read',
  'write',
  'seek',
  'delete',
  'create',
  'exists',
  'mode',
  'bytes',
  'line',
  'to',
  'match',
  'with',
  'eof',
  'len', // 新增：数组长度
];

const List<String> nsOperators = [
  '+', '-', '*', '/', '%',
  '(', ')',
  '=', '>', '<',
  '>=', '<=',
  '==', '!=',
  '&&', '||',
  '!',
  '->', // 新增箭头赋值（结果落入变量）
];

class NSToken<T> {
  final NSTokenKind kind;
  final T value;
  const NSToken(this.kind, this.value);

  String get text {
    switch (kind) {
      case NSTokenKind.keyword:  return nsKeywords[value as int];
      case NSTokenKind.operator: return nsOperators[value as int];
      case NSTokenKind.type:     return nsTypes[value as int];
      case NSTokenKind.ident:    return value.toString();
      case NSTokenKind.intLit:   return (value as int).toString();
      case NSTokenKind.boolLit:  return (value as bool) ? 'true' : 'false';
      case NSTokenKind.stringLit: return value as String; // 新增
      case NSTokenKind.blank:    return value.toString();
      case NSTokenKind.comment:  return value.toString();
    }
  }
}

class NSLangSpec {
  // 代码高亮颜色定义
  static const Color typeColor     = Color(0xFFF59E0B); // amber
  static const Color keywordColor  = Color(0xFF8B5CF6); // purple
  static const Color operatorColor = Color(0xFF22D3EE); // cyan
  static const Color intColor      = Color(0xFF60A5FA); // blue
  static const Color boolColor     = Color(0xFF34D399); // green
  static const Color stringColor   = Color(0xFFF472B6); // 新增：pink
  static const Color identColor    = Color(0xFFE5E7EB); // gray-200
  static const Color commentColor  = Color(0xFF9CA3AF); // gray-400

  static Color? colorOfToken(NSToken token) {
    switch (token.kind) {
      case NSTokenKind.type:     return typeColor;
      case NSTokenKind.keyword:  return keywordColor;
      case NSTokenKind.operator: return operatorColor;
      case NSTokenKind.intLit:   return intColor;
      case NSTokenKind.boolLit:  return boolColor;
      case NSTokenKind.stringLit:return stringColor; // 新增
      case NSTokenKind.ident:    return identColor;
      case NSTokenKind.comment:  return commentColor;
      case NSTokenKind.blank:    return null;
    }
  }

  // 如果需要按原始单词高亮，可用此方法
  static Color? colorOfWord(String word) {
    final lower = word.toLowerCase();
    if (nsTypes.contains(lower)) return typeColor;
    if (nsKeywords.contains(lower)) return keywordColor;
    if (nsOperators.contains(lower)) return operatorColor;
    if (RegExp(r'^\d+$').hasMatch(word)) return intColor;
    if (lower == 'true' || lower == 'false') return boolColor;
    return null;
  }
}