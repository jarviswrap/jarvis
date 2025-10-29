import 'package:flutter/material.dart';

enum NSTokenKind {
  type,     // 类型（int、bool）
  keyword,  // 关键字（let、set、print、if、else、end、while、break、continue）
  ident,    // 标识符（变量名）
  operator, // 操作符：+ - * / ( ) = > < >= <= == != && || !
  comment,  // 注释（# 后整行）
  blank,    // 空白（连续空格或制表符）
  intLit,   // 整数字面量
  boolLit,  // 布尔字面量
  stringLit, // 新增：字符串字面量
}

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

// NS 语言高亮定义：使用 patternMap + stringMap 方式，不使用 language 参数
// 这样可以避免 language 模式覆盖 patternMap 的问题

// 基于关键字/类型/布尔构造排除集，供标识符/函数名识别用
final String _reservedWords =
    [...nsKeywords, ...nsTypes, 'true', 'false'].map(RegExp.escape).join('|');

// 普通标识符（排除关键字/类型/布尔）
final String _identPattern = r'\b(?!' + _reservedWords + r'\b)[A-Za-z_]\w*\b';

// 函数调用标识符（排除关键字/类型/布尔，且后面跟括号）
final String _funcCallPattern = _identPattern + r'(?=\s*\()';

// 新增：关键字与类型的正则，用于 patternMap 精确着色
final String _kwPattern   = r'\b(?:' + nsKeywords.map(RegExp.escape).join('|') + r')\b';
final String _typePattern = r'\b(?:' + nsTypes.map(RegExp.escape).join('|') + r')\b';

// 正则模式映射：用于匹配复杂的语法结构
final Map<String, TextStyle> nsPatternMap = {
  // 注释：# 开头到行尾
  r'#.*$': const TextStyle(color: NSLangSpec.commentColor, fontStyle: FontStyle.italic),

  // 字符串：双引号或单引号包围，支持转义
  r'"(?:[^"\\]|\\.)*"': const TextStyle(color: NSLangSpec.stringColor),
  r"'(?:[^'\\]|\\.)*'": const TextStyle(color: NSLangSpec.stringColor),

  // 数字：整数 / 小数 / 十六进制
  r'\b\d+(?:\.\d+)?\b': const TextStyle(color: NSLangSpec.intColor),
  r'\b0x[0-9A-Fa-f]+\b': const TextStyle(color: NSLangSpec.intColor),

  // 操作符：非捕获分组，避免分组索引问题
  r'(?:->|==|!=|<=|>=|&&|\|\||[+\-*/%()=<>!])': const TextStyle(color: NSLangSpec.operatorColor),

  // 布尔字面量（非捕获分组；stringMap 也会精确匹配）
  r'\b(?:true|false)\b': const TextStyle(color: NSLangSpec.boolColor),

  // 关键字/类型（新增）
  _kwPattern:   const TextStyle(color: NSLangSpec.keywordColor),
  _typePattern: const TextStyle(color: NSLangSpec.typeColor),

  // 标识符：函数调用与普通标识符（参考 colorOfToken 的 identColor）
  _funcCallPattern: const TextStyle(color: NSLangSpec.identColor),
  _identPattern: const TextStyle(color: NSLangSpec.identColor),
};

// 字符串映射：用于精确匹配关键字和类型
// final Map<String, TextStyle> nsStringMap = {
//   // 关键字
//   ...{for (final k in nsKeywords) k: const TextStyle(color: NSLangSpec.keywordColor)},
//   // 类型
//   ...{for (final t in nsTypes) t: const TextStyle(color: NSLangSpec.typeColor)},
//   // 布尔字面量（精确匹配）
//   'true': const TextStyle(color: NSLangSpec.boolColor),
//   'false': const TextStyle(color: NSLangSpec.boolColor),
// };