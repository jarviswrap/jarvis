import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/plugin_system/icon_utils.dart';
import '../core/widgets/file_picker_dialog.dart';
import '../core/widgets/plugin_import_dialog.dart';
import '../core/utils/app_text_styles.dart';
import '../core/utils/app_layout_config.dart';
import '../core/widgets/collapsible_section.dart';

class AddPluginScreen extends StatefulWidget {
  final PluginConfig? editingPlugin;

  const AddPluginScreen({super.key, this.editingPlugin});

  @override
  State<AddPluginScreen> createState() => _AddPluginScreenState();
}

class _AddPluginScreenState extends State<AddPluginScreen> {
  // 通用插件参数
  List<String> get _availableIcons => IconUtils.getAvailableIconNames();
  bool _enabled = true;
  String _selectedIcon = 'extension'; 
  String _displayMode = 'normal';
  String? _compareBaseParameter;
  
  PluginType _selectedType = PluginType.custom;
  final _formKey = GlobalKey<FormState>();
  final _controllerName = TextEditingController();
  final _controllerDescription = TextEditingController();
  
  // 添加命令类型相关变量
  CommandType _commandType = CommandType.system;
  final _controllerExecutePath = TextEditingController();
  final _controllerWorkingDir = TextEditingController();
  List<ParameterConfig> _commandParameters = [];
  
