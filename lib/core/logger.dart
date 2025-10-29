import 'dart:io';
import 'package:flutter/foundation.dart';

class AppLogger {
  bool enabled = true;
  String logFilePath = 'tmp/app.log';

  void init({String? path, bool? enabled}) {
    if (path != null) logFilePath = path;
    if (enabled != null) this.enabled = enabled;
  }

  void info(String msg) => _write('INFO', msg);
  void debug(String msg) => _write('DEBUG', msg);
  void error(String msg) => _write('ERROR', msg);

  // 新增：可监听的日志列表（供 UI 使用）
  final ValueNotifier<List<String>> entries = ValueNotifier<List<String>>([]);

  void _write(String level, String msg) {
    if (!enabled) return;
    final ts = DateTime.now().toIso8601String();
    final line = '[$ts][$level] $msg';

    // 同步输出到控制台（避免限流/延迟）
    if (level == 'ERROR') {
      stderr.writeln(line);
    } else {
      stdout.writeln(line);
    }
    debugPrintSynchronously(line);

    // 文件持久化
    try {
      final f = File(logFilePath);
      final dir = f.parent;
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      f.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {
      // 文件写入失败时静默忽略
    }
    // 新增：推送到 UI 日志列表
    final current = List<String>.from(entries.value);
    current.add(line);
    entries.value = current;
  }
}

// 全局单例
final appLogger = AppLogger();