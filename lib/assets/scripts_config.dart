import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/material.dart';


class ScriptsConfig {
  final String title;
  final String script;
  ScriptsConfig({required this.title, required this.script});

  factory ScriptsConfig.fromJson(Map<String, dynamic> json) {
    return ScriptsConfig(
      title: json['title'] as String,
      script: json['script'] as String,
    );
  }

  // 自动从脚本生成标题
  factory ScriptsConfig.fromScript(String script) {
    return ScriptsConfig(
      title: _deriveTitle(script),
      script: script,
    );
  }

  // 提供公共方法，供外部（例如历史摘要生成）复用
  static String deriveTitle(String script) => _deriveTitle(script);

  static String _deriveTitle(String script) {
    const int maxLen = 64;
    if (script.trim().isEmpty) return '脚本';

    final lines = script.split(RegExp(r'\r?\n'));
    final List<String> commentSegments = [];
    final List<String> codeSegments = [];
    int consumed = 0;

    for (final raw in lines) {
      if (consumed >= maxLen) break;
      final line = raw.trim();
      if (line.isEmpty) continue;

      final bool isComment = line.startsWith('#');
      // 注释去掉开头的#以及后续空格；代码保持原样
      String segment = isComment
          ? line.replaceFirst(RegExp(r'^#+\s*'), '')
          : line;

      if (segment.isEmpty) continue;

      final int available = maxLen - consumed;
      final String taken = segment.length > available
          ? segment.substring(0, available)
          : segment;
      if (taken.isEmpty) break;

      if (isComment) {
        commentSegments.add(taken);
      } else {
        codeSegments.add(taken);
      }
      consumed += taken.length;
    }

    String commentTitle = commentSegments.join(' ').trim();
    String codeTitle = codeSegments.join(' ').trim();

    String title;
    if (commentTitle.isNotEmpty && codeTitle.isNotEmpty) {
      title = '$commentTitle: $codeTitle';
    } else {
      title = commentTitle.isNotEmpty ? commentTitle : codeTitle;
    }
    if (title.isEmpty) title = '脚本';
    if (title.length > maxLen) title = title.substring(0, maxLen);
    return title;
  }
}

Future<List<ScriptsConfig>> loadExampleScripts() async {
  final raw = await rootBundle.loadString('assets/scripts.json');
  final list = (json.decode(raw) as List<dynamic>).cast<String>();
  return list.map((s) => ScriptsConfig.fromScript(s)).toList();
}

// 类 ScriptsConfig 不变，这里仅展示 ScriptHistoryItem 与 ScriptHistoryStore 的重构

class ScriptHistoryItem extends ScriptsConfig {
  final int timeMs;     // 毫秒时间戳（持久化）
  final int lines;      // 运行时字段：从 script 解析（加载时生成）

  // 运行时构造：用于内存展示（持久化仍仅保存 t/c）
  ScriptHistoryItem({
    required this.timeMs,
    required super.script,
    required super.title,
    required this.lines,
  });

  // 持久化写入：仅保存时间与完整脚本
  Map<String, dynamic> toJson() => {
    't': timeMs,
    'c': script,
  };

  // 从持久化读取：加载时解析 title 与 lines
  factory ScriptHistoryItem.fromJson(Map<String, dynamic> json) {
    final int t = json['t'] as int? ?? 0;
    final String c = json['c'] as String? ?? '';
    final String computedTitle = ScriptsConfig.deriveTitle(c);
    final int computedLines = c.isEmpty ? 0 : c.split(RegExp(r'\r?\n')).length;
    return ScriptHistoryItem(
      timeMs: t,
      script: c,
      title: computedTitle,
      lines: computedLines,
    );
  }

  // 便捷构造：新执行产生的记录（内存展示即时可用；持久化仍仅 t/c）
  factory ScriptHistoryItem.newRun(String script, {DateTime? time}) {
    final int t = (time ?? DateTime.now()).millisecondsSinceEpoch;
    final String computedTitle = ScriptsConfig.deriveTitle(script);
    final int computedLines = script.isEmpty ? 0 : script.split(RegExp(r'\r?\n')).length;
    return ScriptHistoryItem(
      timeMs: t,
      script: script,
      title: computedTitle,
      lines: computedLines,
    );
  }
}

// 执行历史存储：SharedPreferences 持久化，最大容量 50，先进先出
class ScriptHistoryStore {
  static const String defaultKey = 'ns_exec_history';
  static const String favoritesKey = 'ns_exec_favorites';

  // 默认最大容量
  static const int _max = 50;

