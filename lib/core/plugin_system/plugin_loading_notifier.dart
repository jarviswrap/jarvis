import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'plugin_manager.dart';

/// 插件加载状态
enum PluginLoadingState {
  loading,    // 正在加载
  loaded,     // 加载完成
  error,      // 加载失败
}

/// 插件加载状态数据类
@immutable
class PluginLoadingData {
  final PluginLoadingState state;
  final String? errorMessage;
  final PluginManager pluginManager;

  const PluginLoadingData({
    required this.state,
    this.errorMessage,
    required this.pluginManager,
  });

  PluginLoadingData copyWith({
    PluginLoadingState? state,
    String? errorMessage,
    PluginManager? pluginManager,
  }) {
    return PluginLoadingData(
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      pluginManager: pluginManager ?? this.pluginManager,
    );
  }

  // 便捷的getter方法
  bool get isLoading => state == PluginLoadingState.loading;
  bool get isLoaded => state == PluginLoadingState.loaded;
  bool get hasError => state == PluginLoadingState.error;
  String? get error => errorMessage;
}

/// 插件加载状态通知器 (Riverpod版本)
class PluginLoadingNotifier extends StateNotifier<PluginLoadingData> {
  PluginLoadingNotifier() : super(PluginLoadingData(
    state: PluginLoadingState.loading,
    pluginManager: PluginManager(),
  ));

  /// 开始加载插件
  Future<void> loadPlugins() async {
    state = state.copyWith(
      state: PluginLoadingState.loading,
      errorMessage: null,
    );
  
    try {
      // 添加5秒延时
      // await Future.delayed(const Duration(seconds: 5));
      
      await state.pluginManager.loadPluginConfigs();
      await state.pluginManager.initializePlugins();
      
      state = state.copyWith(
        state: PluginLoadingState.loaded,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        state: PluginLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 清除所有缓存并重新加载插件
  Future<void> clearCacheAndReload() async {
    state = state.copyWith(
      state: PluginLoadingState.loading,
      errorMessage: null,
    );

    try {
      // 清除所有插件缓存
      await state.pluginManager.resetToDefaultConfigs();
      
      // 重新初始化插件
      await state.pluginManager.initializePlugins();
      
      state = state.copyWith(
        state: PluginLoadingState.loaded,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        state: PluginLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// 重新加载插件（不清除缓存）
  Future<void> reloadPlugins() async {
    await loadPlugins();
  }
}

/// Riverpod Provider
final pluginLoadingProvider = StateNotifierProvider<PluginLoadingNotifier, PluginLoadingData>((ref) {
  return PluginLoadingNotifier();
});