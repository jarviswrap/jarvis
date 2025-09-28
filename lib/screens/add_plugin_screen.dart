import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/plugin_system/icon_utils.dart';
import '../core/widgets/file_picker_dialog.dart';
import '../core/utils/app_text_styles.dart';

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
  PluginType _selectedType = PluginType.custom;
  final _formKey = GlobalKey<FormState>();
  final _controllerName = TextEditingController();
  final _controllerDescription = TextEditingController();
  
  // 添加命令类型相关变量
  CommandType _commandType = CommandType.system; // 'system' 或 'file'
  final _controllerExecutePath = TextEditingController();
  final _controllerWorkingDir = TextEditingController();
  // final _baseCommandController = TextEditingController();
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
    } else { // 新增插件
      _selectedType = PluginType.custom;
      _commandType = CommandType.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editingPlugin != null ? 'Edit plugin' : 'Add plugin',
          style: AppTextStyles.appBarTitle,
        ),
        backgroundColor: Colors.cyan.shade700,
        actions: [
          TextButton(
            onPressed: _savePlugin,
            child: const Text('Save', style: AppTextStyles.buttonLarge),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本信息',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: 12),
                    // 第一行：插件名称和类别
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _controllerName,
                            decoration: AppTextStyles.getInputDecoration(
                              '插件名称',
                              "请输入插件名称",
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
                            decoration: const InputDecoration(
                              labelText: '插件类别',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: PluginType.values.map((type) {
                              return DropdownMenuItem<PluginType>(
                                value: type,
                                child: Text(type.name, 
                                style: AppTextStyles.bodyNormal),
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
                    const SizedBox(height: 12),
                    // 第二行：图标和启用状态
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedIcon,
                            decoration: const InputDecoration(
                              labelText: '图标',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            height: 32, // 与其他输入框高度一致
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: const BorderRadius.all(Radius.circular(4)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), // 与InputDecoration的contentPadding一致
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'enable',
                                      style: AppTextStyles.bodyNormal,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.7, // 缩小Switch以匹配输入框风格
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
                    const SizedBox(height: 12),
                    // 插件描述单独一行，因为内容较长
                    TextFormField(
                      controller: _controllerDescription,
                      decoration: AppTextStyles.getInputDecoration(
                        '插件描述', '请输入插件描述'
                      ),
                      maxLines: 2,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return '请输入插件描述';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 命令配置 - 只有当插件类别是shell时才显示
            if (_selectedType == PluginType.shell) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '命令配置',
                        style: AppTextStyles.sectionTitle,
                      ),
                      const SizedBox(height: 12),
                      
                      // 命令类型选择
                      // 修改单选按钮组件
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<CommandType>(
                              title: const Text('系统命令', style: AppTextStyles.bodyNormal),
                              subtitle: const Text('环境变量中的命令', style: AppTextStyles.bodySecondXSmall),
                              value: CommandType.system,
                              groupValue: _commandType,
                              onChanged: (value) {
                                setState(() {
                                  _commandType = value!;
                                });
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
                                setState(() {
                                  _commandType = value!;
                                });
                              },
                              dense: true,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // 根据命令类型显示不同的输入方式
                      // 修改条件判断
                      if (_commandType == CommandType.system) ...[
                        TextFormField(
                          controller: _controllerExecutePath,
                          decoration: AppTextStyles.getInputDecoration(
                            '基础命令',
                            '例如: ls, git, docker, addr2line',
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return '请输入基础命令';
                            }
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
                                  if (value?.isEmpty ?? true) {
                                    return '请选择可执行文件';
                                  }
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
                      
                      const SizedBox(height: 12),
                      
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
                      
                      const SizedBox(height: 16),
                      
                      // 命令参数配置
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '命令参数',
                            style: AppTextStyles.sectionTitle,
                          ),
                          ElevatedButton.icon(
                            onPressed: _addCommandParameter,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('添加参数', style: AppTextStyles.buttonNormal),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
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
                      
                      const SizedBox(height: 12),
                      
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
                ),
              ),
            ],
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
      
      final pluginConfig = PluginConfig(
        id: widget.editingPlugin?.id ?? const Uuid().v4(),
        name: _controllerName.text,
        description: _controllerDescription.text,
        type: _selectedType,
        icon: _selectedIcon,
        enabled: _enabled,
        commandConfig: commandConfig,
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
        padding: const EdgeInsets.all(12),
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
                    decoration: const InputDecoration(
                      labelText: '类型',
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                            fontSize: 12,
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
}