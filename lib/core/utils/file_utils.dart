import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'byte_length_input_formatter.dart';

// FileReadProgress 类：新增 linesRead 字段与构造参数
class FileReadProgress {
  final int bytesRead;
  final int totalBytes;
  final double percent; // 0.0 ~ 1.0
  final String deltaText; // 本次增量文本（UI自行累积）
  final bool done; // 是否读取完成
  final int linesRead; // 原始文件已读取到的行数

  const FileReadProgress({
    required this.bytesRead,
    required this.totalBytes,
    required this.percent,
    this.deltaText = '',
    this.done = false,
    this.linesRead = 0, // 新增：提供默认值
  });
}

// 新增：可取消读取封装
class CancelableFileRead {
  final Stream<FileReadProgress> stream;
  final void Function() cancel;
  CancelableFileRead({required this.stream, required this.cancel});
}

// FileUtils.readWithProgressCancelable：监听响应，传递 linesRead 到事件
class FileUtils {
  static const int defaultMaxBytes = 10240; // 10KB 展示上限
  static const int defaultLargeThresholdBytes = 5 * 1024 * 1024; // 5MB 分流阈值
  static const int defaultReportEveryBytes = 256 * 1024; // 进度上报间隔

  // 新增：可取消版本（返回封装，含 cancel 方法）
  static CancelableFileRead readWithProgressCancelable({
    required String path,
    String? pattern,
    int maxBytes = defaultMaxBytes,
    int largeThresholdBytes = defaultLargeThresholdBytes,
    int reportEveryBytes = defaultReportEveryBytes,
  }) {
    Isolate? isolate;
    SendPort? workerSend;
    ReceivePort? handShake;
    ReceivePort? responsePort;
    bool closed = false;

    void closeAll(StreamController<FileReadProgress> controller) async {
      if (closed) return;
      closed = true;
      try {
        responsePort?.close();
        handShake?.close();
      } catch (_) {}
      try {
        isolate?.kill(priority: Isolate.immediate);
      } catch (_) {}
      try {
        await controller.close();
      } catch (_) {}
    }

    // 修复：先声明，后赋值；将取消逻辑抽到独立函数，避免在初始化表达式中引用自身
    late final StreamController<FileReadProgress> controller;
    void _handleCancel() {
      try {
        workerSend?.send({'type': 'cancel'});
      } catch (_) {}
      closeAll(controller);
    }
    controller = StreamController<FileReadProgress>(
      onCancel: _handleCancel,
    );

    () async {
      try {
        handShake = ReceivePort();
        isolate = await Isolate.spawn(_isolateEntry, handShake!.sendPort);
        workerSend = await handShake!.first as SendPort;

        responsePort = ReceivePort();
        workerSend!.send({
          'path': path,
          'pattern': pattern ?? '',
          'maxBytes': maxBytes,
          'reportEveryBytes': reportEveryBytes,
          'replyTo': responsePort!.sendPort,
          'largeThresholdBytes': largeThresholdBytes,
        });

        responsePort!.listen((message) async {
          if (message is Map) {
            final bytesRead = message['bytesRead'] as int? ?? 0;
            final total = message['totalBytes'] as int? ?? 0;
            final delta = message['deltaText'] as String? ?? '';
            final done = message['done'] as bool? ?? false;
            final canceled = message['canceled'] as bool? ?? false;
            final linesRead = message['linesRead'] as int? ?? 0; // 新增
            final percent = (total <= 0) ? 0.0 : (bytesRead / total).clamp(0.0, 1.0);

            controller.add(FileReadProgress(
              bytesRead: bytesRead,
              totalBytes: total,
              percent: percent,
              deltaText: delta,
              done: done || canceled,
              linesRead: linesRead, // 新增
            ));

            if (done || canceled) {
              _handleCancel();
            }
          } else if (message is String && message == 'error') {
            controller.addError(StateError('读取文件失败'));
            _handleCancel();
          }
        });
      } catch (e) {
        controller.addError(e);
        _handleCancel();
      }
    }();

    return CancelableFileRead(
      stream: controller.stream,
      cancel: _handleCancel,
    );
  }

