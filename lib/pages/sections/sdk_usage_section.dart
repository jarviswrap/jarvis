import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';
import 'widgets/sdk_api_tree_view.dart';

class SdkUsageSection extends StatefulWidget {
  final List<SdkApi> sdkApis;

  const SdkUsageSection({super.key, required this.sdkApis});

  @override
  State<SdkUsageSection> createState() => _SdkUsageSectionState();
}

class _SdkUsageSectionState extends State<SdkUsageSection> {
  final TextEditingController _projPathCtrl = TextEditingController(text: '');
  bool _loading = false;
  SdkAnalysisResult? _result;
  List<String> _errors = const [];

  @override
  void dispose() {
    _projPathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final apisReady = widget.sdkApis.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('第二步：确认项目调用点', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (!apisReady)
          Text('请先完成第一步的接口提取，完成后此区域将解锁展示。', style: TextStyle(color: muted))
        else ...[
          TextField(
            controller: _projPathCtrl,
            decoration: InputDecoration(
              labelText: 'Android 项目路径',
              hintText: '/absolute/path/to/project',
              helperText: '示例：/Volumes/exssd/catchii_android',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _confirm,
                icon: _loading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow),
                label: Text(_loading ? '扫描中…' : '确认调用点'),
              ),
              const SizedBox(width: 12),
              if (_result != null)
                Text('调用点：${_result!.callSiteCount} 处', style: TextStyle(color: muted)),
          ],
        ),
        const SizedBox(height: 12),
        // 可复用的接口展示区域（显示来自第一步的已提取接口）
        ExpansionTile(
          initiallyExpanded: false,
          title: const Text('已提取的接口（来自第一步）'),
          subtitle: Text('接口数：${widget.sdkApis.length}', style: TextStyle(color: muted)),
          children: [
            SdkApiTreeView(apis: widget.sdkApis, padding: const EdgeInsets.only(bottom: 8)),
          ],
        ),
        const SizedBox(height: 12),
        if (_errors.isNotEmpty)
          Text('错误：\n${_errors.join('\n')}', style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 8),
          if (_result != null) _buildUsages(_result!, muted) else Text('尚未执行分析。', style: TextStyle(color: muted)),
        ],
      ],
    );
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _errors = const [];
      _result = null;
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final res = await analyzer.confirmUsages(
        projectPath: _projPathCtrl.text.trim(),
        sdkApis: widget.sdkApis,
      );
      if (!mounted) return;
      setState(() {
        _result = res;
        _errors = res.errors;
      });
    } catch (e) {
      setState(() => _errors = ['分析过程中出现异常：$e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildUsages(SdkAnalysisResult result, Color muted) {
    // 将被调用的 SDK API 与具体调用点一起分组：模块 -> 类 -> 方法

    final byModule = <String, Map<String, Map<String, List<_CallHit>>>>{};
    result.usages.forEach((api, sites) {
      for (final site in sites) {
        final mod = _moduleName(site.filePath);
        final cls = _callerClassName(site.filePath);
        final mth = _callerMethodName(site.filePath, site.line);
        byModule.putIfAbsent(mod, () => {});
        byModule[mod]!.putIfAbsent(cls, () => {});
        (byModule[mod]![cls]![mth] ??= []).add(_CallHit(api, site));
      }
    });

    final modules = byModule.keys.toList()..sort();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0x1FFFFFFF), height: 1),
      itemBuilder: (context, i) {
        final mod = modules[i];
        final classes = byModule[mod]!.keys.toList()..sort();
        return ExpansionTile(
          title: Text('模块：$mod', style: const TextStyle(fontWeight: FontWeight.w600)),
          children: [
            for (final cls in classes)
              ExpansionTile(
                title: Text(cls),
                children: [
                  for (final mth in (byModule[mod]![cls]!.keys.toList()..sort()))
                    ExpansionTile(
                      title: Text(mth),
                      children: [
                        for (final hit in byModule[mod]![cls]![mth]!)
                          ListTile(
                            title: Text('${hit.api.package}.${hit.api.className}#${hit.api.methodName}'),
                            subtitle: Text(
                              '${hit.site.filePath}:${hit.site.line}\n${hit.site.lineText}',
                              style: TextStyle(color: muted),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  String _moduleName(String filePath) {
    try {
      final parts = filePath.split(Platform.pathSeparator);
      final idx = parts.indexOf('src');
      if (idx > 0) return parts[idx - 1];
      return parts.length > 1 ? parts[1] : 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  String _callerClassName(String filePath) {
    final name = filePath.split(Platform.pathSeparator).last;
    return name.replaceAll('.kt', '').replaceAll('.java', '');
  }

  String _callerMethodName(String filePath, int callLine) {
    try {
      final lines = File(filePath).readAsLinesSync();
      for (int i = callLine - 1; i >= 0 && i >= callLine - 80; i--) {
        final l = lines[i].trim();
        if (RegExp(r'^(public|protected|private)?\s*(static\s+)?[\w<>,\[\]]+\s+\w+\s*\(').hasMatch(l)) {
          final m = RegExp(r'(\w+)\s*\(').firstMatch(l);
          if (m != null) return m.group(1)!;
        }
        if (RegExp(r'^(fun)\s+\w+\s*\(').hasMatch(l)) {
          final m = RegExp(r'fun\s+(\w+)\s*\(').firstMatch(l);
          if (m != null) return m.group(1)!;
        }
      }
    } catch (_) {}
    return 'unknownMethod';
  }
}

class _CallHit {
  final SdkApi api;
  final CallSite site;
  const _CallHit(this.api, this.site);
}