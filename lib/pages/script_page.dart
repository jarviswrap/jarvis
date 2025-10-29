import 'package:flutter/material.dart';
import 'package:jarvis/core/logger.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jarvis/core/nsinterpreter/ns_interpreter.dart';
import 'package:jarvis/core/nsinterpreter/syntax.dart';
import 'package:jarvis/core/nsinterpreter/lang_spec.dart';
import 'package:jarvis/core/color_palette.dart';
import 'package:jarvis/pages/abs/jarvis_stateful.dart';
import 'package:jarvis/widgets/nav_bar.dart';
import 'package:jarvis/assets/scripts_config.dart';
import 'package:jarvis/utils/timeutils.dart';
import 'dart:async';
// 代码
import '../widgets/code_viewer.dart';

class NsScriptPage extends JarvisStateful {
  NsScriptPage({super.key})
      : super(
          isRoot: false,
          title: 'NSInterpreter',
          accent: AccentPalette.forKey('interpreter'),
          actionsBuilder: (BuildContext context) {
            // 通过 context 查找页面 State
            final state = context.findAncestorStateOfType<_ScriptBody>();
            final bool running = state?._running ?? false;

            return [
              // 执行代码：运行中显示 loading 图标并禁用
              NavAction(
                icon: Icons.play_arrow,
                tooltip: running ? '正在执行…' : '执行代码',
                onPressed: running ? null : () => state?._run(),
              ),
              // 清除输出
              NavAction(
                icon: Icons.clear,
                tooltip: '清除输出',
                onPressed: () => state?._clearOutput(),
              )
            ];
          },
        );

  @override
  State<NsScriptPage> createState() => _ScriptBody();
}

class _ScriptBody extends JarvisStatefulState<NsScriptPage> {
  String? currentScripts;

  // 侧栏：当前激活的列表 ID（默认示例），以及持久化键
  String _activeSidebarId = 'examples';
  static const _prefKeySidebarId = 'vscode_sidebar_id';

  // 活动栏：支持多个 IconButton
  final List<ActivityItem> _activityItems = [
    ActivityItem<ScriptsConfig>(id:     'examples', icon: Icons.library_books, tooltip: '示例',     dataList: ScriptsDataStore.instance.exampleScripts),
    ActivityItem<ScriptHistoryItem>(id: 'history',  icon: Icons.history,       tooltip: '执行历史', dataList: ScriptsDataStore.instance.executeHistories),
    ActivityItem<ScriptHistoryItem>(id: 'favorites',icon: Icons.star,          tooltip: '收藏',     dataList: ScriptsDataStore.instance.favoriteRecords),
  ];

  // 布局显隐与尺寸
  bool _showSidebar = true;
  bool _showOutput = true;
  double _sidebarSize = 260;
  double _outputSize = 240;

  // 新增：活动栏宽度与侧栏可见最小宽度（VSCode 风格）
  static const double _activityBarWidth = 48;
  static const double _sidebarMinVisible = 160;
  // 分割控制器
  late MultiSplitViewController _hCtrl; // 水平：侧边栏 | 主区域
  late MultiSplitViewController _vCtrl; // 垂直：编辑区 | 输出区

  // 用于判断拖拽方向的上次宽度记录与抖动过滤
  double? _lastSidebarSizeObserved;
  static const double _deltaEpsilon = 0.5;

  // 新增：拖拽状态与“待处理”标记
  bool _dragging = false;
  bool _pendingHide = false;
  bool _pendingShow = false;

  // 运行态
  bool _running = false;
  List<String> _outputs = [];
  List<String> _errors = [];
  List<String> _logs = [];

  // 持久化键
  static const _prefKeyShowSidebar = 'vscode_show_sidebar';
  static const _prefKeyShowOutput = 'vscode_show_output';
  static const _prefKeySidebarSize = 'vscode_sidebar_size';
  static const _prefKeyOutputSize = 'vscode_output_size';

