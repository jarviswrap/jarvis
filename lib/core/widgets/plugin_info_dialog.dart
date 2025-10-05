import 'package:flutter/material.dart';
import '../plugin_system/plugin_models.dart';

class PluginInfoDialog extends StatelessWidget {
  final PluginConfig config;

  const PluginInfoDialog({super.key, required this.config});

  static Future<void> show({
    required BuildContext context,
    required PluginConfig config,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => PluginInfoDialog(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commandConfig = config.commandConfig;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.extension, color: Colors.cyan.shade700, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(config.name)),
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
              const Text('描述', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(config.description),
              const SizedBox(height: 16),
            ],
            if (commandConfig != null) ...[
              const Text('命令信息', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _CommandInfoBox(commandConfig: commandConfig),
              const SizedBox(height: 16),
            ],
            if (commandConfig?.parameters.isNotEmpty == true) ...[
              const Text('参数列表', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...commandConfig!.parameters.map(
                (param) => Padding(
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
                            Text(param.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                getParameterTypeLabel(param.type),
                                style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
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
                                  style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (param.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(param.description!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    );
  }
}

class _CommandInfoBox extends StatelessWidget {
  final CommandConfig commandConfig;
  const _CommandInfoBox({required this.commandConfig});

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.code, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text('命令: ${commandConfig.executableFile}', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (commandConfig.executableDir?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('工作目录: ${commandConfig.executableDir}', style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          if (commandConfig.parameters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('参数数量: ${commandConfig.parameters.length}'),
          ],
        ],
      ),
    );
  }
}