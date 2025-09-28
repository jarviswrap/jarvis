import 'package:flutter/material.dart';

class WhiteIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const WhiteIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? Colors.white,
    );
  }
}