import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jarvis/core/utils/app_logger.dart';
import '../core/plugin_system/shell_plugin.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/widgets/file_picker_dialog.dart';
import '../core/utils/app_text_styles.dart';
import '../core/utils/app_layout_config.dart';
import '../core/widgets/text_area_regex_input.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/widgets/plugin_export_dialog.dart';
import '../core/widgets/collapsible_section.dart';
import '../core/widgets/app_section_card.dart';
import '../core/widgets/plugin_info_dialog.dart';
import '../core/widgets/common_components.dart';
import '../core/widgets/compare_content_area.dart';
import '../core/utils/byte_length_input_formatter.dart';
import '../core/utils/regex_utils.dart';

class ShellPluginScreen extends StatefulWidget {
  final ShellPlugin plugin;

  const ShellPluginScreen({super.key, required this.plugin});

  @override
  State<ShellPluginScreen> createState() => _ShellPluginScreenState();
}

// 类字段：新增 Controller 管理
// 生命周期：统一释放 Controller
class _ShellPluginScreenState extends State<ShellPluginScreen> {
  bool _isExecuting = false;
  final Map<String, TextAreaRegexController> _textAreaControllers = {};
  final Map<String, dynamic> _parameterValues = {};
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _regexValidationStates = {}; // 添加正则表达式验证状态管理
  final Map<String, String> _originalTexts = {}; // 添加存储原始文本的Map
  final _formKey = GlobalKey<FormState>();
  bool _isParameterSectionExpanded = true; // 添加参数区域展开状态控制
    // 折叠/展开状态：命令预览、执行结果
  bool _isCommandPreviewExpanded = true;
  bool _isExecutionResultExpanded = false;
  
  // 参数概要文本
  String get _parameterSummaryText {
    final parameters = widget.plugin.config.commandConfig?.parameters ?? [];
    return parameters.map((param) => param.name).join(' ');
  }

  PluginExecutionResult? _lastResult;

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
    for (final c in _textAreaControllers.values) {
      c.dispose();
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
        _controllers[param.name] = valueController;
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
    // 计算一次，供本次 build 复用
    final fullCommand = _buildFullCommand();
    
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
            // 命令预览（受控折叠）
            CollapsibleSection(
              icon: Icons.terminal,
              title: '命令预览',
              collapsedSummaryText: fullCommand,
              expanded: _isCommandPreviewExpanded,
              onExpansionChanged: (expanded) {
                setState(() {
                  _isCommandPreviewExpanded = expanded;
                });
              },
              trailingBuilder: (expanded) => [
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copyCommand(fullCommand),
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
                Tooltip(
                  message: _isExecuting ? '执行中' : '执行命令',
                  child: ElevatedButton(
                    onPressed: _isExecuting ? null : _executeCommand,
                    style: CommonComponents.getButtonStyle().copyWith(
                      shape: const WidgetStatePropertyAll(CircleBorder()),
                      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      fixedSize: const WidgetStatePropertyAll(Size(30, 30)),
                      minimumSize: const WidgetStatePropertyAll(Size(30, 30)),
                    ),
                    child: _isExecuting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.play_arrow, size: 22),
                  ),
                ),
              ],
              children: [
                CommonComponents.codeBlock(
                  fullCommand,
                  emptyHint: '请配置参数后查看命令预览',
                ),
              ],
            ),
            
