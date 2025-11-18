import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';
import 'widgets/sdk_api_tree_view.dart';

class SdkApiSection extends StatefulWidget {
  final void Function(List<SdkApi> apis) onApisExtracted;

  const SdkApiSection({super.key, required this.onApisExtracted});

  @override
  State<SdkApiSection> createState() => _SdkApiSectionState();
}

class _SdkApiSectionState extends State<SdkApiSection> {
  final TextEditingController _sdkPathCtrl = TextEditingController(text: '');
  bool _loading = false;
  List<SdkApi> _apis = const [];
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
        const Text('第一步：提取 SDK 公开接口', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _sdkPathCtrl,
          decoration: InputDecoration(
            labelText: 'SDK 二进制路径（.aar 或 classes.jar）',
            hintText: '/absolute/path/to/sdk.aar 或 /path/to/classes.jar',
            helperText: '自动从 .aar 的 classes.jar 或直接从 classes.jar 提取方法接口',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _loading ? null : _extract,
              icon: _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.inventory_2),
              label: Text(_loading ? '提取中…' : '从二进制提取接口'),
            ),
            const SizedBox(width: 12),
            if (_apis.isNotEmpty)
              Text('已识别接口：${_apis.length} 个', style: TextStyle(color: muted)),
          ],
        ),
        const SizedBox(height: 12),
        if (_errors.isNotEmpty)
          Text('错误：\n${_errors.join('\n')}', style: const TextStyle(color: Colors.orange)),
        const SizedBox(height: 8),
        SdkApiTreeView(apis: _apis),
      ],
    );
  }

  Future<void> _extract() async {
    setState(() {
      _loading = true;
      _apis = const [];
      _errors = const [];
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      final apis = await analyzer.extractSdkApisFromBinary(
        sdkBinaryPath: _sdkPathCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() => _apis = apis);
      widget.onApisExtracted(apis);
    } catch (e) {
      setState(() => _errors = ['提取接口出现异常：$e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}