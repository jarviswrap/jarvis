import 'package:flutter/material.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/nav_bar.dart';

abstract class JarvisPage extends StatelessWidget {
  final Color accent;
  final String? title;
  final bool isRoot;
  final VoidCallback? onBack;
  final List<NavAction> Function(BuildContext) actionsBuilder;

  const JarvisPage({
    super.key,
    required this.accent,
    this.title,
    this.isRoot = false,
    this.onBack,
    this.actionsBuilder = _emptyActions,
  });

  static List<NavAction> _emptyActions(BuildContext _) => const [];

  // 子类提供背景层（网格/极光等）
  List<Widget> background(BuildContext context) => const [GridBackground()];

  // 子类提供主体内容（滚动区/网格卡片等）
  Widget content(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      // 背景层
      ...background(context),
      // 内容层：默认 Column 包装，插入与 Navbar 等高的占位，避免遮挡
      Column(
        children: [
          const SizedBox(height: kNavBarHeight),
          Expanded(child: content(context)),
        ],
      ),
      // 悬浮 Navbar（始终作为 Stack 最后一个元素）
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: isRoot
            ? NavBar.root(
                accent: accent,
                actions: actionsBuilder(context),
              )
            : NavBar.page(
                title: title ?? '',
                accent: accent,
                onBack: onBack ?? () => Navigator.of(context).maybePop(),
                actions: actionsBuilder(context),
              ),
      ),
    ];

    return Scaffold(body: Stack(children: children));
  }
}