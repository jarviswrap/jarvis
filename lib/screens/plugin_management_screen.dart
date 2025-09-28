import 'package:flutter/material.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/plugin_system/icon_utils.dart';
import '../core/utils/app_text_styles.dart'; // 添加导入
import 'add_plugin_screen.dart';

class PluginManagementScreen extends StatefulWidget {
  const PluginManagementScreen({super.key});

  @override
  State<PluginManagementScreen> createState() => _PluginManagementScreenState();
}

class _PluginManagementScreenState extends State<PluginManagementScreen> {
  final PluginManager _pluginManager = PluginManager();

  @override
  Widget build(BuildContext context) {
    final pluginsByCategory = _pluginManager.getPluginsByCategory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Management', style: AppTextStyles.appBarTitle),
        actions: [
          IconButton(
            icon: IconUtils.getIconWidget('add', color: Colors.white),
            onPressed: () => _navigateToAddPlugin(),
          ),
        ],
      ),
      body: pluginsByCategory.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.extension_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无插件', style: AppTextStyles.bodyBold),
                ],
              ),
            )
          : ListView.builder(
              itemCount: pluginsByCategory.keys.length,
              itemBuilder: (context, index) {
                final category = pluginsByCategory.keys.elementAt(index);
                final plugins = pluginsByCategory[category]!;
                
                return ExpansionTile(
                  title: Text(
                    category,
                    style: AppTextStyles.sectionTitle,
                  ),
                  // subtitle: Text('${plugins.length} 个插件'),
                  initiallyExpanded: true,
                  // 去掉分割线
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: EdgeInsets.zero,
                  // 设置透明的分割线颜色
                  collapsedBackgroundColor: Colors.transparent,
                  backgroundColor: Colors.transparent,
                  // 去掉边框
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: plugins.map((plugin) => _buildPluginTile(plugin)).toList(),
                );
              },
            ),
    );
  }

  Widget _buildPluginTile(PluginConfig plugin) {
    final state = _pluginManager.getPluginState(plugin.id);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: plugin.enabled ? Colors.green : Colors.grey,
          child: Icon(
            IconUtils.getIcon(plugin.icon),
            color: Colors.white,
          ),
        ),
        title: Text(plugin.name, style: AppTextStyles.bodyBold),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plugin.description, style: AppTextStyles.bodySecondXSmall),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildStateChip(state),
                const SizedBox(width: 8),
                Chip(
                  label: Text(plugin.type.name, style: AppTextStyles.chipText),
                  backgroundColor: Colors.blue.shade100,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(value, plugin),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: plugin.enabled ? 'disable' : 'enable',
              child: Row(
                children: [
                  Icon(plugin.enabled ? Icons.pause : Icons.play_arrow),
                  const SizedBox(width: 8),
                  Text(plugin.enabled ? '禁用' : '启用', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('编辑', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (!_isDefaultPlugin(plugin.id))
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('删除', style: AppTextStyles.inputError),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStateChip(PluginLifecycleState state) {
    Color color;
    String label;
    
    switch (state) {
      case PluginLifecycleState.uninitialized:
        color = Colors.grey;
        label = '未初始化';
        break;
      case PluginLifecycleState.initializing:
        color = Colors.orange;
        label = '初始化中';
        break;
      case PluginLifecycleState.initialized:
        color = Colors.green;
        label = '已加载';
        break;
      case PluginLifecycleState.error:
        color = Colors.red;
        label = '错误';
        break;
      case PluginLifecycleState.disposed:
        color = Colors.grey;
        label = '已卸载';
        break;
    }
    
    return Chip(
      label: Text(label, style: AppTextStyles.chipText),
      backgroundColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: color, fontSize: 10),
    );
  }

  bool _isDefaultPlugin(String pluginId) {
    return pluginId.startsWith('shell_');
  }

  Future<void> _handleMenuAction(String action, PluginConfig plugin) async {
    switch (action) {
      case 'enable':
        await _pluginManager.enablePlugin(plugin.id);
        setState(() {});
        break;
      case 'disable':
        await _pluginManager.disablePlugin(plugin.id);
        setState(() {});
        break;
      case 'edit':
        await _navigateToEditPlugin(plugin);
        break;
      case 'delete':
        await _showDeleteConfirmation(plugin);
        break;
    }
  }

  Future<void> _navigateToAddPlugin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddPluginScreen(),
      ),
    );
    
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _navigateToEditPlugin(PluginConfig plugin) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPluginScreen(editingPlugin: plugin),
      ),
    );
    
    if (result == true) {
      setState(() {});
    }
  }

  Future<void> _showDeleteConfirmation(PluginConfig plugin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除', style: AppTextStyles.cardTitle),
        content: Text('确定要删除插件 "${plugin.name}" 吗？此操作不可撤销。', style: AppTextStyles.bodyNormal),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: AppTextStyles.buttonNormal),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除', style: AppTextStyles.inputError),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await _pluginManager.removePlugin(plugin.id);
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('插件 "${plugin.name}" 已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }
}