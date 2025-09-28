import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class RegexPattern {
  final String id;
  final String name;
  final String pattern;
  final String description;
  final String example;
  final String category;

  const RegexPattern({
    required this.id,
    required this.name,
    required this.pattern,
    required this.description,
    required this.example,
    required this.category,
  });

  factory RegexPattern.fromMap(Map<String, dynamic> map) {
    return RegexPattern(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      pattern: map['pattern'] ?? '',
      description: map['description'] ?? '',
      example: map['example'] ?? '',
      category: map['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'pattern': pattern,
      'description': description,
      'example': example,
      'category': category,
    };
  }
}

class RegexConfigLoader {
  static RegexConfigLoader? _instance;
  static RegexConfigLoader get instance => _instance ??= RegexConfigLoader._();
  
  RegexConfigLoader._();

  List<RegexPattern>? _cachedPatterns;
  Map<String, List<RegexPattern>>? _cachedCategorizedPatterns;

  /// 加载所有正则表达式模式
  Future<List<RegexPattern>> loadPatterns() async {
    if (_cachedPatterns != null) {
      return _cachedPatterns!;
    }

    try {
      final yamlString = await rootBundle.loadString('assets/config/regex_patterns.yaml');
      final yamlMap = loadYaml(yamlString) as Map;
      
      final List<RegexPattern> patterns = [];
      final regexPatterns = yamlMap['regex_patterns'] as Map;
      
      for (final categoryEntry in regexPatterns.entries) {
        final categoryPatterns = categoryEntry.value as List;
        for (final patternData in categoryPatterns) {
          final patternMap = Map<String, dynamic>.from(patternData);
          patterns.add(RegexPattern.fromMap(patternMap));
        }
      }
      
      _cachedPatterns = patterns;
      return patterns;
    } catch (e) {
      print('加载正则表达式配置失败: $e');
      return _getDefaultPatterns();
    }
  }

  /// 按分类获取正则表达式模式
  Future<Map<String, List<RegexPattern>>> loadCategorizedPatterns() async {
    if (_cachedCategorizedPatterns != null) {
      return _cachedCategorizedPatterns!;
    }

    final patterns = await loadPatterns();
    final Map<String, List<RegexPattern>> categorized = {};
    
    for (final pattern in patterns) {
      if (!categorized.containsKey(pattern.category)) {
        categorized[pattern.category] = [];
      }
      categorized[pattern.category]!.add(pattern);
    }
    
    _cachedCategorizedPatterns = categorized;
    return categorized;
  }

  /// 根据ID获取特定的正则表达式模式
  Future<RegexPattern?> getPatternById(String id) async {
    final patterns = await loadPatterns();
    try {
      return patterns.firstWhere((pattern) => pattern.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 搜索正则表达式模式
  Future<List<RegexPattern>> searchPatterns(String query) async {
    if (query.isEmpty) {
      return await loadPatterns();
    }
    
    final patterns = await loadPatterns();
    final lowerQuery = query.toLowerCase();
    
    return patterns.where((pattern) {
      return pattern.name.toLowerCase().contains(lowerQuery) ||
             pattern.description.toLowerCase().contains(lowerQuery) ||
             pattern.category.toLowerCase().contains(lowerQuery) ||
             pattern.pattern.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 清除缓存
  void clearCache() {
    _cachedPatterns = null;
    _cachedCategorizedPatterns = null;
  }

  /// 默认的正则表达式模式（作为后备）
  List<RegexPattern> _getDefaultPatterns() {
    return [
      const RegexPattern(
        id: 'email',
        name: '邮箱地址',
        pattern: r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
        description: '匹配标准邮箱格式',
        example: 'example@domain.com',
        category: '基础验证',
      ),
      const RegexPattern(
        id: 'phone_cn',
        name: '手机号码',
        pattern: r'^1[3-9]\d{9}$',
        description: '匹配中国大陆手机号',
        example: '13812345678',
        category: '基础验证',
      ),
      const RegexPattern(
        id: 'integer',
        name: '整数',
        pattern: r'^-?\d+$',
        description: '匹配正负整数',
        example: '-123, 0, 456',
        category: '数字相关',
      ),
    ];
  }
}