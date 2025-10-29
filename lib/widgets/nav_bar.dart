import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 顶部增加一个公共常量，供 page_frame 复用
const double kNavBarHeight = 52;

class NavAction {
  final IconData icon;
  final String? tooltip;
  final FutureOr<void> Function()? onPressed;

  const NavAction({required this.icon, this.tooltip, this.onPressed});
}

class NavBar extends StatelessWidget {
  final String? title;
  final Color accent;
  final List<NavAction> actions;
  final VoidCallback? onBack;
  final bool isRoot;

  const NavBar.root({
    super.key,
    this.title,
    required this.accent,
    this.actions = const [],
  })  : onBack = null,
        isRoot = true;

  const NavBar.page({
    super.key,
    required this.title,
    required this.accent,
    this.actions = const [],
    required this.onBack,
  }) : isRoot = false;

  @override
  Widget build(BuildContext context) {
    const muted =  Color(0xFFA7B0C0);

    return SafeArea(
      top: true,
      bottom: false,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: kNavBarHeight, // 使用公共常量
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  accent.withOpacity(0.14),
                  const Color(0x0D0A0B12),
                  Colors.transparent,
                ],
              ),
            ),
            child: Row(
              children: [
                // 左侧：root 模式显示品牌；page 模式显示返回+标题
                if (isRoot)
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accent.withOpacity(0.6), accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: accent.withOpacity(0.5), blurRadius: 12, spreadRadius: 1),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('Jarvis', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      const SizedBox(width: 6),
                      const Text('Smart Work OS', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w400)),
                    ],
                  )
                else
                  Row(
                    children: [
                      // IconButton(
                      //   onPressed: onBack,
                      //   icon: const Icon(Icons.arrow_back_ios_sharp),
                      //   tooltip: '返回',
                      // ),
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: _NavIconButton(a: NavAction(icon: Icons.arrow_back_ios_sharp, tooltip: '返回', onPressed: onBack)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                const Spacer(),
                // 右侧：图标按钮列表
                Row(
                  children: actions
                      .map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _NavIconButton(a: a),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatefulWidget {
  final NavAction a;
  const _NavIconButton({required this.a});

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (widget.a.onPressed == null || _loading) return;

    final result = widget.a.onPressed!();
    
    // 如果返回 Future，显示加载状态
    if (result is Future) {
      setState(() {
        _loading = true;
      });
      
      try {
        await result;
      } finally {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: _loading ? null : _handleTap,
        radius: 20,
        highlightColor: Colors.white10,
        hoverColor: Colors.white10,
        child: Tooltip(
          message: widget.a.tooltip ?? '',
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
              ),
            ),
            child: Center(
              child: _loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    )
                  : Icon(widget.a.icon, size: 18),
            ),
          ),
        ),
      ),
    );
  }
}