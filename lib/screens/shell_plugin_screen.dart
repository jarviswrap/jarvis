import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/plugin_system/shell_plugin.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/widgets/file_picker_dialog.dart';
import '../core/utils/app_text_styles.dart';
import '../core/widgets/regex_picker_dialog.dart';

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
        _parameterValues[param.name] = param.value == 'true' || param.value == '1';
      } else if (param.type == ParameterType.textAreaRegex) {
        // 为textAreaRegix类型创建两个控制器
        final valueController = TextEditingController(text: param.value ?? '');
        final regexController = TextEditingController(text: '');
        _controllers[param.name] = valueController;
        _controllers['${param.name}_regex'] = regexController;
        _parameterValues[param.name] = param.value ?? '';
        _parameterValues['${param.name}_regex'] = '';
      } else {
        final controller = TextEditingController(text: param.value ?? '');
        _controllers[param.name] = controller;
        _parameterValues[param.name] = param.value ?? '';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final commandConfig = widget.plugin.config.commandConfig;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plugin.config.name, style: AppTextStyles.appBarTitle),
        backgroundColor: Colors.cyan.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showPluginInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCommandPreview(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (commandConfig?.parameters.isNotEmpty == true) ...[
                    const Text('参数配置', style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 12),
                    ...commandConfig!.parameters.map(_buildParameterWidget),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ),
          if (_lastResult != null) _buildResultArea(),
        ],
      ),
    );
  }

  Widget _buildCommandPreview() {
    final command = _buildFullCommand();
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(6),
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
              Icon(Icons.terminal, size: 20, color: Colors.cyan.shade700),
              const SizedBox(width: 8),
              const Text('命令预览', style: AppTextStyles.sectionTitle),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyCommand(command),
                tooltip: '复制命令',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _clearCommand,
                tooltip: '清除参数',
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: const EdgeInsets.all(4),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 30,
                child: ElevatedButton.icon(
                  onPressed: _isExecuting ? null : _executeCommand,
                  icon: _isExecuting 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_arrow, size: 16),
                  label: Text(_isExecuting ? '执行中' : '执行', style: const TextStyle(fontSize: 12)),
                  style: _buttonStyle.copyWith(
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              command.isEmpty ? '请配置参数后查看命令预览' : command,
              style: TextStyle(
                color: command.isEmpty ? Colors.grey.shade400 : Colors.white,
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
              ),
              maxLines: 5,
              minLines: 2,
            ),
          ),
        ],
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
              
              const Text(
                '状态',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    config.enabled ? Icons.check_circle : Icons.cancel,
                    color: config.enabled ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(config.enabled ? '已启用' : '已禁用'),
                ],
              ),
              
              if (commandConfig != null) ...[
                const SizedBox(height: 16),
                const Text(
                  '命令配置',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildCommandInfoInDialog(commandConfig),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: param.required ? 6 : 1,
      shadowColor: param.required ? Colors.cyan.shade700 : Colors.grey.shade300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                children: [
                  Text(param.name, style: _getParameterNameStyle(param.required)),
                  const SizedBox(width: 12),
                  if (isRegexInput)
                    Expanded(child: _buildTextAndButton(param))
                  else if (isCompactInput)
                    Expanded(child: _buildParameterInput(param))
                ],
              ),
            if (param.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(param.description!, style: AppTextStyles.bodySecondSmall),
            ],
            if (isCompactInput == false)
              ...[
                const SizedBox(height: 8),
                _buildParameterInput(param),
              ],
          ],
        ),
      ),
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
        isRegex ? '请输入正则表达式，并选中输入框右侧按钮应用/取消' : '请输入${getParameterTypeLabel(param.type)}',
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
      validator: (value) => _getValidator(param, value),
      onChanged: (value) => _parameterValues[param.name] = value,
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
      constraints: const BoxConstraints(maxHeight: 250),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
}

  