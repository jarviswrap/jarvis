import 'package:flutter/material.dart';
import '../../widgets/grid_background.dart';
import '../../widgets/nav_bar.dart';

typedef ActionsBuilder = List<NavAction> Function(BuildContext);

abstract class JarvisStateful extends StatefulWidget {
  final Color accent;
  final String? title;
  final bool isRoot;
  final VoidCallback? onBack;
  final ActionsBuilder actionsBuilder;

  const JarvisStateful({
    super.key,
    required this.accent,
    this.title,
    this.isRoot = false,
    this.onBack,
    this.actionsBuilder = _emptyActions,
  });

  static List<NavAction> _emptyActions(BuildContext _) => const [];
}

/// 抽象基类的 State：
/// - 背景层可覆盖（默认 GridBackground）
/// - 内容层为抽象（子类必须实现）
/// - 悬浮 NavBar 与占位避免遮挡，结构与 JarvisPage 保持一致
abstract class JarvisStatefulState<T extends JarvisStateful> extends State<T> {
  /// 子类可覆盖背景层（例如加入极光效果）
  List<Widget> background(BuildContext context) => const [GridBackground()];

  /// 子类必须提供主体内容（滚动区/网格卡片等）
  Widget content(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      // 背景层
      ...background(context),
      // 内容层：默认 Column 包装，插入与 Navbar 等高的占位，避免遮挡
      const Column(
        children: [
          SizedBox(height: kNavBarHeight),
        ],
      ),
      // 使用 Expanded 包裹主体内容
      Positioned.fill(
        top: kNavBarHeight,
        child: content(context),
      ),
      // 悬浮 Navbar（始终作为 Stack 最后一个元素）
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Builder(
          builder: (builderContext) => widget.isRoot
              ? NavBar.root(
                  accent: widget.accent,
                  actions: widget.actionsBuilder(builderContext),
                )
              : NavBar.page(
                  title: widget.title ?? '',
                  accent: widget.accent,
                  onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
                  actions: widget.actionsBuilder(builderContext),
                ),
        ),
      ),
    ];

    return Scaffold(body: Stack(children: children));
  }
}