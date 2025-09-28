import 'package:flutter/material.dart';
import '../widgets/white_icon.dart';

class IconUtils {
  static const Map<String, IconData> _iconMap = {
    'terminal': Icons.terminal,
    'code': Icons.code,
    'settings': Icons.settings,
    'computer': Icons.computer,
    'developer_board': Icons.developer_board,
    'extension': Icons.extension,
    'folder': Icons.folder,
    'file_copy': Icons.file_copy,
    'build': Icons.build,
    'bug_report': Icons.bug_report,
    'storage': Icons.storage,
    'cloud': Icons.cloud,
    'network_check': Icons.network_check,
    'security': Icons.security,
    'dashboard': Icons.dashboard,
    'analytics': Icons.analytics,
    'smart_toy': Icons.smart_toy,
    'error_outline': Icons.error_outline,
    'check_circle': Icons.check_circle,
    'extension_off': Icons.extension_off,
    'refresh': Icons.refresh,
    'add': Icons.add,
    'keyboard_arrow_up': Icons.keyboard_arrow_up,
    'keyboard_arrow_down': Icons.keyboard_arrow_down,
    'note_add': Icons.note_add,
    'web': Icons.web,
    // 可以根据需要添加更多图标
  };

  /// 通过字符串获取对应的 IconData
  static IconData getIcon(String iconName) {
    return _iconMap[iconName] ?? Icons.extension; // 默认图标
  }

  static Widget getIconWidget(String iconName, {double? size, Color? color}) {
    final iconData = _iconMap[iconName] ?? Icons.extension;
    return WhiteIcon(
      iconData,
      size: size,
      color: color, // 如果传入color则使用传入的颜色，否则WhiteIcon会使用白色
    );
  }

  /// 获取所有可用的图标名称
  static List<String> getAvailableIconNames() {
    return _iconMap.keys.toList();
  }

  /// 检查图标名称是否存在
  static bool hasIcon(String iconName) {
    return _iconMap.containsKey(iconName);
  }
}