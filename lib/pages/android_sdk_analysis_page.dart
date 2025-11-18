import 'package:flutter/material.dart';
import 'abs/jarvis_page.dart';
import '../widgets/grid_background.dart';
import '../core/android_sdk_analyzer.dart';
import 'sections/sdk_usage_controls.dart';
import 'sections/widgets/sdk_api_tree_view.dart';
import 'sections/sdk_project_controls.dart';
import 'sections/sdk_dependency_controls.dart';

class AndroidSdkAnalysisPage extends JarvisPage {
  const AndroidSdkAnalysisPage({super.key})
      : super(
          isRoot: false,
          title: 'Android SDK 依赖分析',
          accent: const Color(0xFF0EA5E9),
        );

  @override
  List<Widget> background(BuildContext context) => const [GridBackground()];

  @override
  Widget content(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: _AndroidSdkAnalysisBody(),
    );
  }
}

class _AndroidSdkAnalysisBody extends StatefulWidget {
  const _AndroidSdkAnalysisBody();

  @override
  State<_AndroidSdkAnalysisBody> createState() => _AndroidSdkAnalysisBodyState();
}

class _AndroidSdkAnalysisBodyState extends State<_AndroidSdkAnalysisBody> {
  String _projectPath = '';
  List<ProjectDependency> _deps = const [];
  ProjectDependency? _selectedDep;

  List<SdkApi> _sdkApis = const [];
  SdkAnalysisResult? _usageResult;
  List<String> _usageErrors = const [];

  // 搜索过滤相关状态
  final TextEditingController _depFilterCtrl = TextEditingController(text: '');
  String _depFilter = '';

  // 依赖过滤逻辑
  List<ProjectDependency> _filteredDeps() {
    final q = _depFilter.trim().toLowerCase();
    if (q.isEmpty) return _deps;
    return _deps.where((d) {
      final id = '${d.group}:${d.module}:${d.version}'.toLowerCase();
      return id.contains(q) ||
          d.artifactPath.toLowerCase().contains(q) ||
          d.kind.toLowerCase().contains(q) ||
          d.module.toLowerCase().contains(q) ||
          d.group.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _depFilterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final controller = DefaultTabController.of(context);
              return AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final idx = controller.index;
                  final stepText = idx == 0 ? '第一步' : (idx == 1 ? '第二步' : '第三步');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(stepText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: controller.index > 0 ? () => controller.index = controller.index - 1 : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('上一步'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: controller.index < 2 ? () => controller.index = controller.index + 1 : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('下一步'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (idx == 0)
                        SdkProjectControls(
                          onDiscovered: (path, deps) => setState(() {
                            _projectPath = path;
                            _deps = deps;
                            _selectedDep = null;
                            _sdkApis = const [];
                            _usageResult = null;
                            _usageErrors = const [];
                            // 重置过滤框
                            _depFilter = '';
                            _depFilterCtrl.text = '';
                          }),
                        )
                      else if (idx == 1)
                        (_deps.isNotEmpty
                            ? SdkDependencyControls(
                                deps: _deps,
                                initialSelected: _selectedDep,
                                onSelected: (dep) => setState(() => _selectedDep = dep),
                                onApisExtracted: (apis) => setState(() => _sdkApis = apis),
                              )
                            : Text('请先完成第一步：选择项目并扫描依赖。', style: TextStyle(color: muted)))
                      else
                        (_sdkApis.isNotEmpty
                            ? SdkUsageControls(
                                sdkApis: _sdkApis,
                                initialProjectPath: _projectPath,
                                onResult: (res) => setState(() {
                                  _usageResult = res;
                                  _usageErrors = res.errors;
                                }),
                                onErrors: (errs) => setState(() => _usageErrors = errs),
                              )
                            : Text('请先在第二步选择依赖并提取接口。', style: TextStyle(color: muted))),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                // 第一步：依赖列表（源自 Gradle 缓存解析）
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: (_deps.isEmpty
                        ? Text('尚未发现依赖，请在上方输入项目路径并点击“扫描”。', style: TextStyle(color: muted))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _depFilterCtrl,
                                decoration: InputDecoration(
                                  labelText: '过滤依赖',
                                  hintText: '输入 group/name/version 或路径关键字',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onChanged: (v) => setState(() => _depFilter = v),
                              ),
                              const SizedBox(height: 8),
                              Builder(builder: (context) {
                                final filtered = _filteredDeps();
                                if (filtered.isEmpty) {
                                  return Text('无匹配项，请调整过滤关键词。', style: TextStyle(color: muted));
                                }
                                return ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 0.5, color: Color(0x22FFFFFF)),
                                  itemBuilder: (context, i) {
                                    final d = filtered[i];
                                    return ListTile(
                                      dense: true,
                                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                                      title: Text('${d.group}:${d.module}:${d.version} · ${d.kind}'),
                                      subtitle: Text(d.artifactPath, style: TextStyle(color: muted)),
                                      trailing: (_selectedDep?.artifactPath == d.artifactPath)
                                          ? const Icon(Icons.check_circle, size: 16, color: Colors.green)
                                          : null,
                                      onTap: () {
                                        DefaultTabController.of(context).index = 1;
                                        setState(() => _selectedDep = d);
                                      },
                                    );
                                  },
                                );
                              }),
                            ],
                          )),
                  ),
                ),
                // 第二步：接口树
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: (_sdkApis.isNotEmpty
                        ? SdkApiTreeView(apis: _sdkApis)
                        : Text('请选择依赖（自动提取接口后在此展示）。', style: TextStyle(color: muted))),
                  ),
                ),
                // 第三步：调用点树
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: (_sdkApis.isNotEmpty
                        ? (_usageResult != null
                            ? SdkApiTreeView(apis: _sdkApis, usages: _usageResult!.usages)
                            : Text('请输入项目路径并点击“确认”，随后在此展示调用点。', style: TextStyle(color: muted)))
                        : Text('请先在第二步提取接口。', style: TextStyle(color: muted))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}