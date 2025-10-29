import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GradientButton({
    super.key,
    required this.child,
    this.onPressed,
    this.colors = const [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  });

  static GradientButton ghost({
    Key? key,
    required Widget child,
    VoidCallback? onPressed,
    double borderRadius = 10,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
  }) {
    return GradientButton(
      key: key,
      child: child,
      onPressed: onPressed,
      colors: const [Colors.transparent, Colors.transparent],
      borderRadius: borderRadius,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: const Color(0x1FFFFFFF));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: padding,
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(colors: colors),
            boxShadow: colors.first.opacity > 0
                ? const [
                    BoxShadow(color: Color(0x590EA5E9), blurRadius: 20, offset: Offset(0, 8)),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}