  // 使用指定 key 加载
  static Future<List<ScriptHistoryItem>> loadWithKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return <ScriptHistoryItem>[];
    try {
      final List<dynamic> list = json.decode(raw) as List<dynamic>;
      final items = <ScriptHistoryItem>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          items.add(ScriptHistoryItem.fromJson(e));
        } else if (e is Map) {
          items.add(ScriptHistoryItem.fromJson(Map<String, dynamic>.from(e)));
        }
      }
      while (items.length > _max) {
        items.removeAt(0);
      }
      return items;
    } catch (_) {
      return <ScriptHistoryItem>[];
    }
  }

  // 使用指定 key 保存（仅持久化时间与完整脚本）
  static Future<void> saveWithKey(String key, List<ScriptHistoryItem> items) async {
    final trimmed = items.length > _max ? items.sublist(items.length - _max) : items;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      json.encode(trimmed.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  // 使用指定 key 追加一条脚本并保存
  static Future<List<ScriptHistoryItem>> appendScriptWithKey(String key, String script) async {
    final items = await loadWithKey(key);
    items.add(ScriptHistoryItem.newRun(script));
    if (items.length > _max) {
      items.removeAt(0);
    }
    await saveWithKey(key, items);
    return items;
  }

  // 使用指定 key 清空
  static Future<void> clearWithKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // 兼容旧 API：默认 key 为历史记录 key
  static Future<List<ScriptHistoryItem>> load() => loadWithKey(defaultKey);
  static Future<void> save(List<ScriptHistoryItem> items) => saveWithKey(defaultKey, items);
  static Future<List<ScriptHistoryItem>> appendScript(String script) => appendScriptWithKey(defaultKey, script);
  static Future<void> clear() => clearWithKey(defaultKey);
}

// 统一数据仓库：示例/历史/收藏集中管理 + 与 SharedPreferences 的高效同步
class ScriptsDataStore {
  // 单例
  static final ScriptsDataStore instance = ScriptsDataStore._();
  ScriptsDataStore._();

  // 内存列表（ValueNotifier 便于 UI 响应）
  final ValueNotifier<List<ScriptsConfig>> exampleScripts =
      ValueNotifier<List<ScriptsConfig>>(<ScriptsConfig>[]);
  final ValueNotifier<List<ScriptHistoryItem>> executeHistories =
      ValueNotifier<List<ScriptHistoryItem>>(<ScriptHistoryItem>[]);
  final ValueNotifier<List<ScriptHistoryItem>> favoriteRecords =
      ValueNotifier<List<ScriptHistoryItem>>(<ScriptHistoryItem>[]);

  // 状态
  bool _inited = false;
  Timer? _persistHistoryTimer;
  Timer? _persistFavoritesTimer;

  // 容量上限（与 ScriptHistoryStore 保持一致）
  static const int _max = 50;

  // 初始化：预加载 + 绑定监听（历史/收藏改动去抖保存）
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    // 示例脚本（仅内存缓存；来源于 assets）
    try {
      final examples = await loadExampleScripts();
      exampleScripts.value = List.unmodifiable(examples);
    } catch (_) {
      exampleScripts.value = const <ScriptsConfig>[];
    }

    // 历史与收藏：从 SharedPreferences 加载
    final histories = await ScriptHistoryStore.load();
    executeHistories.value = List.unmodifiable(histories);

    final favorites = await ScriptHistoryStore.loadWithKey(ScriptHistoryStore.favoritesKey);
    favoriteRecords.value = List.unmodifiable(favorites);

    // 改动监听：去抖持久化
    executeHistories.addListener(_schedulePersistHistories);
    favoriteRecords.addListener(_schedulePersistFavorites);
  }

  // 去抖保存（历史）
  void _schedulePersistHistories() {
    _persistHistoryTimer?.cancel();
    _persistHistoryTimer = Timer(const Duration(milliseconds: 250), () async {
      await ScriptHistoryStore.save(executeHistories.value);
    });
  }

  // 去抖保存（收藏）
  void _schedulePersistFavorites() {
    _persistFavoritesTimer?.cancel();
    _persistFavoritesTimer = Timer(const Duration(milliseconds: 250), () async {
      await ScriptHistoryStore.saveWithKey(
        ScriptHistoryStore.favoritesKey,
        favoriteRecords.value,
      );
    });
  }

  // 追加执行历史
  void appendExecution(String script) {
    final item = ScriptHistoryItem.newRun(script);
    final next = List<ScriptHistoryItem>.from(executeHistories.value)..add(item);
    final trimmed = next.length > _max ? next.sublist(next.length - _max) : next;
    executeHistories.value = List.unmodifiable(trimmed);
    // 保存由监听器自动去抖触发
  }

  // 切换收藏（按脚本内容唯一）
  void toggleFavoriteByScript(ScriptHistoryItem item) {  
    final favs = List<ScriptHistoryItem>.from(favoriteRecords.value);
    final idx = favs.indexWhere((e) { return e.script == item.script && e.timeMs == item.timeMs; });
    if (idx >= 0) {
      favs.removeAt(idx);
    } else {
      favs.add(item);
    }
    final trimmed = favs.length > _max ? favs.sublist(favs.length - _max) : favs;
    favoriteRecords.value = List.unmodifiable(trimmed);
    // 保存由监听器自动去抖触发
  }

  // 直接设置收藏列表（例如批量操作）
  void setFavorites(List<ScriptHistoryItem> items) {
    final trimmed = items.length > _max ? items.sublist(items.length - _max) : items;
    favoriteRecords.value = List.unmodifiable(trimmed);
  }

  bool isFavorite(ScriptHistoryItem item) => favoriteRecords.value.indexWhere((e) { return e.script == item.script && e.timeMs == item.timeMs; }) >= 0;

  // 清空历史（内存 + 持久化）
  Future<void> clearHistories() async {
    executeHistories.value = const <ScriptHistoryItem>[];
    await ScriptHistoryStore.clear();
  }

  // 清空收藏（内存 + 持久化）
  Future<void> clearFavorites() async {
    favoriteRecords.value = const <ScriptHistoryItem>[];
    await ScriptHistoryStore.clearWithKey(ScriptHistoryStore.favoritesKey);
  }

  // 释放资源（页面关闭时可调用）
  void dispose() {
    _persistHistoryTimer?.cancel();
    _persistFavoritesTimer?.cancel();
    executeHistories.removeListener(_schedulePersistHistories);
    favoriteRecords.removeListener(_schedulePersistFavorites);
    exampleScripts.dispose();
    executeHistories.dispose();
    favoriteRecords.dispose();
    _inited = false;
  }
}
