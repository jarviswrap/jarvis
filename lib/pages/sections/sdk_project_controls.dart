import 'package:flutter/material.dart';
import '../../core/android_sdk_analyzer.dart';

class SdkProjectControls extends StatefulWidget {
  final void Function(String projectPath, List<ProjectDependency> deps) onDiscovered;

  const SdkProjectControls({super.key, required this.onDiscovered});

  @override
  State<SdkProjectControls> createState() => _SdkProjectControlsState();
}

class _SdkProjectControlsState extends State<SdkProjectControls> {
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _projPathCtrl,
            decoration: InputDecoration(
              labelText: 'Android 项目路径',
              hintText: '示例：/Volumes/exssd/catchii_android',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: _loading ? null : _scan,
          icon: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: Text(_loading ? '扫描中…' : '扫描'),
        ),
      ],
    );
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _errors = const [];
    });
    try {
      final analyzer = AndroidSdkAnalyzer();
      // 使用新的 Gradle 缓存解析方法
      final deps = await analyzer.discoverDependenciesFromGradle(projectPath: _projPathCtrl.text.trim());
      if (!mounted) return;
      widget.onDiscovered(_projPathCtrl.text.trim(), deps);
    } catch (e) {
      setState(() => _errors = ['扫描依赖时出现异常：$e']);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}