  Future<void> _initLayoutFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showSidebar = prefs.getBool(_prefKeyShowSidebar) ?? true;
      _showOutput = prefs.getBool(_prefKeyShowOutput) ?? true;
      _sidebarSize = prefs.getDouble(_prefKeySidebarSize) ?? 260;
      _outputSize = prefs.getDouble(_prefKeyOutputSize) ?? 240;
      // 读取激活的侧栏列表 ID
      _activeSidebarId = prefs.getString(_prefKeySidebarId) ?? 'examples';
      _buildControllers();
    });
  }

  // 切换活动栏项：如果侧栏隐藏则先显示，再切换列表；否则直接切换
  Future<void> _onSelectActivityItem(String id) async {
    setState(() {
      if (_showSidebar) {
        _activeSidebarId = id;
      } else {
        _showSidebar = true;
        _activeSidebarId = id;
        if (_sidebarSize < _sidebarMinVisible) {
          _sidebarSize = _sidebarMinVisible;
        }
        _buildControllers();
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyShowSidebar, _showSidebar);
    await prefs.setString(_prefKeySidebarId, id);
  }

  // 启动时加载历史
  @override
  void initState() {
    super.initState();
    _initLayoutFromPrefs();
    ScriptsDataStore.instance.init();
  }

  // 双击历史项回填脚本到编辑器
  void _applyScript(String script) {
    setState(() {
      currentScripts = script;
    });
  }

  @override
  void dispose() {
    _hCtrl.dispose();
    _vCtrl.dispose();
    ScriptsDataStore.instance.dispose();
    super.dispose();
  }


  Widget _buildSideBar<T>(BuildContext context, ActivityItem<T> activityItem, Widget Function(T) childBuilder, {String? emptyTips, void Function(T)? doubleTap, bool orderDesc = false}) {
    return ValueListenableBuilder<List<T>>(
      valueListenable: activityItem.dataList,
      builder: (context, items, _) {
        // 空列表返回占位视图，避免构建空列表时的异常链
        if (items.isEmpty) {
          return Center(
            child: Text(emptyTips??'暂无记录', style: const TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          key: PageStorageKey(activityItem.id),
          primary: false,
          cacheExtent: 800,
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x20FFFFFF)),
          itemBuilder: (context, i) {
            final idx = orderDesc? items.length - 1 - i : i; // 最新在上
            final it = items[idx];

            return GestureDetector(
              onDoubleTap: () => doubleTap?.call(it),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: childBuilder(it),
              ),
            );
          },
        );
      },
    );
  }

  // 示例列表（沿用 _Sidebar 的视觉样式）
  Widget _buildExamplesList(BuildContext context) {
    return _buildSideBar(context, _activityItems[0] as ActivityItem<ScriptsConfig>, (ScriptsConfig item) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          item.title,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.white),
        ),
      );
    }, doubleTap: (it) => _applyScript(it.script));
  }

  // 历史列表（支持双击回填 + 右下角收藏）
  Widget _buildHistoryList(BuildContext context, {ActivityItem<ScriptHistoryItem>? activityItem, bool orderDesc = true}) {
    activityItem = activityItem??(_activityItems[1] as ActivityItem<ScriptHistoryItem>);
    return _buildSideBar(context, activityItem, (ScriptHistoryItem it) {
      final bool isFav = ScriptsDataStore.instance.isFavorite(it);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Stack(
          children: [
            // 文本区域
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  it.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)
                      ?? const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${fmtTime(it.timeMs)} · ${it.lines} 行',
                  style: const TextStyle(color: Color(0xFFAEDBFF), fontSize: 10),
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            // 右下角收藏按钮（监听收藏状态，点击后立即刷新）
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton(
                    tooltip: isFav ? '取消收藏' : '收藏',
                    iconSize: 18,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                    onPressed: () => {
                      ScriptsDataStore.instance.toggleFavoriteByScript(it),
                      setState(() {}),
                    },
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? const Color(0xFFFFD54F) : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
            ),
          ],
        ),
      );
    }, doubleTap: (it) => _applyScript(it.script), orderDesc: orderDesc);
  }

  Widget _buildFavoritesList(BuildContext context) {
    return _buildHistoryList(context, activityItem:_activityItems[2] as ActivityItem<ScriptHistoryItem>);
  }
  
  void _buildControllers() {
    // 始终保留两个区域：侧栏 + 主区域
    _hCtrl = MultiSplitViewController(areas: [
      // 可见时允许拖到极小；隐藏时保留 1px 柄
      Area(
        size: _showSidebar ? _sidebarSize : 1,
        min: 1,
      ),
      Area(), // 主区域自适应
    ]);
    _vCtrl = MultiSplitViewController(areas: [
      Area(), // 编辑区
      if (_showOutput) Area(size: _outputSize, min: 140),
    ]);

    _hCtrl.addListener(_persistHorizontalSizes);
    _vCtrl.addListener(_persistVerticalSizes);
  }

  // 方法：监听水平尺寸变化，自动隐藏与恢复（支持 size 为 null 的情况）
  Future<void> _persistHorizontalSizes() async {
    final a = _hCtrl.areas;
    if (a.isEmpty || a.first.size == null) return;
    final s = a.first.size!;
    final prev = _lastSidebarSizeObserved;
    final hasPrev = prev != null;
    final isShrinking = hasPrev ? (s < prev! - _deltaEpsilon) : false;
    final isGrowing  = hasPrev ? (s > prev! + _deltaEpsilon) : false;

    // 缩小 + 低于阈值：标记隐藏
    if (_showSidebar && isShrinking && s <= _sidebarMinVisible) {
      appLogger.info('隐藏侧边栏（方向: 缩小）');
      _pendingHide = true;
    }

    // 放大 + 超过阈值：标记显示
    if (!_showSidebar && isGrowing) {
      appLogger.info('显示侧边栏（方向: 放大）');
      _pendingShow = true;
    }

    // 可见时持续更新记忆宽度
    if (_showSidebar) {
      _sidebarSize = s;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeySidebarSize, _sidebarSize);
    }

    // 更新上次观察值
    _lastSidebarSizeObserved = s;
  }

  // 新增：指针事件处理，在抬起时统一应用隐藏/显示
  Future<void> _onPointerDown() async {
    _dragging = true;
    _pendingHide = false;
    _pendingShow = false;
  }

  Future<void> _onPointerUp() async {
    _dragging = false;

    if (_pendingHide) {
      setState(() {
        _showSidebar = false;
        // 记住一个可见宽度用于恢复；区域尺寸重置为 1px 柄
        _sidebarSize = _sidebarMinVisible;
        _buildControllers();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyShowSidebar, _showSidebar);
      _pendingHide = false;
      _lastSidebarSizeObserved = 1; // 与隐藏柄一致
    }

    if (_pendingShow) {
      // 使用当前观测到的尺寸，显示时至少为 _sidebarMinVisible
      final observed = _lastSidebarSizeObserved ?? _sidebarMinVisible;
      final double target = observed < _sidebarMinVisible ? _sidebarMinVisible : observed;
      setState(() {
        _showSidebar = true;
        _sidebarSize = target;
        _buildControllers();
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyShowSidebar, _showSidebar);
      await prefs.setDouble(_prefKeySidebarSize, _sidebarSize);
      _pendingShow = false;
      _lastSidebarSizeObserved = _sidebarSize;
    }
  }

  Future<void> _persistVerticalSizes() async {
    if (!_showOutput) return;
    final a = _vCtrl.areas;
    if (a.length >= 2 && a[1].size != null) {
      _outputSize = a[1].size!;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefKeyOutputSize, _outputSize);
    }
  }

  Future<void> _run() async {
    if (_running) return;
    appLogger.info('开始执行脚本');
    setState(() {
      _running = true;
      _outputs = [];
      _errors = [];
      _logs = ['[info] 开始执行脚本'];
    });

    final interpreter = NsInterpreter();

    // 流式输出
    interpreter.syntax.onOutput = (line) {
      if (!mounted) return;
      setState(() {
        _outputs = [..._outputs, line];
      });
    };

    final script = currentScripts ?? '';
    _logs = [..._logs, '[debug] 语句行数: ${script.split(RegExp(r'\r?\n')).length}'];
    ScriptsDataStore.instance.appendExecution(script);
    ExecResult res;
    try {
      res = await interpreter.runAsync(script);
    } catch (e) {
      res = ExecResult(success: false, outputs: const [], errors: ['$e'], envSnapshot: const {});
    } finally {
      interpreter.syntax.onOutput = null;
    }

    setState(() {
      _outputs = res.outputs;
      _errors = res.errors;
      _logs = [..._logs, '[info] 执行结束', '[info] 输出 ${res.outputs.length} 条，错误 ${res.errors.length} 条'];
      _running = false;
    });
    appLogger.info('脚本执行结束');
  }

  void _clearOutput() {
    setState(() {
      _outputs = [];
    });
  }

  Widget buildEditor() {
    final theme = Theme.of(context);

    // 统一文本样式（等宽与稳定行高）
    final textStyle = theme.textTheme.bodyMedium!.copyWith(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
    );
    final lineNumberStyle = textStyle.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // 基于 lang_spec 与 code_viewer 的预定义正则构建高亮规则
    final reservedWords = {...nsKeywords, ...nsTypes, 'true', 'false'};
    final highlightMap = <RegExp, Color>{
      // 注释（整行）
      commentLineStartPattern('#'): NSLangSpec.commentColor,

      // 字符串（单双引号，支持转义）
      stringDoublePattern(): NSLangSpec.stringColor,
      stringSinglePattern(): NSLangSpec.stringColor,

      // 数字（十进制/十六进制）
      numberDecimalPattern(): NSLangSpec.intColor,
      numberHexPattern(): NSLangSpec.intColor,

      // 操作符集合
      operatorSetPattern(nsOperators.toSet()): NSLangSpec.operatorColor,

      // 布尔字面量
      wordSetPattern({'true', 'false'}): NSLangSpec.boolColor,

      // 关键字与类型
      wordSetPattern(nsKeywords.toSet()): NSLangSpec.keywordColor,
      wordSetPattern(nsTypes.toSet()): NSLangSpec.typeColor,

      // 标识符（排除关键字/类型/布尔）
      identifierPattern(reservedWords: reservedWords): NSLangSpec.identColor,
    };

    return Padding(padding: const EdgeInsets.only(left: 0, top: 0, right: 10, bottom: 0),
      child:  CodeViewer(
        text: currentScripts??"",
        codeStyle: textStyle,
        lineNumberStyle: lineNumberStyle,
        highlightMap: highlightMap,
        wrap: true, // 自动换行；视觉行不重复显示行号
        background: theme.colorScheme.surface,
        gutterBackground: Colors.transparent,
        // 其他参数使用默认值即可（padding/gutterPadding/宽度区间）
      )
    );
  }

  @override
  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _ActivityBar(
          width: _activityBarWidth,
          active: _showSidebar,
          activeId: _activeSidebarId,
          accent: theme.colorScheme.primary,
          items: _activityItems,
          onSelect: _onSelectActivityItem,
        ),
        Expanded(
          child: Listener(
            onPointerDown: (_) => _onPointerDown(),
            onPointerUp: (_) => _onPointerUp(),
            onPointerCancel: (_) => _onPointerUp(),
            child: MultiSplitView(
              controller: _hCtrl,
              axis: Axis.horizontal,
              builder: (BuildContext context, Area area) {
                final int areaIndex = area.index;
                if (areaIndex == 0) {
                  return Container(
                    color: const Color(0xFF1E293B),
                    child: Offstage(
                      offstage: !_showSidebar,
                      child: _Sidebar(
                        activeId: _activeSidebarId,
                        lists: {
                          _activityItems[0].id: (ctx) => _buildExamplesList(ctx),
                          _activityItems[1].id:  (ctx) => _buildHistoryList(ctx),
                          _activityItems[2].id: (ctx) => _buildFavoritesList(ctx),
                        },
                      ),
                    ),
                  );
                } else {
                  return _MainWithOutput(
                    verticalCtrl: _vCtrl,
                    editor: buildEditor(),
                    output: _OutputPanel(outputs: _outputs, errors: _errors, logs: _logs),
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

// 通用侧栏：支持多个数据列表，通过 activeId 选择展示
class _Sidebar extends StatelessWidget {
  final Map<String, Widget Function(BuildContext)> lists;
  final String activeId;

  const _Sidebar({
    required this.lists,
    required this.activeId,
  });

  @override
  Widget build(BuildContext context) {
    final builder = lists[activeId];
    return Container(
      color: const Color(0xFF1E293B),
      child: RepaintBoundary(
        child: builder != null
            ? builder(context)
            : const Center(child: Text('暂无数据', style: TextStyle(color: Colors.white))),
      ),
    );
  }
}

// 主编辑区 + 底部输出（垂直分割）
class _MainWithOutput extends StatelessWidget {
  final MultiSplitViewController verticalCtrl;
  final Widget editor;
  final Widget output;

  const _MainWithOutput({
    required this.verticalCtrl,
    required this.editor,
    required this.output,
  });

  @override
  Widget build(BuildContext context) {
    return MultiSplitView(
      controller: verticalCtrl,
      axis: Axis.vertical,
      builder: (context, area) {
        final int areaIndex = area.index;
        return areaIndex == 0 ? editor : output;
      },
    );
  }
}

// 输出面板（输出 / 错误 / 日志）
class _OutputPanel extends StatelessWidget {
  final List<String> outputs;
  final List<String> errors;
  final List<String> logs;
  const _OutputPanel({required this.outputs, required this.errors, required this.logs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.dividerColor)),
              color: const Color(0xFF111827),
            ),
            child: const TabBar(
              tabs: [
                Tab(text: '输出'),
                Tab(text: '错误'),
                Tab(text: '日志'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LogList(lines: outputs, color: Colors.white),
                _LogList(lines: errors, color: const Color(0xFFFFA8A8)),
                _LogList(lines: logs, color: const Color(0xFFAEDBFF)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<String> lines;
  final Color color;
  const _LogList({required this.lines, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111827),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(lines[i], style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 13)),
        ),
      ),
    );
  }
}

// 文件顶部：增加 ActivityItem 声明
class ActivityItem<T> {
  final String id;
  final IconData icon;
  final String tooltip;
  final ValueNotifier<List<T>> dataList;
  const ActivityItem({required this.id, required this.icon, required this.tooltip, required this.dataList});
  void dispose() { dataList.dispose(); }
}

// 左侧固定图标栏（支持多个模块，当前仅“示例”）
class _ActivityBar extends StatelessWidget {
  final double width;
  final bool active;
  final String activeId;
  final Color accent;
  final List<ActivityItem> items;
  final void Function(String id) onSelect;

  const _ActivityBar({
    required this.width,
    required this.active,
    required this.activeId,
    required this.accent,
    required this.items,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surfaceVariant;

    return Container(
      width: width,
      color: bg,
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 动态图标按钮列表
          for (final it in items) IconButton(
            tooltip: active && activeId == it.id ? '隐藏侧栏' : it.tooltip,
            onPressed: () => onSelect(it.id),
            icon: Icon(
              it.icon,
              color: active && activeId == it.id
                  ? accent
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
