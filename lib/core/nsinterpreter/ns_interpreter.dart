import 'syntax.dart';

class NsInterpreter {
  final NsSyntax syntax = NsSyntax();

  ExecResult run(String script) {
    syntax.clear();
    final lines = script.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        syntax.lex(line: raw, index: i); // 保留原始行（可含空白/注释）
        continue;
      }
      try {
        syntax.lex(line: raw, index: i);
      } catch (e) {
        syntax.errors.add('Line ${i + 1}: $e');
      }
    }
    return syntax.execute();
  }

  Future<ExecResult> runAsync(String script) async {
    syntax.clear();
    final lines = script.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) {
        syntax.lex(line: raw, index: i);
        continue;
      }
      try {
        syntax.lex(line: raw, index: i);
      } catch (e) {
        syntax.errors.add('Line ${i + 1}: $e');
      }
    }
    // 第1阶段：使用默认 I/O 实现
    return await syntax.executeAsync(DefaultFileIO());
  }
}