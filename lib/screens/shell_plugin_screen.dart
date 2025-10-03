import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/plugin_system/shell_plugin.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/widgets/file_picker_dialog.dart';
import '../core/utils/app_text_styles.dart';
import '../core/utils/app_layout_config.dart';
import '../core/widgets/regex_picker_dialog.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/widgets/plugin_export_dialog.dart';
import '../core/widgets/collapsible_section.dart';
import '../core/widgets/app_section_card.dart';

class ShellPluginScreen extends StatefulWidget {
  final ShellPlugin plugin;

  const ShellPluginScreen({super.key, required this.plugin});

  @override
  State<ShellPluginScreen> createState() => _ShellPluginScreenState();
}

class _ShellPluginScreenState extends State<ShellPluginScreen> {
  bool _isExecuting = false;
  final Map<String, dynamic> _parameterValues = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _regexValidationStates = {}; // 添加正则表达式验证状态管理
  final Map<String, String> _originalTexts = {}; // 添加存储原始文本的Map
  final _formKey = GlobalKey<FormState>();
  bool _isParameterSectionExpanded = true; // 添加参数区域展开状态控制
  
  // 参数概要文本
  String get _parameterSummaryText {
    final parameters = widget.plugin.config.commandConfig?.parameters ?? [];
    return parameters.map((param) => param.name).join(' ');
  }

  PluginExecutionResult? _lastResult;

