import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AppLogger {
  static late Talker _talker;
  static late Directory _logDirectory;
  static File? _currentLogFile;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. 设置日志目录
      await _setupLogDirectory();

      // 2. 初始化 Talker（使用正确的API）
      _talker = TalkerFlutter.init(
        settings: TalkerSettings(
          enabled: true,
          useHistory: true,
          maxHistoryItems: 1000,
          useConsoleLogs: kDebugMode,
        ),
        logger: TalkerLogger(
          settings: TalkerLoggerSettings(
            enableColors: !kIsWeb && !Platform.isWindows,
          ),
          // 使用自定义输出函数
          output: _customLogOutput,
        ),
      );

      _isInitialized = true;
      info('AppLogger initialized successfully');
      
    } catch (e, stackTrace) {
      print('Failed to initialize AppLogger: $e');
      print('StackTrace: $stackTrace');
      
      // 降级到仅控制台输出
      _talker = TalkerFlutter.init(
        settings: TalkerSettings(
          enabled: true,
          useHistory: true,
          maxHistoryItems: 500,
          useConsoleLogs: true,
        ),
      );
      _isInitialized = true;
    }
  }

  // 设置日志目录
  static Future<void> _setupLogDirectory() async {
    if (kIsWeb) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logDirectory = Directory(path.join(appDir.path, 'jarvis_logs'));
      
      if (!await _logDirectory.exists()) {
        await _logDirectory.create(recursive: true);
      }

      // 创建当前日志文件
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      _currentLogFile = File(path.join(_logDirectory.path, 'app_$dateStr.log'));

      // 清理旧日志文件（保留最近7天）
      await _cleanOldLogs();
      
    } catch (e) {
      print('Failed to setup log directory: $e');
      rethrow;
    }
  }

  // 自定义日志输出函数
  static void _customLogOutput(String message) {
    // 1. 控制台输出
    if (kDebugMode) {
      print(message);
    }

    // 2. 文件输出（仅在非Web平台）
    if (!kIsWeb && _currentLogFile != null) {
      try {
        final timestamp = DateTime.now().toIso8601String();
        final logEntry = '[$timestamp] $message\n';
        _currentLogFile!.writeAsStringSync(logEntry, mode: FileMode.append);
      } catch (e) {
        print('Failed to write log to file: $e');
      }
    }
  }

  // 清理旧日志文件
  static Future<void> _cleanOldLogs() async {
    try {
      final files = await _logDirectory.list().toList();
      final now = DateTime.now();
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.log')) {
          final stat = await file.stat();
          final age = now.difference(stat.modified).inDays;
          
          if (age > 7) {
            await file.delete();
            print('Deleted old log file: ${path.basename(file.path)}');
          }
        }
      }
    } catch (e) {
      print('Failed to clean old logs: $e');
    }
  }

  // 日志方法
  static void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _talker.debug(message);
  }

  static void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _talker.info(message);
  }

  static void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _talker.warning(message);
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _talker.error(message, error, stackTrace);
  }

  // 获取日志历史
  static List<TalkerData> getLogs() {
    _ensureInitialized();
    return _talker.history;
  }

  // 清除内存日志
  static void clearLogs() {
    _ensureInitialized();
    _talker.cleanHistory();
  }

  // 获取日志文件路径
  static String? getLogFilePath() {
    if (kIsWeb || !_isInitialized || _currentLogFile == null) return null;
    return _currentLogFile!.path;
  }

  // 导出日志文件
  static Future<List<File>> exportLogs() async {
    if (kIsWeb || !_isInitialized) return [];
    
    try {
      final files = await _logDirectory.list().toList();
      return files.whereType<File>().where((f) => f.path.endsWith('.log')).toList();
    } catch (e) {
      error('Failed to export logs', e);
      return [];
    }
  }

  // 获取日志目录大小
  static Future<int> getLogDirectorySize() async {
    if (kIsWeb || !_isInitialized) return 0;
    
    try {
      final files = await _logDirectory.list().toList();
      int totalSize = 0;
      
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      print('AppLogger not initialized, using fallback');
    }
  }

  static Talker get talker => _talker;
}