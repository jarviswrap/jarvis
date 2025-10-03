import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../utils/app_text_styles.dart';
import '../plugin_system/plugin_manager.dart';
import '../plugin_system/plugin_models.dart';

enum ImportFormat {
  yaml('YAML', ['yaml', 'yml'], Icons.description),
  json('JSON', ['json'], Icons.code);

  const ImportFormat(this.displayName, this.extensions, this.icon);
  
  final String displayName;
  final List<String> extensions;
  final IconData icon;
}

enum ImportSource {
  file('从文件导入', Icons.file_upload),
  clipboard('从剪贴板导入', Icons.content_paste);

  const ImportSource(this.displayName, this.icon);
  
  final String displayName;
  final IconData icon;
}

class PluginImportDialog extends StatefulWidget {
  final bool parseOnly; // 新增：是否只解析不保存

  const PluginImportDialog({
    super.key,
    this.parseOnly = false,
  });

  @override
  State<PluginImportDialog> createState() => _PluginImportDialogState();

  /// 显示插件导入对话框
  static Future<bool?> show({
    required BuildContext context,
    bool parseOnly = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => PluginImportDialog(parseOnly: parseOnly),
    );
  }

  /// 显示插件导入对话框并返回解析的配置
  static Future<PluginConfig?> showForParsing({
    required BuildContext context,
  }) {
    return showDialog<PluginConfig>(
      context: context,
      builder: (context) => const PluginImportDialog(parseOnly: true),
    );
  }
}

