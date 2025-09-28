import 'package:flutter/foundation.dart';
import 'plugin_manager.dart';

/// 插件加载状态
enum PluginLoadingState {
  loading,    // 正在加载
  loaded,     // 加载完成
  error,      // 加载失败
}

/// 插件加载状态通知器
class PluginLoadingNotifier extends ChangeNotifier {
  static final PluginLoadingNotifier _instance = PluginLoadingNotifier._internal();
  factory PluginLoadingNotifier() => _instance;
  PluginLoadingNotifier._internal();

  PluginLoadingState _state = PluginLoadingState.loading;
  String? _errorMessage;
  final PluginManager _pluginManager = PluginManager();

  PluginLoadingState get state => _state;
  String? get errorMessage => _errorMessage;
  PluginManager get pluginManager => _pluginManager;

  /// 开始加载插件
  Future<void> loadPlugins() async {
    _state = PluginLoadingState.loading;
    _errorMessage = null;
    notifyListeners();
  
    try {
      // 临时清除缓存以强制重新加载 YAML 配置
      await _pluginManager.resetToDefaultConfigs();
      
      await _pluginManager.loadPluginConfigs();
      await _pluginManager.initializePlugins();
      
      _state = PluginLoadingState.loaded;
      _errorMessage = null;
    } catch (e) {
      _state = PluginLoadingState.error;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  /// 清除所有缓存并重新加载插件
  Future<void> clearCacheAndReload() async {
    _state = PluginLoadingState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // 清除所有插件缓存
      await _pluginManager.resetToDefaultConfigs();
      
      // 重新初始化插件
      await _pluginManager.initializePlugins();
      
      _state = PluginLoadingState.loaded;
      _errorMessage = null;
    } catch (e) {
      _state = PluginLoadingState.error;
      _errorMessage = e.toString();
    }
    
    notifyListeners();
  }

  /// 重新加载插件（不清除缓存）
  Future<void> reloadPlugins() async {
    await loadPlugins();
  }
}