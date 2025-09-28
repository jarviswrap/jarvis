import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';
import 'plugin_interface.dart';
import 'plugin_models.dart';
import 'shell_plugin.dart';
import '../utils/app_logger.dart';

class PluginManager {
  static final PluginManager _instance = PluginManager._internal();
  factory PluginManager() => _instance;
  PluginManager._internal();

  final Map<String, JarvisPlugin> _loadedPlugins = {};
  final Map<String, PluginConfig> _pluginConfigs = {};
  final Map<String, PluginLifecycleState> _pluginStates = {};
  
  List<PluginConfig> get availablePlugins => _pluginConfigs.values.toList();
  List<JarvisPlugin> get loadedPlugins => _loadedPlugins.values.toList();
  List<JarvisPlugin> get enabledPlugins => 
      _loadedPlugins.values.where((p) => p.config.enabled).toList();

  /// 从配置文件和本地存储加载插件配置
  Future<void> loadPluginConfigs() async {
    try {
      // 1. 首先从 assets/config/plugins.yaml 加载默认配置
      final Map<String, PluginConfig> defaultConfigs = await _loadDefaultConfigs();
      
      // 2. 从 SharedPreferences 加载已存储的配置
      final Map<String, PluginConfig> storedConfigs = await _loadStoredConfigs();
      
      // 3. 检查并同步新的默认配置到 SharedPreferences
      await _syncDefaultConfigsToStorage(defaultConfigs, storedConfigs);
      
      // 4. 统一从 SharedPreferences 加载所有配置
      await _loadAllConfigsFromStorage();
      
    } catch (e, stackTrace) {
      AppLogger.error('Error loading plugin configs', e, stackTrace);
    }
  }

  /// 加载默认配置文件
  Future<Map<String, PluginConfig>> _loadDefaultConfigs() async {
    final Map<String, PluginConfig> defaultConfigs = {};
    
    try {
      final String yamlString = await rootBundle.loadString('assets/config/plugins.yaml');
      final dynamic yamlData = loadYaml(yamlString);
      
      if (yamlData['plugins'] != null) {
        for (final pluginData in yamlData['plugins']) {
          final config = PluginConfig.fromMap(Map<String, dynamic>.from(pluginData));
          defaultConfigs[config.id] = config;
        }
      }
      
      AppLogger.info('Loaded ${defaultConfigs.length} default plugin configs');
    } catch (e, stackTrace) {
      AppLogger.error('Error loading default configs', e, stackTrace);
    }
    
    return defaultConfigs;
  }

  /// 从 SharedPreferences 加载已存储的配置
  Future<Map<String, PluginConfig>> _loadStoredConfigs() async {
    final Map<String, PluginConfig> storedConfigs = {};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final allPluginsJson = prefs.getString('all_plugins');
      
      if (allPluginsJson != null) {
        final List<dynamic> allPlugins = jsonDecode(allPluginsJson);
        for (final pluginData in allPlugins) {
          final config = PluginConfig.fromMap(Map<String, dynamic>.from(pluginData));
          storedConfigs[config.id] = config;
        }
      }
      
      AppLogger.info('Loaded ${storedConfigs.length} stored plugin configs');
    } catch (e, stackTrace) {
      AppLogger.error('Error loading stored configs', e, stackTrace);
    }
    