            // 参数配置（可折叠）
            if (commandConfig?.parameters.isNotEmpty == true) ...[              
              // 参数配置（受控折叠）
              CollapsibleSection(
                icon: Icons.settings,
                title: '参数配置',
                collapsedSummaryText: _parameterSummaryText,
                expanded: _isParameterSectionExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _isParameterSectionExpanded = expanded;
                  });
                },
                children: commandConfig!.parameters.map(_buildParameterWidget).toList(),
              ),
            ],
                  
            // 主内容区域（普通/对比模式）
            _buildMainContentArea(),
          ],
        ),
      ),
    );
  }

  void _showPluginInfo() {
    PluginInfoDialog.show(
      context: context,
      config: widget.plugin.config,
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

  // 提取公共的参数名称样式方法
  TextStyle _getParameterNameStyle(bool isRequired) {
    return AppTextStyles.listTitle.copyWith(
      fontWeight: FontWeight.w600,
      color: isRequired ? Colors.cyan.shade700 : null,
    );
  }

  Widget _buildParameterWidget(ParameterConfig param) {
    final isCompactInput = _isCompactInputType(param.type);

    return AppSectionCard(
      hasShadow: param.required,
      children: [
        if (isCompactInput)
          Row(
            children: [
              Text(param.name, style: _getParameterNameStyle(param.required)),
              const SizedBox(width: 12),
              Expanded(child: _buildParameterInput(param)),
            ],
          )
        else
          _buildParameterInput(param),
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
  // 在参数文本输入控件中，使用 setState 刷新命令预览
  Widget _buildTextFormField(
    ParameterConfig param, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int? maxLines,
    int? minLines,
  }) {
    final paramKey = param.name;
    final mergedFormatters = <TextInputFormatter>[
      ...?inputFormatters,
      const ByteLimitFormatter(10240),
    ];
    return TextFormField(
      controller: _controllers[paramKey],
      decoration: AppTextStyles.getInputDecoration(
        getParameterTypeLabel(param.type),
        param.description ?? '请输入${getParameterTypeLabel(param.type)}',
      ),
      keyboardType: keyboardType,
      inputFormatters: mergedFormatters,
      maxLines: maxLines,
      minLines: minLines,
      validator: (value) => _getValidator(param, value),
      onChanged: (value) {
        setState(() {
          _parameterValues[paramKey] = value;
        });
      },
    );
  }

  // 提取公共的文件选择器构建方法
  Widget _buildTextAndButton(ParameterConfig param) {
    final isDirectory = param.type == ParameterType.folderPath;
    // final isRegexInput = param.type == ParameterType.textAreaRegex;
    return Row(
      children: [
        Expanded(
          child: _buildTextFormField(param),
        ),
        const SizedBox(width: 6),
        SizedBox(
          height: AppTextStyles.inputFieldHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              if (isDirectory) {
                _selectFolder(param);
              } else {
                _selectFile(param);
              }
            },
            icon: Icon(
              isDirectory ? Icons.folder_open : Icons.file_open, 
              size: 16
            ),
            label: const Text(
              '选择', 
              style: TextStyle(fontSize: 12)
            ),
            style: CommonComponents.getButtonStyle(),
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
        final ctrl = _textAreaControllers.putIfAbsent(param.name, () => TextAreaRegexController());
        // 仅在首次创建时绑定监听（避免重复绑定）
        if (!(_parameterValues['__listening_${param.name}'] == true)) {
          _parameterValues['__listening_${param.name}'] = true;
          ctrl.addListener(() {
            // 完全基于 Controller 同步外部状态
            _parameterValues[param.name] = ctrl.text;
            _parameterValues['${param.name}_regex'] = ctrl.regex;
            setState(() {});
          });
        }
      
        return TextAreaRegexInput(
          controller: ctrl,
          rowPrefix: Text(param.name, style: _getParameterNameStyle(param.required)),
          initialText: (_parameterValues[param.name] ?? param.value ?? ''),
          initialRegex: _parameterValues['${param.name}_regex'] ?? param.valueRegex ?? '',
          mainLabel: getParameterTypeLabel(param.type),
          mainHint: param.description ?? '请输入${getParameterTypeLabel(param.type)}',
          mainValidator: (value) => _getValidator(param, value),
        );
        
      case ParameterType.filePath:
      case ParameterType.folderPath:
        return _buildTextAndButton(param);
    }
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
        setState(() {
          // 执行成功：折叠预览与参数，展开结果
          _isParameterSectionExpanded = false;
          _isCommandPreviewExpanded = false;
          _isExecutionResultExpanded = true;
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

  // 构建主内容区域（执行结果）
  Widget _buildMainContentArea() {
    final config = widget.plugin.config;
    final displayConfig = config.displayConfig;
    return CollapsibleSection(
        icon: Icons.play_circle_outline,
        title: '执行结果',
        collapsedSummaryText: '请展开查看执行结果',
        expanded: _isExecutionResultExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isExecutionResultExpanded = expanded;
          });
        },
      children: [
        if (displayConfig == null || displayConfig.type == DisplayType.normal)
          _buildNormalContentArea()
        else
          _buildCompareContentArea(displayConfig.param)
      ],
    );
  }
  
  // 构建普通模式的内容区域
  Widget _buildNormalContentArea() {
    if (_lastResult != null) {
      return _buildResultDisplay(_lastResult!);
    } else {
      return Container(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  '点击"执行命令"查看结果',
                  style: AppTextStyles.bodySecondSmall,
                ),
              ),
            );
    } 
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
              child: Text('对比模式配置错误：未指定对比基础参数', style: AppTextStyles.bodySecondSmall),
            ),
          ],
        ),
      );
    }
    final leftText = (() {
      final ctrl = _textAreaControllers[compareParam];
      if (ctrl == null) {
        return (_parameterValues[compareParam] as String?) ?? '';
      }
      final original = ctrl.originalText;
      final regex = ctrl.regex;
  
      // 调用前打印输入
      AppLogger.info('CompareContentArea: calling extractAllGroupsPerLine');
      AppLogger.debug('INPUT regex="$regex"');
      AppLogger.debug('INPUT source length=${original.length}');
      AppLogger.debug('INPUT source:\n$original');
  
      // 调用并打印输出
      final out = RegexUtils.extractAllGroupsPerLine(original, regex);
      AppLogger.debug('OUTPUT length=${out.length}');
      AppLogger.debug('OUTPUT:\n$out');
      return out;
    })();
    final rightText = _lastResult == null
        ? ''
        : (_lastResult!.output.isNotEmpty ? _lastResult!.output : (_lastResult!.error ?? ''));
    return CompareContentArea(
      left: leftText,
      right: rightText,
    );
  }
  
  // 构建结果显示组件
  Widget _buildResultDisplay(PluginExecutionResult result) {
    final media = MediaQuery.of(context);
    final viewHeight = media.size.height - media.padding.top - media.viewInsets.bottom;
    final maxH = viewHeight * 0.6;
    return Container(
      constraints: BoxConstraints(minHeight: 100, maxHeight: maxH),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.output.isNotEmpty) ...[
              CommonComponents.codeBlock(
                result.output,
                emptyHint: '无输出',
                minLines: 2,
                maxLines: 100,
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
                    CommonComponents.codeBlock(
                      result.error!,
                      emptyHint: '无错误信息',
                      textColor: Colors.red.shade300,
                      minLines: 2,
                      maxLines: 100,
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

}
  