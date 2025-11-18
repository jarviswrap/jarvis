import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';

class SdkUsageControls extends StatefulWidget {
  final List<SdkApi> sdkApis;
  final void Function(SdkAnalysisResult result) onResult;
  final void Function(List<String> errors)? onErrors;
  final String? initialProjectPath; // 新增：预填项目路径

  const SdkUsageControls({
    super.key,
    required this.sdkApis,
    required this.onResult,
    this.onErrors,
    this.initialProjectPath,
  });

  @override
  State<SdkUsageControls> createState() => _SdkUsageControlsState();
}

class _SdkUsageControlsState extends State<SdkUsageControls> {
  final TextEditingController _projPathCtrl = TextEditingController(text: '');
  bool _loading = false;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部步骤标题在主页面展示，此处不再重复显示
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _projPathCtrl,
                decoration: InputDecoration(
                  labelText: 'Android 项目路径',
                  // 将示例文案作为 hint 展示，并移除 helperText
                  hintText: '示例：/Volumes/exssd/catchii_android',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _confirm,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              // 简化按钮文案
              label: Text(_loading ? '扫描中…' : '确认'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_errors.isNotEmpty)
          Text('错误：\n${_errors.join('\n')}', style: const TextStyle(color: Colors.orange)),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialProjectPath != null && widget.initialProjectPath!.isNotEmpty) {
      _projPathCtrl.text = widget.initialProjectPath!;
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _errors = const [];
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final res = await analyzer.confirmUsages(
        projectPath: _projPathCtrl.text.trim(),
        sdkApis: widget.sdkApis,
      );
      if (!mounted) return;
      widget.onResult(res);
      if (widget.onErrors != null) widget.onErrors!(res.errors);
    } catch (e) {
      setState(() => _errors = ['分析过程中出现异常：$e']);
      if (widget.onErrors != null) widget.onErrors!(_errors);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}