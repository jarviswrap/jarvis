import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';

class SdkDependencyControls extends StatefulWidget {
  final List<ProjectDependency> deps;
  final ProjectDependency? initialSelected;
  final void Function(ProjectDependency dep)? onSelected;
  final void Function(List<SdkApi> apis) onApisExtracted;

  const SdkDependencyControls({
    super.key,
    required this.deps,
    this.initialSelected,
    this.onSelected,
    required this.onApisExtracted,
  });

  @override
  State<SdkDependencyControls> createState() => _SdkDependencyControlsState();
}

class _SdkDependencyControlsState extends State<SdkDependencyControls> {
  ProjectDependency? _selected;
  bool _loading = false;
  List<String> _errors = const [];
  final TextEditingController _artifactCtrl = TextEditingController(text: '');
  String? _autoExtractedArtifact; // 防止重复自动提取

  @override
  void initState() {
    super.initState();
    // 延后到首帧后进行自动填充与自动提取，避免构建期间 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialSelected == null) return;
      final dep = widget.initialSelected!;
      setState(() {
        _selected = dep;
        _artifactCtrl.text = dep.artifactPath;
        _errors = const [];
      });
      if (_autoExtractedArtifact != dep.artifactPath) {
        _autoExtractedArtifact = dep.artifactPath;
        _extract(dep);
        widget.onSelected?.call(dep);
      }
    });
  }

  @override
  void didUpdateWidget(covariant SdkDependencyControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当第一步选择变化时，第二步自动跟随填充与提取
    if (widget.initialSelected?.artifactPath != oldWidget.initialSelected?.artifactPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.initialSelected == null) return;
        final dep = widget.initialSelected!;
        setState(() {
          _selected = dep;
          _artifactCtrl.text = dep.artifactPath;
          _errors = const [];
        });
        _autoExtractedArtifact = dep.artifactPath;
        _extract(dep);
        widget.onSelected?.call(dep);
      });
    }
  }

  @override
  void dispose() {
    _artifactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<ProjectDependency>(
            items: [
              for (final d in widget.deps)
                DropdownMenuItem<ProjectDependency>(
                  value: d,
                  child: Text('${d.group}:${d.module}:${d.version} · ${d.kind}'),
                ),
            ],
            value: _selected,
            decoration: InputDecoration(
              labelText: '选择依赖（自动提取接口）',
              hintText: '从 aar 或 jar 自动解析公开方法',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              // 将路径作为辅助文字显示，避免第二个输入框
              helperText: _selected?.artifactPath ?? '',
              helperMaxLines: 2,
            ),
            onChanged: (dep) async {
              setState(() {
                _selected = dep;
                _errors = const [];
              });
              if (dep != null) {
                _artifactCtrl.text = dep.artifactPath;
                _autoExtractedArtifact = null; // 手动选择时重置自动提取标记
                widget.onSelected?.call(dep);
                await _extract(dep);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        if (_loading)
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }

  Future<void> _extract(ProjectDependency dep) async {
    setState(() {
      _loading = true;
      _errors = const [];
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final apis = await analyzer.extractSdkApisFromBinary(sdkBinaryPath: dep.artifactPath);
      if (!mounted) return;
      widget.onApisExtracted(apis);
    } catch (e) {
      setState(() => _errors = ['提取接口时出现异常：$e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}