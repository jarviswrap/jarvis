part of ns_syntax;

// 执行结果
class ExecResult {
  final bool success;
  final List<String> outputs;
  final List<String> errors;
  final Map<String, dynamic> envSnapshot;
  const ExecResult({
    required this.success,
    required this.outputs,
    required this.errors,
    required this.envSnapshot,
  });
}

// 位置信息（0-based）
class Position {
  final int line;
  final int col;
  const Position(this.line, this.col);
}

// 语法问题
class SyntaxIssue {
  final Position position;
  final String reason;
  const SyntaxIssue({required this.position, required this.reason});
}

// 块信息（用于基本结构校验）
class _CtrlBlock {
  final String kind; // 'if' | 'while'
  final int startLine;
  bool seenElse = false;
  _CtrlBlock(this.kind, this.startLine);
}