class _PluginImportDialogState extends State<PluginImportDialog> {
  ImportFormat _selectedFormat = ImportFormat.yaml;
  ImportSource _selectedSource = ImportSource.file;
  late TextEditingController _contentController;
  late TextEditingController _filePathController;
  String _previewContent = '';
  bool _isLoading = false;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _filePathController = TextEditingController();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _filePathController.dispose();
    super.dispose();
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
            // 标题栏
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  size: 24,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  '导入插件配置',
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 简洁的导入配置区域
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // 第一行：导入源和文件格式选择
                  Row(
                    children: [
                      // 导入源选择 - 紧凑型
                      Expanded(
                        child: Row(
                          children: ImportSource.values.map((source) {
                            final isSelected = _selectedSource == source;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: source == ImportSource.file ? 6 : 0,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedSource = source;
                                      _previewContent = '';
                                      _showPreview = false;
                                      _contentController.clear();
                                      _filePathController.clear();
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue.shade600
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: isSelected
                                          ? Colors.blue.shade50
                                          : Colors.transparent,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          source.icon,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.blue.shade600
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          source == ImportSource.file ? '文件' : '剪贴板',
                                          style: TextStyle(
                                            fontSize: AppTextStyles.fontSizeNormal,
                                            color: isSelected
                                                ? Colors.blue.shade600
                                                : Colors.grey.shade700,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      
                      Container(
                        width: 1,
                        height: 25,
                        color: Colors.grey.shade300,
                        margin: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      
                      // 文件格式选择 - 紧凑型
                      Expanded(
                        child: Row(
                          children: ImportFormat.values.map((format) {
                            final isSelected = _selectedFormat == format;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: format == ImportFormat.yaml ? 6 : 0,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedFormat = format;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    height: 32,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.orange.shade600
                                            : Colors.grey.shade300,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      color: isSelected
                                          ? Colors.orange.shade50
                                          : Colors.transparent,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          format.icon,
                                          size: 14,
                                          color: isSelected
                                              ? Colors.orange.shade600
                                              : Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          format.displayName,
                                          style: TextStyle(
                                            fontSize: AppTextStyles.fontSizeNormal,
                                            color: isSelected
                                                ? Colors.orange.shade600
                                                : Colors.grey.shade700,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                  
                  // 第二行：文件选择 - 仅在文件导入时显示
                  if (_selectedSource == ImportSource.file) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextFormField(
                              controller: _filePathController,
                              decoration: AppTextStyles.getInputDecoration(
                                '选择文件',
                                '请选择要导入的配置文件',
                              ),
                              readOnly: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 32,
                          child: ElevatedButton(
                            onPressed: _selectFile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(50, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Text('选择', style: TextStyle(fontSize: AppTextStyles.fontSizeNormal)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 文件预览/内容输入区域 - 作为主题，占据大部分空间
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
                          Icon(
                            _selectedSource == ImportSource.file ? Icons.preview : Icons.edit,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedSource == ImportSource.file 
                                ? (_showPreview ? '文件预览' : '请选择文件')
                                : '配置内容',
                            style: AppTextStyles.sectionTitle.copyWith(fontSize: 14),
                          ),
                          const Spacer(),
                          if (_selectedSource == ImportSource.clipboard)
                            TextButton.icon(
                              onPressed: _pasteFromClipboard,
                              icon: const Icon(Icons.content_paste, size: 16),
                              label: const Text('粘贴', style: TextStyle(fontSize: 12)),
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
                      child: _selectedSource == ImportSource.file
                          ? _buildFilePreviewContent()
                          : _buildClipboardInputContent(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _importPlugin,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download, size: 18),
                  label: Text(_isLoading ? '导入中...' : '导入'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
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

  Widget _buildFilePreviewContent() {
    if (!_showPreview) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.file_upload,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '请选择要导入的 ${_selectedFormat.displayName} 文件',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '支持的文件格式: ${_selectedFormat.extensions.join(', ')}',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        _previewContent,
        style: AppTextStyles.code.copyWith(
          backgroundColor: Colors.transparent,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildClipboardInputContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextFormField(
        controller: _contentController,
        decoration: AppTextStyles.getInputDecoration(
          '',
          '请粘贴 ${_selectedFormat.displayName} 格式的插件配置内容',
        ).copyWith(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: AppTextStyles.code.copyWith(
          backgroundColor: Colors.transparent,
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: '选择要导入的文件',
        type: FileType.custom,
        allowedExtensions: _selectedFormat.extensions,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        
        if (await file.exists()) {
          final content = await file.readAsString();
          // 添加 mounted 检查
          if (mounted) {
            setState(() {
              _filePathController.text = filePath.split('/').last; // 只显示文件名
              _previewContent = content;
              _showPreview = true;
            });
          }
        }
      }
    } catch (e) {
      // 添加 mounted 检查
      if (mounted) {
        _showErrorSnackBar('选择文件失败: $e');
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        // 添加 mounted 检查
        if (mounted) {
          setState(() {
            _contentController.text = clipboardData!.text!;
          });
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('剪贴板为空');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('读取剪贴板失败: $e');
      }
    }
  }

  Future<void> _importPlugin() async {
    String content = '';
    
    if (_selectedSource == ImportSource.file) {
      if (_filePathController.text.isEmpty) {
        if (mounted) {
          _showErrorSnackBar('请选择要导入的文件');
        }
        return;
      }
      content = _previewContent;
    } else {
      if (_contentController.text.trim().isEmpty) {
        if (mounted) {
          _showErrorSnackBar('请输入要导入的内容');
        }
        return;
      }
      content = _contentController.text.trim();
    }

    // 添加 mounted 检查
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final pluginManager = PluginManager();
      
      if (widget.parseOnly) {
        // 只解析，不保存
        PluginConfig config;
        if (_selectedFormat == ImportFormat.json) {
          config = pluginManager.parsePluginConfigFromJson(content);
        } else {
          config = pluginManager.parsePluginConfigFromYaml(content);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('插件配置解析成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, config);
        }
      } else {
        // 解析并保存
        if (_selectedFormat == ImportFormat.json) {
          await pluginManager.importPluginConfig(content);
        } else {
          await pluginManager.importPluginConfigFromYaml(content);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('插件配置导入成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('${widget.parseOnly ? '解析' : '导入'}失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}