  @override
  void initState() {
    super.initState();
    final plugin = widget.editingPlugin;
    if (plugin != null) { // 编辑插件
      _enabled = plugin.enabled;
      _selectedIcon = plugin.icon;
      _selectedType = plugin.type;
      _controllerName.text = plugin.name;
      _controllerDescription.text = plugin.description;
  
      final commandConfig = plugin.commandConfig;
      _commandType = commandConfig?.type ?? CommandType.system; 
      _controllerWorkingDir.text = commandConfig?.executableDir ?? '';
      _controllerExecutePath.text = commandConfig?.executableFile ?? '';
      _commandParameters = commandConfig?.parameters ?? [];
      
      // 初始化展示配置
      final displayConfig = plugin.displayConfig;
      if (displayConfig != null) {
        _displayMode = displayConfig.type.name;
        _compareBaseParameter = displayConfig.param;
      } else {
        _displayMode = 'normal';
        _compareBaseParameter = null;
      }
    } else { // 新增插件
      _selectedType = PluginType.custom;
      _commandType = CommandType.system;
      _displayMode = 'normal';
      _compareBaseParameter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTextStyles.buildAppBar(
        title: widget.editingPlugin == null ? '添加插件' : '编辑插件',
        actions: [
          IconButton(
            onPressed: _showImportDialog,
            icon: const Icon(Icons.file_upload),
            tooltip: '导入插件配置',
          ),
          IconButton(
            onPressed: _savePlugin,
            icon: const Icon(Icons.save),
            tooltip: widget.editingPlugin == null ? '保存插件' : '更新插件',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppLayoutConfig.pagePadding,
          children: [
            // 基本信息
            CollapsibleSection(
              icon: Icons.info_outline,
              title: '基本信息',
              iconColor: Colors.cyan.shade700,
              childrenSpacing: 12,
              children: [
                // 第一行：插件名称和类别
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _controllerName,
                        decoration: AppTextStyles.getInputDecoration(
                          '插件名称',
                          '请输入插件名称',
                        ),
                        validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return '请输入插件名称';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<PluginType>(
                        initialValue: _selectedType,
                        decoration: AppTextStyles.getInputDecoration(
                          '插件类别',
                          '请输入插件类别',
                        ),
                        items: PluginType.values.map((type) {
                          return DropdownMenuItem<PluginType>(
                            value: type,
                            child: Text(type.name, style: AppTextStyles.bodyNormal),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value ?? PluginType.values.first;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return '请选择插件类别';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                // 第二行：图标和启用状态
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedIcon,
                        decoration: AppTextStyles.getInputDecoration(
                          '图标',
                          '请输入插件图标',
                        ),
                        items: _availableIcons.map((icon) {
                          return DropdownMenuItem(
                            value: icon,
                            child: Row(
                              children: [
                                IconUtils.getIconWidget(icon, size: 20, color: Colors.grey),
                                const SizedBox(width: 8),
                                Text(icon, style: AppTextStyles.bodyNormal),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedIcon = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: const BorderRadius.all(Radius.circular(4)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text('enable', style: AppTextStyles.bodyNormal),
                              ),
                              Transform.scale(
                                scale: 0.7,
                                child: Switch(
                                  value: _enabled,
                                  onChanged: (value) {
                                    setState(() {
                                      _enabled = value;
                                    });
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // 命令配置 - 只有当插件类别是shell时才显示
            if (_selectedType == PluginType.shell) ...[
              CollapsibleSection(
                icon: Icons.terminal,
                title: '命令配置',
                iconColor: Colors.cyan.shade700,
                childrenSpacing: 8,
                children: [
                  // 命令类型选择
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<CommandType>(
                          title: const Text('系统命令', style: AppTextStyles.bodyNormal),
                          subtitle: const Text('环境变量中的命令', style: AppTextStyles.bodySecondXSmall),
                          value: CommandType.system,
                          groupValue: _commandType,
                          onChanged: (value) {
                            setState(() { _commandType = value!; });
                          },
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<CommandType>(
                          title: const Text('可执行文件', style: AppTextStyles.bodyNormal),
                          subtitle: const Text('本地磁盘文件', style: AppTextStyles.bodySecondXSmall),
                          value: CommandType.file,
                          groupValue: _commandType,
                          onChanged: (value) {
                            setState(() { _commandType = value!; });
                          },
                          dense: true,
                        ),
                      ),
                    ],
                  ),

                  // 根据命令类型显示不同的输入方式
                  if (_commandType == CommandType.system) ...[
                    TextFormField(
                      controller: _controllerExecutePath,
                      decoration: AppTextStyles.getInputDecoration(
                        '基础命令',
                        '例如: ls, git, docker, addr2line',
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) return '请输入基础命令';
                        return null;
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _controllerExecutePath,
                            decoration: AppTextStyles.getInputDecoration(
                              '可执行文件路径',
                              '/usr/local/bin/myapp',
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) return '请选择可执行文件';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _selectExecutableFile,
                          icon: const Icon(Icons.folder_open, size: 16),
                          label: const Text('选择', style: AppTextStyles.buttonNormal),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 工作目录
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _controllerWorkingDir,
                          decoration: AppTextStyles.getInputDecoration(
                            '工作目录 (可选)',
                            '/Users/username/projects',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _selectWorkingDirectory,
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('选择', style: AppTextStyles.buttonNormal),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                      
                  // 命令参数配置标题与按钮（其后的参数列表与预览保持不变）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('命令参数', style: AppTextStyles.sectionTitle),
                      ElevatedButton.icon(
                        onPressed: _addCommandParameter,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('添加参数', style: AppTextStyles.buttonNormal),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  
                  // 参数列表
                  if (_commandParameters.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Center(
                        child:Text(
                          '暂无参数，点击"添加参数"来配置命令参数',
                          style: AppTextStyles.bodySecondSmall,
                        ),
                      ),
                    )
                  else
                    ...(_commandParameters.asMap().entries.map((entry) {
                      final index = entry.key;
                      final param = entry.value;
                      return _buildParameterCard(index, param);
                    }).toList()),
                  
                  // 预览完整命令
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '命令预览:',
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _buildCommandPreview(),
                          style: AppTextStyles.bodySecondSmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            
            // 展示配置 - 与命令配置同一层级
            _buildDisplayConfigCard(),
          ],
        ),
      ),
    );
  }

  // 修改保存方法
  void _savePlugin() async {
    if (_formKey.currentState!.validate()) {
      final pluginManager = PluginManager();
      
      // 创建CommandConfig对象
      final commandConfig = CommandConfig(
        executableFile: _controllerExecutePath.text,
        type: _commandType, // 直接使用枚举值
        executableDir: _controllerWorkingDir.text.isEmpty ? null : _controllerWorkingDir.text,
        parameters: _commandParameters,
      );
      
      // 创建DisplayConfig对象
      DisplayConfig? displayConfig;
      if (_selectedType == PluginType.shell) {
        displayConfig = DisplayConfig(
          type: _displayMode == 'compare' ? DisplayType.compare : DisplayType.normal,
          param: _displayMode == 'compare' ? _compareBaseParameter : null,
        );
      }
      
      final pluginConfig = PluginConfig(
        id: widget.editingPlugin?.id ?? const Uuid().v4(),
        name: _controllerName.text,
        description: _controllerDescription.text,
        type: _selectedType,
        icon: _selectedIcon,
        enabled: _enabled,
        commandConfig: commandConfig,
        displayConfig: displayConfig,
      );
  
      try {
        if (widget.editingPlugin != null) {
          await pluginManager.updatePlugin(pluginConfig);
        } else {
          await pluginManager.addPlugin(pluginConfig);
        }
  
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.editingPlugin != null ? '插件更新成功' : '插件添加成功'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存失败: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// 显示导入对话框
  void _showImportDialog() async {
    final config = await PluginImportDialog.showForParsing(context: context);
    if (config != null && mounted) {
      // 将导入的配置填充到表单中
      _fillFormWithConfig(config);
    }
  }
  
  /// 将配置数据填充到表单中
  void _fillFormWithConfig(PluginConfig config) {
    setState(() {
      _controllerName.text = config.name;
      _controllerDescription.text = config.description;
      _selectedType = config.type;
      _selectedIcon = config.icon;
      _enabled = config.enabled;

      if (config.commandConfig != null) {
        final commandConfig = config.commandConfig;
        _commandType = commandConfig?.type ?? CommandType.system; 
        _controllerWorkingDir.text = commandConfig?.executableDir ?? '';
        _controllerExecutePath.text = commandConfig?.executableFile ?? '';
        _commandParameters = commandConfig?.parameters ?? [];
      }
    });

    // 显示成功提示
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('插件配置已填充到表单中，请检查并保存'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  @override
  void dispose() {
    _controllerName.dispose();
    _controllerDescription.dispose();
    _controllerExecutePath.dispose();
    _controllerWorkingDir.dispose();
    super.dispose();
  }

  // 选择可执行文件
  void _selectExecutableFile() async {
    final result = await FilePickerDialog.pickFile(
      context: context,
      title: '选择可执行文件',
      initialPath: _controllerExecutePath.text,
    );
    if (result != null) {
      setState(() {
        _controllerExecutePath.text = result;
      });
    }
  }

  // 选择工作目录
  void _selectWorkingDirectory() async {
    final result = await FilePickerDialog.pickDirectory(
      context: context,
      title: '选择工作目录',
      initialPath: _controllerWorkingDir.text,
    );
    if (result != null) {
      setState(() {
        _controllerWorkingDir.text = result;
      });
    }
  }

  // 添加命令参数
  void _addCommandParameter() {
    setState(() {
      _commandParameters.add(const ParameterConfig(
        name: '',
        type: ParameterType.text, // 使用plugin_models.dart中的枚举值
        required: false,
        description: '',
      ));
    });
  }

  // 构建参数卡片
  Widget _buildParameterCard(int index, ParameterConfig param) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: AppLayoutConfig.cardPaddingMedium,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: param.name,
                    decoration: AppTextStyles.getInputDecoration(
                      '参数名',
                      '例如: -e, --file',
                    ),
                    style: AppTextStyles.inputText,
                    onChanged: (value) {
                      setState(() {
                        _commandParameters[index] = param.copyWith(name: value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<ParameterType>(
                    initialValue: param.type,
                    decoration: AppTextStyles.getInputDecoration(
                      '类型', ''
                    ),
                    style: AppTextStyles.inputText,
                    items: ParameterType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(getParameterTypeLabel(type), style: AppTextStyles.bodyNormal),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _commandParameters[index] = param.copyWith(type: value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _commandParameters.removeAt(index);
                    });
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 参数描述和必填勾选框在同一行
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: param.description,
                    decoration: AppTextStyles.getInputDecoration(
                      '参数描述',
                      '例如: 指定要分析的共享库文件',
                    ),
                    style: AppTextStyles.inputText,
                    onChanged: (value) {
                      setState(() {
                        _commandParameters[index] = param.copyWith(description: value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // 必填勾选框
                InkWell(
                  onTap: () {
                    setState(() {
                      _commandParameters[index] = param.copyWith(required: !param.required);
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: param.required ? Colors.orange.shade300 : Colors.grey.shade300,
                        width: 1,
                      ),
                      color: param.required ? Colors.orange.shade50 : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: Checkbox(
                            value: param.required,
                            onChanged: (value) {
                              setState(() {
                                _commandParameters[index] = param.copyWith(required: value ?? false);
                              });
                            },
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(
                              color: param.required ? Colors.orange : Colors.grey.shade400,
                              width: 1.5,
                            ),
                            activeColor: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '必填',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: param.required ? FontWeight.w500 : FontWeight.normal,
                            color: param.required ? Colors.orange.shade700 : Colors.grey.shade600,
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
      ),
    );
  }

  // 构建命令预览
  String _buildCommandPreview() {
    String baseCommand = _controllerExecutePath.text.trim();
    
    if (baseCommand.isEmpty) {
      return '请先配置基础命令';
    }
    
    List<String> parts = [baseCommand];
    for (var param in _commandParameters) {
      if (param.name.isNotEmpty) {
        if (param.type == ParameterType.none || param.type == ParameterType.boolean) {
          parts.add(param.name);
        } else {
          parts.add('${param.name} <${getParameterTypeLabel(param.type)}>');
        }
      }
    }
    return parts.join(' ');
  }

  // 位于 _AddPluginScreenState 中
  Widget _buildDisplayConfigCard() {
    return CollapsibleSection(
      icon: Icons.visibility,
      title: '展示配置',
      iconColor: Colors.cyan.shade700,
      childrenSpacing: 16,
      children: [
        // 展示方式选择
        _buildDisplayModeSelector(),
        // 对比基础参数选择（仅在 compare 模式下显示）
        if (_displayMode == 'compare') ...[
          _buildCompareBaseSelector(),
        ],
      ],
    );
  }

  // 构建展示模式选择器
  Widget _buildDisplayModeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('普通模式', style: AppTextStyles.bodyNormal),
                subtitle: const Text('标准的结果展示', style: AppTextStyles.bodySecondXSmall),
                value: 'normal',
                groupValue: _displayMode,
                onChanged: (value) {
                  setState(() {
                    _displayMode = value!;
                    if (_displayMode == 'normal') {
                      _compareBaseParameter = null;
                    }
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('对比模式', style: AppTextStyles.bodyNormal),
                subtitle: const Text('与基础参数对比展示', style: AppTextStyles.bodySecondXSmall),
                value: 'compare',
                groupValue: _displayMode,
                onChanged: (value) {
                  setState(() {
                    _displayMode = value!;
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建对比基础参数选择器
  Widget _buildCompareBaseSelector() {
    // 获取所有可用的参数名称（排除布尔类型和none类型）
    final availableParameters = _commandParameters
        .where((param) => 
            param.name.isNotEmpty && 
            param.type != ParameterType.none && 
            param.type != ParameterType.boolean)
        .map((param) => param.name)
        .toList();

    if (availableParameters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '没有可用于对比的参数，请先添加非布尔类型的命令参数',
                style: AppTextStyles.bodySecondSmall,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('对比基础参数', style: AppTextStyles.inputLabel),
        const SizedBox(width: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _compareBaseParameter,
              hint: const Text('选择用于对比的基础参数', style: AppTextStyles.inputHint),
              isExpanded: true,
              items: availableParameters.map((paramName) {
                final param = _commandParameters.firstWhere((p) => p.name == paramName);
                return DropdownMenuItem<String>(
                  value: paramName,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(paramName, style: AppTextStyles.bodyNormal),
                      if (param.description != null)
                        Text(
                          param.description?? "description",
                          style: AppTextStyles.bodySecondXSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _compareBaseParameter = value;
                });
              },
            ),
          ),
        ),
        if (_compareBaseParameter != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已选择 "$_compareBaseParameter" 作为对比基础',
                    style: AppTextStyles.bodySecondSmall.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}