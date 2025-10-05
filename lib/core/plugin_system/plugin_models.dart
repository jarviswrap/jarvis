import 'package:uuid/uuid.dart';
import 'dart:convert';

/// 参数类型枚举
enum ParameterType {
  none,      // 无类型，用于特殊参数，如 --help
  text,      // 文本输入
  number,    // 数字输入
  boolean,   // 布尔值
  filePath,  // 文件路径选择
  folderPath, // 文件夹路径选择
  textArea,   // 多行文本输入
  textAreaRegex, // 多行文本输入，正则校验
}

enum PluginType {
  shell,
  custom,
}

enum CommandType {
  system,
  file
}

/// 参数配置
class ParameterConfig {
  final String name;
  final ParameterType type;
  final String? value;
  final String? valueRegex;
  final bool required;
  final String? description;

  const ParameterConfig({
    required this.name,
    required this.type,
    this.value,
    this.valueRegex,
    this.required = false,
    this.description,
  });

  factory ParameterConfig.fromMap(Map<String, dynamic> map) {
    String? valueRegex;
    
    // 优先处理Base64编码的正则表达式
    if (map['valueRegex_base64'] != null) {
      try {
        final decodedBytes = base64Decode(map['valueRegex_base64']);
        valueRegex = utf8.decode(decodedBytes);
      } catch (e) {
        // 如果Base64解码失败，记录错误但继续处理
        print('Warning: Failed to decode valueRegex_base64: $e');
        valueRegex = map['valueRegex']; // 回退到原始字段
      }
    } else {
      // 使用原始的valueRegex字段
      valueRegex = map['valueRegex'];
    }
    
    return ParameterConfig(
      name: map['name'] ?? '',
      type: ParameterType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ParameterType.text,
      ),
      value: map['value'],
      valueRegex: valueRegex,
      required: map['required'] is String 
          ? map['required'] == 'true' 
          : (map['required'] ?? false),  // 支持字符串和布尔值
      description: map['description'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'type': type.name,
      if (value != null) 'value': value,
      'required': required,
      if (description != null) 'description': description,
    };
    
    // 如果有正则表达式，同时保存原始和Base64编码版本
    if (valueRegex != null && valueRegex!.isNotEmpty) {
      map['valueRegex'] = valueRegex;
      try {
        final encodedRegex = base64Encode(utf8.encode(valueRegex!));
        map['valueRegex_base64'] = encodedRegex;
      } catch (e) {
        // 如果编码失败，只保存原始版本
        print('Warning: Failed to encode valueRegex to base64: $e');
      }
    }
    
    return map;
  }

  ParameterConfig copyWith({
    String? name,
    ParameterType? type,
    String? value,
    String? valueRegex,
    bool? required,
    String? description,
  }) {
    return ParameterConfig(
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      valueRegex: valueRegex ?? this.valueRegex,
      required: required ?? this.required,
      description: description ?? this.description,
    );
  }
}

enum DisplayType {
  normal,
  compare,
}

class DisplayConfig {
  final DisplayType type;
  final String? param;

  const DisplayConfig({
    required this.type,
    this.param,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      if (param != null) 'param': param,
    };
  }

  factory DisplayConfig.fromMap(Map<String, dynamic> map) {
    return DisplayConfig(
      type: DisplayType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DisplayType.normal,
      ),
      param: map['param'],
    );
  }
}

class CommandConfig {
  final String executableFile;  // 软件路径
  final String? executableDir; // 工作目录 
  final CommandType type;  // 将 String category 改为 CommandType type
  final List<ParameterConfig> parameters;

  const CommandConfig({
    required this.executableFile,
    required this.type,  // 将 category 改为 type
    this.executableDir,
    this.parameters = const [], // 允许为空，默认为空列表
  });

  // 添加序列化方法
  factory CommandConfig.fromMap(Map<String, dynamic> map) {
    final parametersData = map['parameters'] as List<dynamic>? ?? [];
    final parameters = parametersData
        .map((p) => ParameterConfig.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    return CommandConfig(
      executableFile: map['executable_file'] ?? '',
      type: CommandType.values.firstWhere(  // 从字符串解析为枚举
        (e) => e.name == map['type'],
        orElse: () => CommandType.system,
      ),
      // 修复字段映射：应该是executable_dir而不是executable_path
      executableDir: map['executable_dir'] ?? map['executable_path'],
      parameters: parameters,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'executable_file': executableFile,
      'type': type.name,  // 存储枚举的名称
      // 统一使用executable_dir
      if (executableDir != null) 'executable_dir': executableDir,
      'parameters': parameters.map((p) => p.toMap()).toList(),
    };
  }
}

/// 插件配置模型
class PluginConfig {
  final String id;
  final String name;
  final String description;
  final PluginType type;
  final String icon;
  final bool enabled;
  final DisplayConfig? displayConfig;
  final CommandConfig? commandConfig;

  const PluginConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
    required this.enabled,
    this.displayConfig,
    this.commandConfig,
  });

  factory PluginConfig.fromMap(Map<String, dynamic> map) {
    return PluginConfig(
      id: map['id'] ?? const Uuid().v4(),
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      type: PluginType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PluginType.custom,
      ),
      icon: map['icon'] ?? 'extension',
      enabled: map['enabled'] ?? false,
      commandConfig: map['command_config'] != null
          ? CommandConfig.fromMap(Map<String, dynamic>.from(map['command_config']))
          : null,
      displayConfig: map['display_config'] != null
          ? DisplayConfig.fromMap(Map<String, dynamic>.from(map['display_config']))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final commandConfigMap = commandConfig?.toMap() ?? {};
    
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'icon': icon,
      'enabled': enabled,
      'command_config': commandConfigMap,
      'display_config': displayConfig?.toMap(),
    };
  }

  PluginConfig copyWith({
    String? id,
    String? name,
    String? description,
    PluginType? type,
    String? icon,
    bool? enabled,
    CommandConfig? commandConfig,
    DisplayConfig? displayConfig, // 新增：保留展示配置
  }) {
    return PluginConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      enabled: enabled ?? this.enabled,
      displayConfig: displayConfig ?? this.displayConfig, // 新增：传递展示配置
      commandConfig: commandConfig ?? this.commandConfig,
    );
  }
}

/// 插件执行结果
class PluginExecutionResult {
  final bool success;
  final String output;
  final String? error;
  final int? exitCode;
  final DateTime timestamp;

  const PluginExecutionResult({
    required this.success,
    required this.output,
    this.error,
    this.exitCode,
    required this.timestamp,
  });
}

/// 插件生命周期状态
enum PluginLifecycleState {
  uninitialized,
  initializing,
  initialized,
  error,
  disposed,
}

/// 获取参数类型的中文标签
String getParameterTypeLabel(ParameterType type) {
  switch (type) {
    case ParameterType.none:
      return '基础参数';
    case ParameterType.text:
      return '文本';
    case ParameterType.number:
      return '数字';
    case ParameterType.boolean:
      return '布尔值';
    case ParameterType.filePath:
      return '文件路径';
    case ParameterType.folderPath:
      return '目录路径';
    case ParameterType.textArea:
      return '多行文本';
    case ParameterType.textAreaRegex:
      return '多行文本(正则校验)';
  }
}