import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';

class SdkApiControls extends StatefulWidget {
  final void Function(List<SdkApi> apis) onApisExtracted;

  const SdkApiControls({super.key, required this.onApisExtracted});

  @override
  State<SdkApiControls> createState() => _SdkApiControlsState();
}

class _SdkApiControlsState extends State<SdkApiControls> {
  final TextEditingController _sdkPathCtrl = TextEditingController(text: '');
  bool _loading = false;
  List<String> _errors = const [];

  @override
  void dispose() {
    _sdkPathCtrl.dispose();
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
                controller: _sdkPathCtrl,
                decoration: InputDecoration(
                  labelText: 'SDK 二进制路径（.aar 或 classes.jar）',
                  // 将原 helper 文案改为 hint，并移除 helperText
                  hintText: '自动从 .aar 的 classes.jar 或直接从 classes.jar 提取方法接口',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _extract,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.inventory_2),
              // 简化按钮文案
              label: Text(_loading ? '提取中…' : '提取'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_errors.isNotEmpty)
          Text('错误：\n${_errors.join('\n')}', style: const TextStyle(color: Colors.orange)),
      ],
    );
  }

  Future<void> _extract() async {
    setState(() {
      _loading = true;
      _errors = const [];
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final apis = await analyzer.extractSdkApisFromBinary(
        sdkBinaryPath: _sdkPathCtrl.text.trim(),
      );
      if (!mounted) return;
      widget.onApisExtracted(apis);
    } catch (e) {
      setState(() => _errors = ['提取接口出现异常：$e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}