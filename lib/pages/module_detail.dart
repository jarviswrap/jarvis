import 'package:flutter/material.dart';
import '../widgets/grid_background.dart';
import '../widgets/gradient_button.dart';
import '../widgets/nav_bar.dart';
import 'abs/jarvis_page.dart';

class ModuleDetailPage extends JarvisPage {
  final String title;
  final String hint;
  final IconData iconData;
  final Color accent;

  const ModuleDetailPage({
    super.key,
    required this.title,
    required this.hint,
    required this.iconData,
    required this.accent,
  }): super(
          isRoot: false,
          title: title,
          accent: accent,
          actionsBuilder: _detailActions,
        );

  // 内页的右侧图标动作（按需扩展）
  static List<NavAction> _detailActions(BuildContext context) => const [
        NavAction(icon: Icons.settings, tooltip: '模块设置'),
        NavAction(icon: Icons.play_arrow, tooltip: '开始使用'),
      ];

  @override
  List<Widget> background(BuildContext context) => const [
        GridBackground(),
      ];

  @override
  Widget content(BuildContext context) {
    final muted = const Color(0xFFA7B0C0);

    return Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 28, 0), // 顶部空隙，避免与 NavBar 重叠
            child: ListView(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x0FFFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconData, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x1FFFFFFF)),
                        gradient: LinearGradient(colors: [accent.withOpacity(0.15), Colors.transparent]),
                      ),
                      child: Text(hint, style: TextStyle(color: muted)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '模块简介',
                  style: TextStyle(color: muted, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1FFFFFFF)),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
                    ),
                  ),
                  child: const Text(
                    '这里展示该模块的能力、示例与接入点。后续可接入工作流、设置、数据源等。',
                    style: TextStyle(fontSize: 14),
                  ),
                ),

                const SizedBox(height: 24),
                Text('近期规划', style: TextStyle(color: muted, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _chip('路由与页面结构'),
                    _chip('状态管理与数据'),
                    _chip('外部服务集成'),
                    _chip('快捷命令与自动化'),
                  ],
                ),

                const SizedBox(height: 24),
                Text('入口与操作', style: TextStyle(color: muted, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    GradientButton(
                      onPressed: () {},
                      colors: [accent, const Color(0xFF0EA5E9)],
                      child: const Text('打开示例'),
                    ),
                    GradientButton.ghost(onPressed: () {}, child: const Text('模块设置')),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        gradient: const LinearGradient(
          colors: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
        ),
      ),
      child: Text(text),
    );
  }
}