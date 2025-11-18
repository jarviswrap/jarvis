import 'package:flutter/material.dart';
import 'package:jarvis/core/color_palette.dart';
import 'package:jarvis/pages/abs/jarvis_stateful.dart';
import 'package:jarvis/widgets/nav_bar.dart';
import 'package:jarvis/core/workflow_store.dart';
import 'package:jarvis/core/android_sdk_analyzer.dart';

class WorkflowPage extends JarvisStateful {
  WorkflowPage({super.key})
      : super(
          isRoot: false,
          title: '创建工作流',
          accent: AccentPalette.forKey('workflow'),
          actionsBuilder: (BuildContext context) {
            final state = context.findAncestorStateOfType<_WorkflowBody>();
            return [
              NavAction(
                icon: Icons.save,
                tooltip: '保存配置',
                onPressed: () => state?._saveCurrent(),
              ),
            ];
          },
        );

  @override
  State<WorkflowPage> createState() => _WorkflowBody();
}

class _WorkflowBody extends JarvisStatefulState<WorkflowPage> {
  // Templates for common workflows
  static const List<_Template> _templates = [
    _Template(
      key: 'backup_downloads_daily',
      name: '定时备份下载目录（每日）',
      triggerType: 'schedule',
      cron: '0 2 * * *',
      steps: ['压缩 ~/Downloads', '复制到 ~/Backup'],
      platforms: ['macos', 'linux'],
    ),
    _Template(
      key: 'logs_archive_weekly',
      name: '日志压缩归档（每周）',
      triggerType: 'schedule',
      cron: '0 3 * * 1',
      steps: ['收集 /var/log', '压缩为 logs-YYYYWW.zip', '归档到 ~/Archives'],
      platforms: ['linux'],
    ),
    _Template(
      key: 'cleanup_temp_manual',
      name: '手动清理临时文件',
      triggerType: 'manual',
      steps: ['删除 ~/.cache/tmp', '清理 ~/Downloads/*.tmp'],
      platforms: ['macos', 'linux'],
    ),
  ];

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _cronCtrl = TextEditingController();
  String _triggerType = 'manual';
  final Set<String> _platforms = {'macos', 'linux'};
  final List<TextEditingController> _stepCtrls = [TextEditingController()];
  _Template? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    WorkflowStore.instance.init();
  }

  @override
  Widget content(BuildContext context) {
    final muted = const Color(0xFFA7B0C0);
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 顶部标签
          Container(
            margin: const EdgeInsets.only(left: 24, right: 24, top: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0x1FFFFFFF)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const TabBar(
              labelPadding: EdgeInsets.symmetric(vertical: 10),
              tabs: [
                Tab(text: '通用工作流'),
                Tab(text: 'Android SDK 依赖分析'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Tab 1: 通用工作流
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSavedList(muted),
                      const SizedBox(height: 20),
                      Divider(color: const Color(0x1FFFFFFF)),
                      const SizedBox(height: 16),
                      _buildForm(muted),
                    ],
                  ),
                ),
                // Tab 2: SDK 依赖分析
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: _buildSdkAnalyzer(muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList(Color muted) {
    return ValueListenableBuilder<List<WorkflowConfig>>(
      valueListenable: WorkflowStore.instance.workflows,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return Text('当前暂无已保存的工作流配置。', style: TextStyle(color: muted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('已保存的工作流', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((wf) {
                final accent = AccentPalette.forKey(wf.name);
                return Container(
                  width: 320,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withOpacity(0.12), const Color(0x08FFFFFF)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(wf.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (wf.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        Text(wf.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip('触发', wf.triggerType == 'manual' ? '手动' : '定时 ${wf.cron ?? ''}'),
                          _Chip('平台', wf.platforms.join(', ')),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // 辅助：统一样式的轻量标签显示
  Widget _Chip(String label, String value) {
    const borderColor = Color(0x1FFFFFFF);
    const bgColor = Color(0x14000000);
    const muted = Color(0xFFA7B0C0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ---------- Android SDK 依赖分析 ----------
  final TextEditingController _projPathCtrl = TextEditingController(text: '/Volumes/exssd/catchii_android');
  final TextEditingController _pkgPrefixCtrl = TextEditingController(text: 'sg.bigo.media.live');
  bool _analyzing = false;
  SdkAnalysisResult? _analysisResult;

  Widget _buildSdkAnalyzer(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Android 项目与 MediaSDK 依赖分析', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('目标：扫描 Android 项目对 MediaSDK 的所有接口调用，并列出调用来源（文件与行号）。', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        // 配置输入
        TextField(
          controller: _projPathCtrl,
          decoration: InputDecoration(
            labelText: 'Android 项目路径',
            hintText: '/absolute/path/to/project',
            helperText: '例如：/Volumes/exssd/catchii_android',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _pkgPrefixCtrl,
                decoration: InputDecoration(
                  labelText: 'SDK 包名前缀',
                  hintText: '例如：sg.bigo.media.live',
                  helperText: '用于筛选 import 行（例如：import sg.bigo.media.live.*）',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _analyzing ? null : _runAnalysis,
              icon: _analyzing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow),
              label: Text(_analyzing ? '分析中…' : '开始分析'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _analysisResult == null ? null : _saveAnalysisConfig,
              icon: const Icon(Icons.save),
              label: const Text('保存分析配置'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 结果
        if (_analysisResult == null)
          Text('尚未执行分析。', style: TextStyle(color: muted))
        else
          _buildAnalysisResult(_analysisResult!, muted),
      ],
    );
  }

  Widget _buildAnalysisResult(SdkAnalysisResult result, Color muted) {
    final apis = result.usages.keys.toList()
      ..sort((a, b) {
        final ca = '${a.package}.${a.className}';
        final cb = '${b.package}.${b.className}';
        final cc = ca.compareTo(cb);
        return cc != 0 ? cc : a.methodName.compareTo(b.methodName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('分析完成：接口数 ${result.apiCount} · 调用点 ${result.callSiteCount}'),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('警告/错误：\n${result.errors.join('\n')}', style: const TextStyle(color: Colors.orange)),
        ],
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: apis.length,
          separatorBuilder: (_, __) => const Divider(color: Color(0x1FFFFFFF), height: 1),
          itemBuilder: (context, i) {
            final api = apis[i];
            final sites = result.usages[api] ?? const <CallSite>[];
            final fqn = '${api.package}.${api.className}#${api.methodName}';
            return ExpansionTile(
              title: Text(fqn, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(api.signature, style: TextStyle(color: muted)),
              children: [
                for (final s in sites)
                  ListTile(
                    leading: Icon(s.kind == 'static' ? Icons.bolt : Icons.call_made, color: s.kind == 'static' ? Colors.amber : Colors.cyan),
                    title: Text('${s.filePath}:${s.line}'),
                    subtitle: Text(s.lineText, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _analyzing = true;
      _analysisResult = null;
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final res = await analyzer.analyzeUsageOnly(
        projectPath: _projPathCtrl.text.trim(),
        sdkPackagePrefix: _pkgPrefixCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _analysisResult = res);
    } catch (e) {
      _showSnack('分析出现异常：$e');
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _saveAnalysisConfig() async {
    final name = 'MediaSDK 依赖分析';
    final steps = [
      'project=${_projPathCtrl.text.trim()}',
      'pkg=${_pkgPrefixCtrl.text.trim()}',
    ];
    final cfg = WorkflowConfig(
      id: 'wf_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: '分析 ${_projPathCtrl.text.trim()} 对 MediaSDK 的接口调用',
      platforms: const ['macos', 'linux'],
      triggerType: 'manual',
      steps: steps,
      template: 'android_sdk_analyzer',
      createdAt: DateTime.now(),
    );
    await WorkflowStore.instance.add(cfg);
    _showSnack('分析配置已保存');
  }

  Widget _buildForm(Color muted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('新建工作流配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        // Template selection
        Row(
          children: [
            const Text('常用模板'),
            const SizedBox(width: 12),
            DropdownButton<_Template>(
              value: _selectedTemplate,
              hint: const Text('选择模板（可选）'),
              items: [
                const DropdownMenuItem<_Template>(value: null, child: Text('不使用模板')),
                ..._templates.map((t) => DropdownMenuItem<_Template>(value: t, child: Text(t.name))),
              ],
              onChanged: (t) {
                setState(() {
                  _selectedTemplate = t;
                  if (t != null) {
                    _triggerType = t.triggerType;
                    _cronCtrl.text = t.cron ?? '';
                    _platforms
                      ..clear()
                      ..addAll(t.platforms);
                    // Reset steps
                    for (final c in _stepCtrls) c.dispose();
                    _stepCtrls
                      ..clear()
                      ..addAll(t.steps.map((s) => TextEditingController(text: s)));
                    if (_stepCtrls.isEmpty) _stepCtrls.add(TextEditingController());
                    if (_nameCtrl.text.trim().isEmpty) {
                      _nameCtrl.text = t.name;
                    }
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Name & Description
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: '名称',
            hintText: '例如：每日备份下载目录',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: '描述（可选）',
            hintText: '为工作流添加一句简要说明',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 16),
        // Platforms
        const Text('平台选择'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            _platformCheckbox('macos'),
            _platformCheckbox('linux'),
          ],
        ),
        const SizedBox(height: 16),
        // Trigger
        const Text('触发方式'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('手动'),
              selected: _triggerType == 'manual',
              onSelected: (sel) => setState(() {
                if (sel) _triggerType = 'manual';
              }),
            ),
            ChoiceChip(
              label: const Text('定时'),
              selected: _triggerType == 'schedule',
              onSelected: (sel) => setState(() {
                if (sel) _triggerType = 'schedule';
              }),
            ),
            if (_triggerType == 'schedule')
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _cronCtrl,
                  decoration: InputDecoration(
                    labelText: 'Cron 表达式',
                    hintText: '例如：0 2 * * *',
                    helperText: '使用标准 5 字段 cron（分钟 小时 日 月 周）',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Steps
        const Text('步骤'),
        const SizedBox(height: 8),
        Column(
          children: [
            for (int i = 0; i < _stepCtrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stepCtrls[i],
                        decoration: InputDecoration(
                          hintText: '例如：压缩 ~/Downloads',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: '删除该步骤',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                        if (_stepCtrls.length > 1) {
                          final c = _stepCtrls.removeAt(i);
                          c.dispose();
                        } else {
                          _stepCtrls[i].clear();
                        }
                      }),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
                icon: const Icon(Icons.add),
                label: const Text('添加步骤'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Save button (duplicate of navbar action for convenience)
        ElevatedButton.icon(
          onPressed: _saveCurrent,
          icon: const Icon(Icons.save),
          label: const Text('保存配置'),
        ),
      ],
    );
  }

  Widget _platformCheckbox(String key) {
    final checked = _platforms.contains(key);
    return FilterChip(
      label: Text(key),
      selected: checked,
      onSelected: (sel) => setState(() {
        if (sel) {
          _platforms.add(key);
        } else {
          _platforms.remove(key);
        }
      }),
    );
  }

  Future<void> _saveCurrent() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('请填写工作流名称');
      return;
    }
    final id = 'wf_${DateTime.now().millisecondsSinceEpoch}';
    final steps = _stepCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    final config = WorkflowConfig(
      id: id,
      name: name,
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      platforms: _platforms.toList(),
      triggerType: _triggerType,
      cron: _triggerType == 'schedule' ? (_cronCtrl.text.trim().isEmpty ? null : _cronCtrl.text.trim()) : null,
      steps: steps,
      template: _selectedTemplate?.key,
      createdAt: DateTime.now(),
    );
    await WorkflowStore.instance.add(config);
    _showSnack('工作流已保存');
    // reset basic fields but keep template selection
    setState(() {
      _nameCtrl.clear();
      _descCtrl.clear();
      if (_selectedTemplate == null) {
        _triggerType = 'manual';
        _cronCtrl.clear();
        _platforms
          ..clear()
          ..addAll(['macos', 'linux']);
        for (final c in _stepCtrls) c.dispose();
        _stepCtrls
          ..clear()
          ..add(TextEditingController());
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _Template {
  final String key;
  final String name;
  final String triggerType;
  final String? cron;
  final List<String> steps;
  final List<String> platforms;
  const _Template({
    required this.key,
    required this.name,
    required this.triggerType,
    this.cron,
    required this.steps,
    required this.platforms,
  });
}