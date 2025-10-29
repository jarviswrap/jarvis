import 'syntax.dart';

class NsInterpreter {
  final NsSyntax syntax = NsSyntax();

  Future<ExecResult> runAsync(String script) async {
    syntax.clear();
    final lines = script.split(RegExp(r'\r?\n'));
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      try {
        syntax.lex(line: raw, index: i);
      } catch (e) {
        syntax.errors.add('Line ${i + 1}: $e');
      }
    }
    return await syntax.executeAsync(DefaultFileIO());
  }
}