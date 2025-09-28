import 'package:flutter/material.dart';
import 'plugin_models.dart';

/// 插件基础接口
abstract class JarvisPlugin {
  /// 插件配置
  PluginConfig get config;
  
  /// 插件初始化
  Future<void> initialize();
  
  /// 插件销毁
  Future<void> dispose();
  
  /// 获取插件主界面Widget
  Widget getMainWidget();
  
  /// 插件是否已初始化
  bool get isInitialized;
  
  /// 执行插件参数
  Future<PluginExecutionResult> executeParameter(String command);
  
  /// 处理插件特定的操作
  Future<dynamic> handleAction(String action, Map<String, dynamic> params);
}