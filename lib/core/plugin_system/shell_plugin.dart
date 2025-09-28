import 'dart:io';
import 'package:flutter/material.dart';
import 'plugin_interface.dart';
import 'plugin_models.dart';
import '../utils/app_logger.dart';
import '../../screens/shell_plugin_screen.dart';

class ShellPlugin implements JarvisPlugin {
  final PluginConfig _config;
  bool _isInitialized = false;

  ShellPlugin(this._config);

  @override
  PluginConfig get config => _config;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize() async {
    AppLogger.info('Initializing Shell Plugin: ${config.name}');
     _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    AppLogger.info('Disposing Shell Plugin: ${config.name}');
    _isInitialized = false;
  }

  @override
  Widget getMainWidget() {
    return ShellPluginScreen(plugin: this);
  }

  @override
  Future<PluginExecutionResult> executeParameter(String command) async {
    // 直接执行，就像在终端中一样
    final result = await Process.run('sh', ['-c', command]);
    
    return PluginExecutionResult(
      success: result.exitCode == 0,
      output: result.stdout.toString(),
      error: result.stderr.toString(),
      exitCode: result.exitCode,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<dynamic> handleAction(String action, Map<String, dynamic> params) async {
  }
}