  // 原方法维持不变：如需取消，请改用 readWithProgressCancelable
  static Stream<FileReadProgress> readWithProgress({
    required String path,
    String? pattern,
    int maxBytes = defaultMaxBytes,
    int largeThresholdBytes = defaultLargeThresholdBytes,
    int reportEveryBytes = defaultReportEveryBytes,
  }) {
    final cancelable = readWithProgressCancelable(
      path: path,
      pattern: pattern,
      maxBytes: maxBytes,
      largeThresholdBytes: largeThresholdBytes,
      reportEveryBytes: reportEveryBytes,
    );
    return cancelable.stream;
  }

  /// 便捷方法：直接读取完整结果（内部订阅进度流并聚合），最后按字节安全截断
  static Future<String> readFully({
    required String path,
    String? pattern,
    int maxBytes = defaultMaxBytes,
    int largeThresholdBytes = defaultLargeThresholdBytes,
    int reportEveryBytes = defaultReportEveryBytes,
  }) async {
    final sb = StringBuffer();
    await for (final p in readWithProgress(
      path: path,
      pattern: pattern,
      maxBytes: maxBytes,
      largeThresholdBytes: largeThresholdBytes,
      reportEveryBytes: reportEveryBytes,
    )) {
      if (p.deltaText.isNotEmpty) sb.write(p.deltaText);
      if (p.done) break;
    }
    return ByteLimitFormatter.truncateUtf8(sb.toString(), maxBytes);
  }
}

