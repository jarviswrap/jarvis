import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:jarvis/core/utils/app_text_styles.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class FilePickerDialog extends StatefulWidget {
  final String title;
  final String initialPath;
  final bool isDirectory;
  final List<String>? allowedExtensions;

  const FilePickerDialog({
    super.key,
    required this.title,
    this.initialPath = '',
    this.isDirectory = false,
    this.allowedExtensions,
  });

  @override
  State<FilePickerDialog> createState() => _FilePickerDialogState();

  /// 显示文件选择对话框
  static Future<String?> pickFile({
    required BuildContext context,
    String title = '选择文件',
    String initialPath = '',
    List<String>? allowedExtensions,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => FilePickerDialog(
        title: title,
        initialPath: initialPath,
        isDirectory: false,
        allowedExtensions: allowedExtensions,
      ),
    );
  }

  /// 显示目录选择对话框
  static Future<String?> pickDirectory({
    required BuildContext context,
    String title = '选择目录',
    String initialPath = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => FilePickerDialog(
        title: title,
        initialPath: initialPath,
        isDirectory: true,
      ),
    );
  }

  /// 直接调用系统文件选择器（内部使用）
  static Future<String?> _pickFileSystem({
    String dialogTitle = '选择文件',
    List<String>? allowedExtensions,
    String? initialDirectory,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        initialDirectory: initialDirectory,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }
    } catch (e) {
      debugPrint('文件选择错误: $e');
    }
    return null;
  }

  /// 直接调用系统目录选择器（内部使用）
  static Future<String?> _pickDirectorySystem({
    String dialogTitle = '选择目录',
    String? initialDirectory,
  }) async {
    try {
      String? result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
      );
      return result;
    } catch (e) {
      debugPrint('目录选择错误: $e');
    }
    return null;
  }
}

class _FilePickerDialogState extends State<FilePickerDialog> with TickerProviderStateMixin {
  late TextEditingController _pathController;
  late TextEditingController _baseDirectoryController;
  late TextEditingController _searchController;
  late TabController _tabController;
  
  bool _isLoading = false;
  bool _isSearching = false;
  List<FileSystemEntity> _searchResults = [];
  String? _selectedSearchResult;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController(text: widget.initialPath);
    _baseDirectoryController = TextEditingController();
    _searchController = TextEditingController();
    _tabController = TabController(length: widget.isDirectory ? 2 : 3, vsync: this);
    
    // 添加监听器来实时更新按钮状态
    _baseDirectoryController.addListener(() {
      setState(() {});
    });
    _searchController.addListener(() {
      setState(() {});
    });
    
