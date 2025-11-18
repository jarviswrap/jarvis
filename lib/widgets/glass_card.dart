import 'package:flutter/material.dart';

class GlassCard extends StatefulWidget {
  final String title;
  final String hint;
  final String status;
  final IconData iconData;
  final Color accent;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.title,
    required this.hint,
    required this.iconData,
    required this.accent,
    this.status = '',
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    const textColor = const Color(0xFFE6EAF2);
    const muted = const Color(0xFFA7B0C0);

    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.identity()..translate(0.0, hovered ? -4.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x1FFFFFFF)),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
            ),
            // 修复：Flutter 的 BoxShadow 没有 inset 参数
            boxShadow: hovered
                ? [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                    const BoxShadow(
                      color: Color(0x0FFFFFFF),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(18),
          // 添加：用叠层渐变模拟“内阴影/高光”
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // 内高光叠层（可调透明度与方向）
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(hovered ? 0.08 : 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: const Color(0x0FFFFFFF),
                            borderRadius: BorderRadius.circular(10),
                            // 修复：移除无效的 inset
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x10FFFFFF),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Icon(widget.iconData, color: textColor),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.hint, style: TextStyle(color: muted, fontSize: 13)),
                    const Spacer(),
                    Text(widget.status, style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}