// =========================
// Isolate Worker
// =========================
// Worker：_isolateEntry（在后台 Isolate 内部获取 totalBytes，并以此做分流与进度基准）
// 方法/函数：_isolateEntry（新增取消监听与协作式中断）
// _isolateEntry：在所有 replyTo.send(...) 中补充 linesRead
void _isolateEntry(SendPort initialReplyTo) async {
  final port = ReceivePort();
  initialReplyTo.send(port.sendPort);

  final argsCompleter = Completer<Map>();
  bool canceled = false;

  port.listen((message) {
    if (message is Map && message['type'] == 'cancel') {
      canceled = true;
    } else if (message is Map && !argsCompleter.isCompleted) {
      argsCompleter.complete(message);
    }
  });

  final args = await argsCompleter.future;

  final path = args['path'] as String;
  final String pattern = (args['pattern'] as String?) ?? '';
  final int maxBytes = args['maxBytes'] as int? ?? FileUtils.defaultMaxBytes;
  final int reportEveryBytes = args['reportEveryBytes'] as int? ?? FileUtils.defaultReportEveryBytes;
  final int largeThresholdBytes = args['largeThresholdBytes'] as int? ?? FileUtils.defaultLargeThresholdBytes;
  final SendPort replyTo = args['replyTo'] as SendPort;

  final file = File(path);
  final reg = pattern.isNotEmpty ? RegExp(pattern) : null;

  try {
    final totalBytesLocal = await file.length();

    if (totalBytesLocal <= largeThresholdBytes) {
      if (canceled) {
        replyTo.send({
          'bytesRead': 0,
          'totalBytes': totalBytesLocal,
          'deltaText': '',
          'done': true,
          'canceled': true,
          'linesRead': 0, // 新增
        });
        return;
      }
      final raw = await file.readAsString();
      if (canceled) {
        replyTo.send({
          'bytesRead': 0,
          'totalBytes': totalBytesLocal,
          'deltaText': '',
          'done': true,
          'canceled': true,
          'linesRead': 0, // 新增
        });
        return;
      }
      final processed = _applyRegexLineFilter(raw, reg);
      final truncated = ByteLimitFormatter.truncateUtf8(processed, maxBytes);
      replyTo.send({
        'bytesRead': totalBytesLocal,
        'totalBytes': totalBytesLocal,
        'deltaText': truncated,
        'done': true,
        'linesRead': raw.split('\n').length, // 新增
      });
      return;
    }

    final input = file.openRead();
    int bytesRead = 0;
    int lineIndex = 0; // 原始行计数
    int? lastMatchedIndex;
    int outBytesAcc = 0;

    final sbDelta = StringBuffer();
    String remainder = '';

    await for (final chunk in input) {
      if (canceled) {
        replyTo.send({
          'bytesRead': bytesRead,
          'totalBytes': totalBytesLocal,
          'deltaText': '',
          'done': true,
          'canceled': true,
          'linesRead': lineIndex, // 新增
        });
        return;
      }

      bytesRead += chunk.length;
      final segment = utf8.decode(chunk, allowMalformed: true);
      final combined = remainder + segment;
      final parts = combined.split('\n');
      remainder = parts.removeLast();

      for (final line in parts) {
        lineIndex++; // 每读到一行，原始行计数 +1
        final match = reg == null ? true : reg.hasMatch(line);
        if (match) {
          if (reg != null) {
            if (lastMatchedIndex != null && lineIndex != lastMatchedIndex + 1) {
              sbDelta.writeln('');
              outBytesAcc += utf8.encode('\n').length;
            }
            lastMatchedIndex = lineIndex;
          }
          final outLine = '${lineIndex}    $line\n';
          sbDelta.write(outLine);
          outBytesAcc += utf8.encode(outLine).length;
          if (outBytesAcc >= maxBytes) {
            final truncated = ByteLimitFormatter.truncateUtf8(sbDelta.toString(), maxBytes);
            replyTo.send({
              'bytesRead': bytesRead,
              'totalBytes': totalBytesLocal,
              'deltaText': truncated,
              'done': true,
              'linesRead': lineIndex, // 新增
            });
            return;
          }
        }
      }

      if (bytesRead % reportEveryBytes < (chunk.length)) {
        final delta = sbDelta.toString();
        replyTo.send({
          'bytesRead': bytesRead,
          'totalBytes': totalBytesLocal,
          'deltaText': delta,
          'done': false,
          'linesRead': lineIndex, // 新增
        });
        sbDelta.clear();
      }
    }

    if (remainder.isNotEmpty && !canceled) {
      lineIndex++;
      final match = reg == null ? true : reg.hasMatch(remainder);
      if (match) {
        if (reg != null) {
          if (lastMatchedIndex != null && lineIndex != lastMatchedIndex + 1) {
            sbDelta.writeln('');
          }
          lastMatchedIndex = lineIndex;
        }
        final outLine = '${lineIndex}    $remainder\n';
        sbDelta.write(outLine);
      }
    }

    if (!canceled) {
      final finalText = ByteLimitFormatter.truncateUtf8(sbDelta.toString(), maxBytes);
      replyTo.send({
        'bytesRead': totalBytesLocal,
        'totalBytes': totalBytesLocal,
        'deltaText': finalText,
        'done': true,
        'linesRead': lineIndex, // 新增
      });
    } else {
      replyTo.send({
        'bytesRead': bytesRead,
        'totalBytes': totalBytesLocal,
        'deltaText': '',
        'done': true,
        'canceled': true,
        'linesRead': lineIndex, // 新增
      });
    }
  } catch (e) {
    replyTo.send('error');
  }
}

// 行过滤与标注（复用小文件路径）
String _applyRegexLineFilter(String raw, RegExp? reg) {
  final lines = raw.split('\n');
  final buf = StringBuffer();
  int? lastMatchedIndex;
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final match = reg == null ? true : reg.hasMatch(line);
    if (match) {
      if (reg != null) {
        if (lastMatchedIndex != null && i != lastMatchedIndex + 1) {
          buf.writeln('');
        }
        lastMatchedIndex = i;
      }
      buf.write('${i + 1}    ');
      buf.writeln(line);
    }
  }
  return buf.toString();
}