import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../utils/app_text_styles.dart';
import '../plugin_system/plugin_manager.dart';
import '../plugin_system/plugin_models.dart';

class PluginExportDialog extends StatefulWidget {
  final PluginConfig pluginConfig;

  const PluginExportDialog({
    super.key,
    required this.pluginConfig,
  });

  @override
  State<PluginExportDialog> createState() => _PluginExportDialogState();

  /// 显示插件导出对话框
  static Future<void> show({
    required BuildContext context,
    required PluginConfig pluginConfig,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => PluginExportDialog(
        pluginConfig: pluginConfig,
      ),
    );
  }
}

class _PluginExportDialogState extends State<PluginExportDialog> {
  late TextEditingController _fileNameController;
  late TextEditingController _savePathController;
  String _yamlContent = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fileNameController = TextEditingController(
      text: '${widget.pluginConfig.name.replaceAll(' ', '_')}.yaml'
    );
    _savePathController = TextEditingController();
    _generateYamlContent();
  }

  @override
  void dispose() {
    _fileNameController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  void _generateYamlContent() {
    final pluginManager = PluginManager();
    _yamlContent = pluginManager.exportPluginConfigAsYaml(widget.pluginConfig.id);
    setState(() {});
  }

  Future<void> _selectSavePath() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );
      
      if (selectedDirectory != null) {
        setState(() {
          _savePathController.text = selectedDirectory;
        });
      }
    } catch (e) {
      _showErrorSnackBar('选择路径失败: $e');
    }
  }

  Future<void> _saveToFile() async {
    if (_savePathController.text.isEmpty) {
      _showErrorSnackBar('请选择保存路径');
      return;
    }

    if (_fileNameController.text.isEmpty) {
      _showErrorSnackBar('请输入文件名');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final fileName = _fileNameController.text;
      final savePath = _savePathController.text;
      final fullPath = '$savePath/$fileName';
      
      final file = File(fullPath);
      await file.writeAsString(_yamlContent);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('插件已导出到: $fullPath'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('保存文件失败: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    try {
      await Clipboard.setData(ClipboardData(text: _yamlContent));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('YAML内容已复制到剪贴板'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('复制失败: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏 - 更紧凑
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  color: Colors.cyan.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '导出插件配置 - ${widget.pluginConfig.name}',
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // YAML内容预览 - 作为主题，占据大部分空间
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // 预览工具栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.code, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'YAML配置预览',
                            style: AppTextStyles.sectionTitle.copyWith(fontSize: 14),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('复制', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 内容区域
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _yamlContent,
                          style: AppTextStyles.code.copyWith(
                            backgroundColor: Colors.transparent,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 紧凑的文件配置区域
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '保存配置',
                    style: AppTextStyles.sectionTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  
                  // 文件名和路径 - 紧凑布局
                  Row(
                    children: [
                      // 文件名
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '文件名',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 32,
                              child: TextFormField(
                                controller: _fileNameController,
                                style: const TextStyle(fontSize: 12),
                                decoration: AppTextStyles.getInputDecoration(
                                  '',
                                  '文件名',
                                ).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // 保存路径
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '保存路径',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.grey.shade600,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 32,
                                    child: TextFormField(
                                      controller: _savePathController,
                                      style: const TextStyle(fontSize: 12),
                                      decoration: AppTextStyles.getInputDecoration(
                                        '',
                                        '选择路径',
                                      ).copyWith(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        isDense: true,
                                      ),
                                      readOnly: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  height: 32,
                                  child: ElevatedButton(
                                    onPressed: _selectSavePath,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyan.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(60, 32),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('选择', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveToFile,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save, size: 18),
                  label: Text(_isLoading ? '保存中...' : '保存文件'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}