    return storedConfigs;
  }

  /// 同步默认配置到 SharedPreferences
  Future<void> _syncDefaultConfigsToStorage(
    Map<String, PluginConfig> defaultConfigs,
    Map<String, PluginConfig> storedConfigs,
  ) async {
    try {
      bool hasNewConfigs = false;
      final Map<String, PluginConfig> mergedConfigs = Map.from(storedConfigs);
      
      // 检查是否有新的默认配置需要添加
      for (final entry in defaultConfigs.entries) {
        final pluginId = entry.key;
        final defaultConfig = entry.value;
        
        if (!storedConfigs.containsKey(pluginId)) {
          // 新的默认配置，添加到存储中
          mergedConfigs[pluginId] = defaultConfig;
          hasNewConfigs = true;
          AppLogger.info('Adding new default plugin config: ${defaultConfig.name}');
        } else {
          // 已存在的配置，保留用户的自定义设置，但可能需要更新默认值
          final storedConfig = storedConfigs[pluginId]!;
          
          // 检查是否需要更新默认配置的某些字段（如新增的命令参数等）
          if (_shouldUpdateStoredConfig(defaultConfig, storedConfig)) {
            final updatedConfig = _mergeConfigs(defaultConfig, storedConfig);
            mergedConfigs[pluginId] = updatedConfig;
            hasNewConfigs = true;
            AppLogger.info('Updating stored plugin config: ${storedConfig.name}');
          }
        }
      }
      
      // 如果有新配置，保存到 SharedPreferences
      if (hasNewConfigs) {
        await _saveAllConfigsToStorage(mergedConfigs);
        AppLogger.info('Synced plugin configs to storage');
      }
      
    } catch (e, stackTrace) {
      AppLogger.error('Error syncing configs to storage', e, stackTrace);
    }
  }

  /// 检查是否需要更新已存储的配置
  bool _shouldUpdateStoredConfig(PluginConfig defaultConfig, PluginConfig storedConfig) {
    // 比较版本号、命令参数数量等，判断是否需要更新
    // 如果任一配置没有 commandConfig，则不需要更新
    if (defaultConfig.commandConfig == null || storedConfig.commandConfig == null) {
      return false;
    }
    
    return defaultConfig.commandConfig!.parameters.length != storedConfig.commandConfig!.parameters.length;
  }

  /// 合并默认配置和已存储配置
  PluginConfig _mergeConfigs(PluginConfig defaultConfig, PluginConfig storedConfig) {
    // 保留用户的自定义设置（如 enabled 状态），但更新默认配置的新字段
    return defaultConfig.copyWith(
      enabled: storedConfig.enabled, // 保留用户的启用状态
      // 可以根据需要保留更多用户自定义字段
    );
  }

  /// 统一从 SharedPreferences 加载所有配置
  Future<void> _loadAllConfigsFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allPluginsJson = prefs.getString('all_plugins');
      
      if (allPluginsJson != null) {
        final List<dynamic> allPlugins = jsonDecode(allPluginsJson);
        
        _pluginConfigs.clear();
        _pluginStates.clear();
        
        for (final pluginData in allPlugins) {
          final config = PluginConfig.fromMap(Map<String, dynamic>.from(pluginData));
          _pluginConfigs[config.id] = config;
          _pluginStates[config.id] = PluginLifecycleState.uninitialized;
        }
        
        AppLogger.info('Loaded ${_pluginConfigs.length} plugin configs from storage');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error loading all configs from storage', e, stackTrace);
    }
  }

  /// 保存所有配置到 SharedPreferences
  Future<void> _saveAllConfigsToStorage(Map<String, PluginConfig> configs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allPlugins = configs.values.map((config) => config.toMap()).toList();
      await prefs.setString('all_plugins', jsonEncode(allPlugins));
    } catch (e, stackTrace) {
      AppLogger.error('Error saving all configs to storage', e, stackTrace);
    }
  }

  /// 保存当前配置到 SharedPreferences
  Future<void> _saveCurrentConfigs() async {
    await _saveAllConfigsToStorage(_pluginConfigs);
  }

  /// 检查是否为默认插件
  bool _isDefaultPlugin(String pluginId) {
    return pluginId.startsWith('shell_');
  }

  /// 初始化所有启用的插件
  Future<void> initializePlugins() async {
    for (final config in _pluginConfigs.values) {
      if (config.enabled) {
        await _loadPlugin(config);
      }
    }
  }

  /// 加载单个插件
  Future<void> _loadPlugin(PluginConfig config) async {
    try {
      _pluginStates[config.id] = PluginLifecycleState.initializing;
      
      final plugin = _createPluginInstance(config);
      
      if (plugin != null) {
        await plugin.initialize();
        _loadedPlugins[config.id] = plugin;
        _pluginStates[config.id] = PluginLifecycleState.initialized;
        AppLogger.info('Plugin ${config.name} loaded successfully');
      }
    } catch (e) {
      _pluginStates[config.id] = PluginLifecycleState.error;
      AppLogger.info('Error loading plugin ${config.name}: $e');
    }
  }

  /// 创建插件实例
  JarvisPlugin? _createPluginInstance(PluginConfig config) {
    switch (config.type) {
      case PluginType.shell:
        return ShellPlugin(config);
      case PluginType.custom:
        // 如果有自定义插件类型的处理逻辑，在这里添加
        AppLogger.info('Custom plugin type not implemented yet: ${config.type}');
        return ShellPlugin(config); // 自定义插件类型暂不支持，返回ShellPlugin
      default:
        AppLogger.info('Unknown plugin type: ${config.type}');
        return null;
    }
  }

  /// 添加新插件
  Future<void> addPlugin(PluginConfig config) async {
    _pluginConfigs[config.id] = config;
    _pluginStates[config.id] = PluginLifecycleState.uninitialized;
    
    if (config.enabled) {
      await _loadPlugin(config);
    }
    
    await _saveCurrentConfigs();
  }

  /// 更新插件配置
  Future<void> updatePlugin(PluginConfig config) async {
    // 如果插件已加载，先卸载
    if (_loadedPlugins.containsKey(config.id)) {
      await disablePlugin(config.id);
    }
    
    _pluginConfigs[config.id] = config;
    
    if (config.enabled) {
      await _loadPlugin(config);
    }
    
    await _saveCurrentConfigs();
  }

  /// 删除插件
  Future<void> removePlugin(String pluginId) async {
    if (_isDefaultPlugin(pluginId)) {
      throw Exception('Cannot remove default plugin');
    }
    
    await disablePlugin(pluginId);
    _pluginConfigs.remove(pluginId);
    _pluginStates.remove(pluginId);
    
    await _saveCurrentConfigs();
  }

  /// 获取插件
  JarvisPlugin? getPlugin(String id) {
    return _loadedPlugins[id];
  }

  /// 获取插件配置
  PluginConfig? getPluginConfig(String id) {
    return _pluginConfigs[id];
  }

  /// 启用插件
  Future<void> enablePlugin(String id) async {
    final config = _pluginConfigs[id];
    if (config != null && !config.enabled) {
      final newConfig = config.copyWith(enabled: true);
      _pluginConfigs[id] = newConfig;
      await _loadPlugin(newConfig);
      await _saveCurrentConfigs();
    }
  }

  /// 禁用插件
  Future<void> disablePlugin(String id) async {
    final plugin = _loadedPlugins[id];
    if (plugin != null) {
      await plugin.dispose();
      _loadedPlugins.remove(id);
      _pluginStates[id] = PluginLifecycleState.disposed;
    }
    
    final config = _pluginConfigs[id];
    if (config != null) {
      _pluginConfigs[id] = config.copyWith(enabled: false);
      await _saveCurrentConfigs();
    }
  }

  /// 获取插件状态
  PluginLifecycleState getPluginState(String id) {
    return _pluginStates[id] ?? PluginLifecycleState.uninitialized;
  }

  /// 按类别分组插件
  Map<String, List<PluginConfig>> getPluginsByCategory() {
    final Map<String, List<PluginConfig>> grouped = {};
    
    for (final config in availablePlugins) {
      final category = config.type.name;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(config);
    }
    
    return grouped;
  }

  /// 销毁所有插件
  Future<void> disposeAllPlugins() async {
    for (final plugin in _loadedPlugins.values) {
      await plugin.dispose();
    }
    _loadedPlugins.clear();
  }

  /// 重置所有插件配置到默认状态
  Future<void> resetToDefaultConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('all_plugins');
      
      // 重新加载配置
      await loadPluginConfigs();
      
      AppLogger.info('Reset all plugin configs to default');
    } catch (e, stackTrace) {
      AppLogger.error('Error resetting to default configs', e, stackTrace);
    }
  }
}