    // 如果有初始路径，尝试分解为基础目录
    if (widget.initialPath.isNotEmpty) {
      _baseDirectoryController.text = path.dirname(widget.initialPath);
      if (!widget.isDirectory) {
        _searchController.text = path.basename(widget.initialPath);
      }
    }
  }

  Future<void> _openSystemPicker() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? selectedPath;
      
      if (widget.isDirectory) {
        selectedPath = await FilePickerDialog._pickDirectorySystem(
          dialogTitle: widget.title,
          initialDirectory: _getInitialDirectory(),
        );
      } else {
        selectedPath = await FilePickerDialog._pickFileSystem(
          dialogTitle: widget.title,
          allowedExtensions: widget.allowedExtensions,
          initialDirectory: _getInitialDirectory(),
        );
      }

      if (selectedPath != null) {
        _pathController.text = selectedPath;
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectBaseDirectory() async {
    final result = await FilePickerDialog._pickDirectorySystem(
      dialogTitle: '选择基础目录',
      initialDirectory: _baseDirectoryController.text.isNotEmpty 
          ? _baseDirectoryController.text 
          : null,
    );
    
    if (result != null) {
      setState(() {
        _baseDirectoryController.text = result;
      });
    }
  }

  Future<void> _searchFiles() async {
    final baseDir = _baseDirectoryController.text.trim();
    final searchName = _searchController.text.trim();
    
    if (baseDir.isEmpty || searchName.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _selectedSearchResult = null;
    });

    try {
      final directory = Directory(baseDir);
      if (!directory.existsSync()) {
        _showSnackBar('基础目录不存在');
        return;
      }

      final results = <FileSystemEntity>[];
      
      await for (final entity in directory.list(recursive: true, followLinks: false)) {
        try {
          final entityName = path.basename(entity.path);
          
          // 检查文件名是否匹配搜索条件
          bool matches = false;
          if (entityName.toLowerCase().contains(searchName.toLowerCase())) {
            matches = true;
          }
          
          if (matches) {
            if (widget.isDirectory && entity is Directory) {
              results.add(entity);
            } else if (!widget.isDirectory && entity is File) {
              // 检查文件扩展名
              if (widget.allowedExtensions != null) {
                final extension = path.extension(entityName).toLowerCase();
                if (extension.isNotEmpty && 
                    widget.allowedExtensions!.any((ext) => 
                        extension == '.${ext.toLowerCase()}')) {
                  results.add(entity);
                }
              } else {
                results.add(entity);
              }
            }
          }
          
          // 限制结果数量以避免性能问题
          if (results.length >= 100) {
            break;
          }
        } catch (e) {
          // 忽略无法访问的文件/目录
          continue;
        }
      }

      setState(() {
        _searchResults = results;
      });

      if (results.isEmpty) {
        _showSnackBar('未找到匹配的${widget.isDirectory ? '目录' : '文件'}');
      }
    } catch (e) {
      _showSnackBar('搜索过程中发生错误: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _getInitialDirectory() {
    if (_pathController.text.isNotEmpty) {
      try {
        if (widget.isDirectory) {
          return Directory(_pathController.text).existsSync() 
              ? _pathController.text 
              : path.dirname(_pathController.text);
        } else {
          return File(_pathController.text).existsSync()
              ? path.dirname(_pathController.text)
              : path.dirname(_pathController.text);
        }
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  bool _validatePath() {
    final pathText = _pathController.text.trim();
    if (pathText.isEmpty) return false;

    try {
      if (widget.isDirectory) {
        return Directory(pathText).existsSync();
      } else {
        return File(pathText).existsSync();
      }
    } catch (e) {
      return false;
    }
  }

  Widget _buildDirectInputTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _pathController,
                  // 移除 style，使用主题中的 textTheme.bodyMedium
                  decoration: AppTextStyles.getInputDecoration(
                    widget.isDirectory ? '目录路径' : '文件路径',
                    widget.isDirectory 
                        ? '/Users/username/projects' 
                        : '/usr/local/bin/myapp',
                    onTap: _pathController.text.isNotEmpty? () {
                          setState(() {
                            _pathController.clear();
                          });
                    }: null,
                  ),
                  maxLines: 1,
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _openSystemPicker,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        widget.isDirectory ? Icons.folder_open : Icons.file_open,
                        // 移除 size，使用主题中的 iconSize
                      ),
                label: const Text('浏览'), // 移除 style，使用主题中的 textStyle
                // 移除 style，使用主题中的 elevatedButtonTheme
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildValidationInfo(),
        ],
      ),
    );
  }

  Widget _buildSmartSearchTab() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 基础目录选择
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _baseDirectoryController,
                  // 移除所有样式配置，使用主题
                  decoration: AppTextStyles.getInputDecoration(
                    '基础目录',
                    '/Users/username/projects'),
                  readOnly: true,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectBaseDirectory,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择'),
                // 移除 style，使用主题配置
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // 搜索名称输入
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _searchController,
                  // 移除所有样式配置，使用主题
                  decoration: AppTextStyles.getInputDecoration(
                    widget.isDirectory ? '目录名称' : '文件名称',
                    widget.isDirectory ? 'myproject' : 'myapp.so',
                  ),
                  onFieldSubmitted: (_) {
                    if (_baseDirectoryController.text.isNotEmpty && 
                        _searchController.text.isNotEmpty && 
                        !_isSearching) {
                      _searchFiles();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (_baseDirectoryController.text.isNotEmpty && 
                           _searchController.text.isNotEmpty && 
                           !_isSearching) 
                    ? _searchFiles 
                    : null,
                icon: _isSearching 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: const Text('搜索'),
                // 移除 style，使用主题配置
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 搜索结果
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '搜索结果 (${_searchResults.length} 项)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: const EdgeInsets.all(4),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final entity = _searchResults[index];
                  final isSelected = _selectedSearchResult == entity.path;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.shade50 : null,
                      borderRadius: BorderRadius.circular(4),
                      border: isSelected ? Border.all(color: Colors.blue.shade200) : null,
                    ),
                    child: ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Icon(
                        entity is Directory ? Icons.folder : Icons.insert_drive_file,
                        size: 18,
                        color: isSelected ? Colors.blue : Colors.grey.shade600,
                      ),
                      title: Text(
                        path.basename(entity.path),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? Colors.blue.shade700 : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        path.dirname(entity.path),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 10
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedSearchResult = entity.path;
                          _pathController.text = entity.path;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    } else if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在搜索...',
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    } else if (_baseDirectoryController.text.isNotEmpty && 
               _searchController.text.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search,
                size: 48,
                color: Colors.blue.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                '点击"搜索"按钮开始查找${widget.isDirectory ? '目录' : '文件'}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                '请先选择基础目录并输入${widget.isDirectory ? '目录' : '文件'}名称',
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildValidationInfo() {
    final pathText = _pathController.text.trim();
    final isValid = _validatePath();
    
    Color color;
    IconData icon;
    String message;
    
    if (pathText.isEmpty) {
      color = Colors.grey.shade600;
      icon = Icons.info_outline;
      message = widget.isDirectory 
          ? '请输入目录路径或使用其他方式选择' 
          : '请输入文件路径或使用其他方式选择';
    } else if (isValid) {
      color = Colors.green;
      icon = Icons.check_circle_outline;
      message = widget.isDirectory ? '目录存在' : '文件存在';
    } else {
      color = Colors.red;
      icon = Icons.error_outline;
      message = widget.isDirectory ? '目录不存在或路径无效' : '文件不存在或路径无效';
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8), // 减少底部内边距
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.65, // 稍微增加高度
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(text: '直接输入'),
                if (!widget.isDirectory) const Tab(text: '智能搜索'),
                const Tab(text: '系统浏览'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDirectInputTab(),
                  if (!widget.isDirectory) _buildSmartSearchTab(),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _openSystemPicker,
                      icon: _isLoading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              widget.isDirectory ? Icons.folder_open : Icons.file_open,
                            ),
                      label: Text('打开${widget.isDirectory ? '目录' : '文件'}选择器'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16), // 减少actions的上边距
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final pathText = _pathController.text.trim();
            if (pathText.isNotEmpty) {
              Navigator.pop(context, pathText);
            }
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pathController.dispose();
    _baseDirectoryController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}