  // 统一的按钮样式
  static final _buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.cyan.shade700,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    minimumSize: const Size(0, 36),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  );

  @override
  void initState() {
    super.initState();
    _initializeParameterValues();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeParameterValues() {
    final parameters = widget.plugin.config.commandConfig?.parameters ?? [];
    for (final param in parameters) {
      if (param.type == ParameterType.none || param.type == ParameterType.boolean) {
        _parameterValues[param.name] = (param.value == 'true' || param.value == '1');
      } else if (param.type == ParameterType.textAreaRegex) {
        // 为textAreaRegix类型创建两个控制器
        final valueController = TextEditingController(text: param.value ?? '');
        final regexController = TextEditingController(text: param.valueRegex ?? '');
        _controllers[param.name] = valueController;
        _controllers['${param.name}_regex'] = regexController;
        _parameterValues[param.name] = param.value ?? '';
        _parameterValues['${param.name}_regex'] = param.valueRegex?? '';
      } else {
        final controller = TextEditingController(text: param.value ?? '');
        _controllers[param.name] = controller;
        _parameterValues[param.name] = param.value ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.plugin.config;
    final commandConfig = config.commandConfig;
    final displayConfig = config.displayConfig;
    
    return Scaffold(
      appBar: AppTextStyles.buildAppBar(
        title: config.name,
        actions: [
          IconButton(
            onPressed: _showPluginInfo,
            icon: const Icon(Icons.info_outline),
            tooltip: '插件信息',
          ),
          IconButton(
            onPressed: _exportPlugin,
            icon: const Icon(Icons.file_download),
            tooltip: '导出插件',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppLayoutConfig.pagePadding,
          clipBehavior: Clip.none,
          children: [
            // 命令预览（使用 CollapsibleSection 替换外层 Container）
            CollapsibleSection(
              icon: Icons.terminal,
              title: '命令预览',
              iconColor: Colors.cyan.shade700,
              collapsedSummaryText: _buildFullCommand(),
              trailingBuilder: (expanded) => [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyCommand(_buildFullCommand()),
                  tooltip: '复制命令',
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 22),
                  onPressed: _clearCommand,
                  tooltip: '清除参数',
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _isExecuting ? null : _executeCommand,
                  style: _buttonStyle.copyWith(
                    shape: const WidgetStatePropertyAll(CircleBorder()),
                    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                    fixedSize: const WidgetStatePropertyAll(Size(30, 30)),
                    minimumSize: const WidgetStatePropertyAll(Size(30, 30)),
                  ),
                  child: _isExecuting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 22),
                ),
              ],
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    _buildFullCommand().isEmpty ? '请配置参数后查看命令预览' : _buildFullCommand(),
                    style: TextStyle(
                      color: _buildFullCommand().isEmpty ? Colors.grey.shade400 : Colors.white,
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                    maxLines: 5,
                    minLines: 2,
                  ),
                ),
              ],
            ),
            
            // 参数配置（可折叠）
            if (commandConfig?.parameters.isNotEmpty == true) ...[              
              CollapsibleSection(
                icon: Icons.settings,
                title: '参数配置',
                iconColor: Colors.cyan.shade700,
                collapsedSummaryText: _parameterSummaryText,
                initiallyExpanded: _isParameterSectionExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isParameterSectionExpanded = expanded;
                  });
                },
                children: commandConfig!.parameters.map(_buildParameterWidget).toList(),
              ),
              const SizedBox(height: 20),
            ],
                  
            // 主内容区域（普通/对比模式）
            _buildMainContentArea(),
          ],
        ),
      ),
    );
  }

  void _showPluginInfo() {
    final config = widget.plugin.config;
    final commandConfig = config.commandConfig;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.extension,
              color: Colors.cyan.shade700,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(config.name),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.cyan.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                config.type.name.toUpperCase(),
                style: TextStyle(
                  color: Colors.cyan.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (config.description.isNotEmpty) ...[
                const Text(
                  '描述',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(config.description),
                const SizedBox(height: 16),
              ],
              if (commandConfig != null) ...[
                const Text(
                  '命令信息',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCommandInfoInDialog(commandConfig),
                const SizedBox(height: 16),
              ],
              if (commandConfig?.parameters.isNotEmpty == true) ...[
                const Text(
                  '参数列表',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...commandConfig!.parameters.map((param) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              param.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                getParameterTypeLabel(param.type),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                            if (param.required) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '必填',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (param.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            param.description!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 导出插件配置
  void _exportPlugin() async {
    try {
      await PluginExportDialog.show(
        context: context,
        pluginConfig: widget.plugin.config,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('打开导出对话框失败: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildCommandInfoInDialog(CommandConfig commandConfig) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                commandConfig.type == CommandType.system ? Icons.terminal : Icons.insert_drive_file,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                '类型: ${commandConfig.type == CommandType.system ? '系统命令' : '可执行文件'}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.code,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '命令: ${commandConfig.executableFile}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          if (commandConfig.executableDir?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '工作目录: ${commandConfig.executableDir}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          if (commandConfig.parameters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '参数数量: ${commandConfig.parameters.length}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
  // 提取公共的参数名称样式方法
  TextStyle _getParameterNameStyle(bool isRequired) {
    return AppTextStyles.listTitle.copyWith(
      fontWeight: FontWeight.w600,
      color: isRequired ? Colors.cyan.shade700 : null,
    );
  }

  Widget _buildParameterWidget(ParameterConfig param) {
    final isCompactInput = _isCompactInputType(param.type);
    final isRegexInput = param.type == ParameterType.textAreaRegex;

      return AppSectionCard(
        hasShadow: param.required,
        children: [
          Row(
            children: [
              Text(param.name, style: _getParameterNameStyle(param.required)),
              const SizedBox(width: 12),
              if (isRegexInput)
                Expanded(child: _buildTextAndButton(param))
              else if (isCompactInput)
                Expanded(child: _buildParameterInput(param)),
            ],
          ),
          if (isCompactInput == false) ...[
            const SizedBox(height: 8),
            _buildParameterInput(param),
          ],
        ],
      );
  }

  // 是否紧凑输入类型
  bool _isCompactInputType(ParameterType type) {
    return type != ParameterType.textArea && type != ParameterType.textAreaRegex;
  }

    // 提取公共的验证器方法
  String? _getValidator(ParameterConfig param, String? value) {
    if (param.required && (value?.isEmpty ?? true)) {
      return '此参数为必填项';
    }
    if (param.type == ParameterType.number && value?.isNotEmpty == true) {
      if (double.tryParse(value!) == null) {
        return '请输入有效的数字';
      }
    }
    return null;
  }

  // 提取公共的TextFormField构建方法
  Widget _buildTextFormField(
    ParameterConfig param, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    int? minLines,
    bool isRegex = false,
  }) {
    final paramKey = isRegex ? '${param.name}_regex' : param.name;
    final isValidationEnabled = _regexValidationStates[paramKey] ?? false;
    
    return TextFormField(
      controller: _controllers[paramKey],
      decoration: AppTextStyles.getInputDecoration(
        isRegex ? '正则表达式' : getParameterTypeLabel(param.type),
        isRegex ? '请输入正则表达式，并选中输入框右侧按钮应用/取消' : param.description ?? '请输入${getParameterTypeLabel(param.type)}',
        onTap: isRegex ? () {
          setState(() {
            final isRegexValid = _controllers[paramKey]?.text.isNotEmpty == true;
            final isInputValid = _controllers[param.name]?.text.isNotEmpty == true;
            if (isRegexValid && isInputValid) {
              final newState = !(_regexValidationStates[paramKey] ?? false);
              _regexValidationStates[paramKey] = newState;
              
              if (newState) {
                // 启用正则表达式处理：保存原始文本并应用正则匹配
                final originalText = _controllers[param.name]!.text;
                _originalTexts[param.name] = originalText;
                
                try {
                  final regexPattern = _controllers[paramKey]!.text;
                  final regex = RegExp(regexPattern);
                  final matches = regex.allMatches(originalText);
                  
                  // 提取所有group(1)的值并用空格连接
                  final extractedValues = matches
                      .map((match) => match.group(1))
                      .where((group) => group != null)
                      .cast<String>()
                      .toList();
                  
                  final processedText = extractedValues.join(' ');
                  _controllers[param.name]!.text = processedText;
                  _parameterValues[param.name] = processedText;
                } catch (e) {
                  // 正则表达式无效时，保持原始状态
                  _regexValidationStates[paramKey] = false;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('正则表达式无效: $e')),
                  );
                }
              } else {
                // 禁用正则表达式处理：恢复原始文本
                final originalText = _originalTexts[param.name];
                if (originalText != null) {
                  _controllers[param.name]!.text = originalText;
                  _parameterValues[param.name] = originalText;
                }
              }
            } else {
              _regexValidationStates[paramKey] = false;
            }
          });
        } : null,
        suffixIconData: isRegex ? (isValidationEnabled ? Icons.check_circle : Icons.radio_button_unchecked) : null,
        suffixIconColor: isRegex ? (isValidationEnabled ? Colors.green.shade600 : Colors.grey.shade400) : null,
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      minLines: minLines,
      validator: isRegex ? null : (value) => _getValidator(param, value),
      onChanged: (value) => _parameterValues[paramKey] = value,
    );
  }

  // 提取公共的文件选择器构建方法
  Widget _buildTextAndButton(ParameterConfig param) {
    final isDirectory = param.type == ParameterType.folderPath;
    final isRegexInput = param.type == ParameterType.textAreaRegex;
    return Row(
      children: [
        Expanded(
          child: _buildTextFormField(param, isRegex: isRegexInput),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: AppTextStyles.inputFieldHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              if (isRegexInput) {
                _showRegexPickerDialog(param);
              } else if (isDirectory) {
                _selectFolder(param);
              } else {
                _selectFile(param);
              }
            },
            icon: Icon(
              isRegexInput 
                  ? Icons.pattern 
                  : (isDirectory ? Icons.folder_open : Icons.file_open), 
              size: 16
            ),
            label: Text(
              isRegexInput ? '正则' : '选择', 
              style: const TextStyle(fontSize: 12)
            ),
            style: _buttonStyle,
          ),
        ),
      ],
    );
  }

  Widget _buildParameterInput(ParameterConfig param) {
    switch (param.type) {
      case ParameterType.none:
      case ParameterType.boolean:
        return Align(
          alignment: Alignment.centerLeft,
          child: Transform.scale(
            scale: 0.7,
            child: Switch(
              value: _parameterValues[param.name] ?? false,
              onChanged: (value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() => _parameterValues[param.name] = value);
                  }
                });
              },
            ),
          ),
        );
        
      case ParameterType.text:
        return _buildTextFormField(param);
        
      case ParameterType.number:
        return _buildTextFormField(
          param,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*'))],
        );
        
      case ParameterType.textArea:
      case ParameterType.textAreaRegex:
        return _buildTextFormField(param, maxLines: 4, minLines: 3);
        
      case ParameterType.filePath:
      case ParameterType.folderPath:
        return _buildTextAndButton(param);
    }
  }

  Widget _buildResultArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 固定高度的头部状态栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _lastResult!.success ? Colors.green.shade700 : Colors.red.shade700,
            ),
            child: Row(
              children: [
                Icon(
                  _lastResult!.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _lastResult!.success ? '执行成功' : '执行失败',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_lastResult!.timestamp.hour.toString().padLeft(2, '0')}:${_lastResult!.timestamp.minute.toString().padLeft(2, '0')}:${_lastResult!.timestamp.second.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 16),
                  onPressed: () => setState(() => _lastResult = null),
                ),
              ],
            ),
          ),
          // 可滚动的内容区域
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_lastResult!.output.isNotEmpty) ...[
                    const Text('输出:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _lastResult!.output,
                      style: const TextStyle(color: Colors.white, fontFamily: 'JetBrainsMono', fontSize: 12),
                    ),
                  ],
                  if (_lastResult!.error?.isNotEmpty == true) ...[
                    if (_lastResult!.output.isNotEmpty) const SizedBox(height: 12),
                    const Text('错误:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      _lastResult!.error!,
                      style: TextStyle(color: Colors.red.shade300, fontFamily: 'JetBrainsMono', fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String getFilePath(String path) {
    if (path.contains('/Macintosh HD')) {
      final index = path.indexOf('/Macintosh HD');
      return path.substring(index + '/Macintosh HD'.length);
    }
    return path;
  }

  String _buildFullCommand() {
    final commandConfig = widget.plugin.config.commandConfig;
    if (commandConfig == null) return '';

    // 处理executableFile路径，如果包含/Macintosh HD则截取后面的部分
    String executableFile = getFilePath(commandConfig.executableFile);
    final parts = <String>[executableFile];
    
    for (final param in commandConfig.parameters) {
      final value = _parameterValues[param.name];
      
      if (param.type == ParameterType.none) {
        if (value == true) {
          parts.add(param.name);
        }
      } else if (param.type == ParameterType.filePath || param.type == ParameterType.folderPath) {
        parts.add('${param.name} ${getFilePath(value.toString())}');
      } else if (value != null && value.toString().isNotEmpty) {
        parts.add('${param.name} ${value.toString()}');
      }
    }
    
    return parts.join(' ');
  }

  Future<void> _selectFile(ParameterConfig param) async {
    final result = await FilePickerDialog.pickFile(
      context: context,
      title: '选择文件 - ${param.name}',
      initialPath: _controllers[param.name]?.text ?? '',
    );
    
    if (result != null) {
      setState(() {
        _controllers[param.name]?.text = result;
        _parameterValues[param.name] = result;
      });
    }
  }

  Future<void> _selectFolder(ParameterConfig param) async {
    final result = await FilePickerDialog.pickDirectory(
      context: context,
      title: '选择文件夹 - ${param.name}',
      initialPath: _controllers[param.name]?.text ?? '',
    );
    
    if (result != null) {
      setState(() {
        _controllers[param.name]?.text = result;
        _parameterValues[param.name] = result;
      });
    }
  }

  void _copyCommand(String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('命令已复制到剪贴板'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _executeCommand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isExecuting = true);

    try {
      final command = _buildFullCommand();
      final result = await _executeShellCommand(command);
      setState(() => _lastResult = result);
      
      // 如果命令执行成功，保存参数值到配置中并折叠参数配置区域
      if (result.success) {
        await _saveParameterValues();
        // 折叠参数配置区域
        setState(() {
          _isParameterSectionExpanded = false;
        });
      }
    } catch (e) {
      setState(() {
        _lastResult = PluginExecutionResult(
          success: false,
          output: '',
          error: e.toString(),
          timestamp: DateTime.now(),
        );
      });
    } finally {
      setState(() => _isExecuting = false);
    }
  }

  /// 保存参数值到插件配置中
  Future<void> _saveParameterValues() async {
    try {
      final commandConfig = widget.plugin.config.commandConfig;
      if (commandConfig == null) return;

      // 创建新的参数列表，更新每个参数的值
      final updatedParameters = <ParameterConfig>[];
      
      for (final param in commandConfig.parameters) {
        String? newValue;
        
        // 根据参数类型获取对应的值
        if (param.type == ParameterType.none || param.type == ParameterType.boolean) {
          final boolValue = _parameterValues[param.name] as bool? ?? false;
          newValue = boolValue.toString();
        } else if (param.type == ParameterType.textAreaRegex) {
          // 对于 textAreaRegex 类型，保存主要的文本值
          newValue = _parameterValues[param.name] as String? ?? '';
        } else {
          // 其他文本类型参数
          newValue = _parameterValues[param.name] as String? ?? '';
        }

        // 创建更新后的参数配置
        final updatedParam = ParameterConfig(
          name: param.name,
          type: param.type,
          required: param.required,
          description: param.description,
          value: newValue, // 更新为用户输入的值
          valueRegex: _parameterValues['${param.name}_regex'] as String?,
        );
        updatedParameters.add(updatedParam);
      }
      
      // 创建更新后的命令配置
      final updatedCommandConfig = CommandConfig(
        executableFile: commandConfig.executableFile,
        type: commandConfig.type,
        executableDir: commandConfig.executableDir,
        parameters: updatedParameters,
      );
      
      // 创建更新后的插件配置
      final updatedPluginConfig = widget.plugin.config.copyWith(
        commandConfig: updatedCommandConfig,
      );
      
      // 通过 PluginManager 保存配置
      final pluginManager = PluginManager();
      await pluginManager.updatePlugin(updatedPluginConfig);
    } catch (e, stackTrace) {
      // 可以选择显示错误提示给用户
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存参数值失败: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<PluginExecutionResult> _executeShellCommand(String command) async {
    await Future.delayed(const Duration(seconds: 1));
    return await widget.plugin.executeParameter(command);
  }

  // 显示正则表达式选择对话框
  void _showRegexPickerDialog(ParameterConfig param) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RegexPickerDialog(
          initialValue: _parameterValues['${param.name}_regex'] as String?,
          onRegexSelected: (selectedRegex) {
            setState(() {
              _controllers['${param.name}_regex']?.text = selectedRegex;
              _parameterValues['${param.name}_regex'] = selectedRegex;
            });
          },
        );
      },
    );
  }

  // 添加清除命令方法
  void _clearCommand() {
    setState(() {
      // 清空所有参数值
      _parameterValues.clear();
      
      // 清空所有控制器的文本
      for (var controller in _controllers.values) {
        controller.clear();
      }
      
      // 清空正则表达式验证状态
      _regexValidationStates.clear();
      
      // 清空原始文本存储
      _originalTexts.clear();
      
      // 清空执行结果
      _lastResult = null;
    });
    
    // 显示清除成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清除所有参数'),
        duration: Duration(seconds: 2),
      ),
    );
  }

    // 构建主内容区域
  Widget _buildMainContentArea() {
    final config = widget.plugin.config;
    final displayConfig = config.displayConfig;
    
    // 如果displayConfig为空或者type为normal，显示普通的执行结果区域
    if (displayConfig == null || displayConfig.type == DisplayType.normal) {
      return _buildNormalContentArea();
    }
    
    // 如果type为compare，显示对比模式的内容区域
    if (displayConfig.type == DisplayType.compare) {
      return _buildCompareContentArea(displayConfig.param);
    }
    
    return const SizedBox.shrink();
  }
  
  // 构建普通模式的内容区域
  Widget _buildNormalContentArea() {
    return Container(
      width: double.infinity,
      margin: AppLayoutConfig.cardMargin,
      padding: AppLayoutConfig.cardPadding,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: AppLayoutConfig.borderRadiusLarge,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_outline, size: 20, color: Colors.cyan.shade700),
              const SizedBox(width: 8),
              const Text('执行结果', style: AppTextStyles.sectionTitle),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _executeCommand,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('执行命令', style: AppTextStyles.buttonNormal),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lastResult != null)
            _buildResultDisplay(_lastResult!)
          else
            Container(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  '点击"执行命令"查看结果',
                  style: AppTextStyles.bodySecondSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // 构建对比模式的内容区域
  Widget _buildCompareContentArea(String? compareParam) {
    if (compareParam == null || compareParam.isEmpty) {
      return Container(
        width: double.infinity,
        margin: AppLayoutConfig.cardMargin,
        padding: AppLayoutConfig.cardPadding,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: AppLayoutConfig.borderRadiusLarge,
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '对比模式配置错误：未指定对比基础参数',
                style: AppTextStyles.bodySecondSmall,
              ),
            ),
          ],
        ),
      );
    }
    
    // 查找对比参数的配置
    final commandConfig = widget.plugin.config.commandConfig;
    final compareParamConfig = commandConfig?.parameters.firstWhere(
      (param) => param.name == compareParam,
      orElse: () => const ParameterConfig(name: '', type: ParameterType.text),
    );
    
    if (compareParamConfig?.name.isEmpty == true) {
      return Container(
        width: double.infinity,
        margin: AppLayoutConfig.cardMargin,
        padding: AppLayoutConfig.cardPadding,
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: AppLayoutConfig.borderRadiusLarge,
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '对比模式配置错误：找不到参数 "$compareParam"',
                style: AppTextStyles.bodySecondSmall,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      margin: AppLayoutConfig.cardMargin,
      padding: AppLayoutConfig.cardPadding,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: AppLayoutConfig.borderRadiusLarge,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, size: 20, color: Colors.cyan.shade700),
              const SizedBox(width: 8),
              const Text('对比模式', style: AppTextStyles.sectionTitle),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _executeCompareCommand,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('执行对比', style: AppTextStyles.buttonNormal),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 左右分栏布局
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：对比参数输入
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '对比参数: ${compareParamConfig!.name}',
                        style: AppTextStyles.bodySecondary.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (compareParamConfig.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          compareParamConfig.description!,
                          style: AppTextStyles.bodySecondXSmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildCompareParameterInput(compareParamConfig),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // 右侧：执行结果
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '执行结果',
                        style: AppTextStyles.bodySecondary,
                      ),
                      const SizedBox(height: 8),
                      if (_lastResult != null)
                        _buildResultDisplay(_lastResult!)
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          child: const Center(
                            child: Text(
                              '点击"执行对比"查看结果',
                              style: AppTextStyles.bodySecondSmall,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 构建对比参数输入组件
  Widget _buildCompareParameterInput(ParameterConfig paramConfig) {
    // 获取当前参数值
    final currentValue = _parameterValues[paramConfig.name] ?? paramConfig.value ?? '';
    
    switch (paramConfig.type) {
      case ParameterType.text:
        return TextFormField(
          initialValue: currentValue,
          decoration: AppTextStyles.getInputDecoration(
            paramConfig.name,
            '请输入${paramConfig.name}的值',
          ),
          onChanged: (value) {
            setState(() {
              _parameterValues[paramConfig.name] = value;
            });
          },
        );
        
      case ParameterType.textArea:
      case ParameterType.textAreaRegex:
        return TextFormField(
          initialValue: currentValue,
          decoration: AppTextStyles.getInputDecoration(
            paramConfig.name,
            '请输入${paramConfig.name}的值',
          ),
          maxLines: 3,
          onChanged: (value) {
            setState(() {
              _parameterValues[paramConfig.name] = value;
            });
          },
        );
        
      case ParameterType.number:
        return TextFormField(
          initialValue: currentValue,
          decoration: AppTextStyles.getInputDecoration(
            paramConfig.name,
            '请输入数字',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() {
              _parameterValues[paramConfig.name] = value;
            });
          },
        );
        
      case ParameterType.filePath:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: currentValue,
                decoration: AppTextStyles.getInputDecoration(
                  paramConfig.name,
                  '请选择文件',
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _selectFile(paramConfig),
              icon: const Icon(Icons.file_open, size: 16),
              label: const Text('选择', style: AppTextStyles.buttonNormal),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        );
        
      case ParameterType.folderPath:
        return Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: currentValue,
                decoration: AppTextStyles.getInputDecoration(
                  paramConfig.name,
                  '请选择目录',
                ),
                readOnly: true,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _selectFolder(paramConfig),
              icon: const Icon(Icons.folder_open, size: 16),
              label: const Text('选择', style: AppTextStyles.buttonNormal),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        );
        
      default:
        return TextFormField(
          initialValue: currentValue,
          decoration: AppTextStyles.getInputDecoration(
            paramConfig.name,
            '请输入${paramConfig.name}的值',
          ),
          onChanged: (value) {
            setState(() {
              _parameterValues[paramConfig.name] = value;
            });
          },
        );
    }
  }
  
  // 构建结果显示组件
  Widget _buildResultDisplay(PluginExecutionResult result) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.output.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '输出',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.output,
                      style: AppTextStyles.bodySecondSmall.copyWith(
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            if (result.error?.isNotEmpty == true) ...[
              if (result.output.isNotEmpty) const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '错误',
                          style: AppTextStyles.bodySecondary.copyWith(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result.error!,
                      style: AppTextStyles.bodySecondSmall.copyWith(
                        fontFamily: 'JetBrainsMono',
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green.shade600 : Colors.red.shade600,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '退出码: ${result.exitCode ?? 'N/A'}',
                  style: AppTextStyles.bodySecondXSmall.copyWith(
                    color: result.success ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '执行时间: ${result.timestamp.hour.toString().padLeft(2, '0')}:${result.timestamp.minute.toString().padLeft(2, '0')}:${result.timestamp.second.toString().padLeft(2, '0')}',
                  style: AppTextStyles.bodySecondXSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 执行对比命令
  Future<void> _executeCompareCommand() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isExecuting = true);

    try {
      final command = _buildFullCommand();
      final result = await _executeShellCommand(command);
      setState(() => _lastResult = result);
      
      // 如果命令执行成功，保存参数值到配置中并折叠参数配置区域
      if (result.success) {
        await _saveParameterValues();
        // 折叠参数配置区域
        setState(() {
          _isParameterSectionExpanded = false;
        });
      }
    } catch (e) {
      setState(() {
        _lastResult = PluginExecutionResult(
          success: false,
          output: '',
          error: e.toString(),
          timestamp: DateTime.now(),
        );
      });
    } finally {
      setState(() => _isExecuting = false);
    }
  }
}
  