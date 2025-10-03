import 'package:flutter/material.dart';

class AppSectionCard extends StatelessWidget {
  final bool hasShadow;
  final List<Widget> children;
  final bool singleChild;

  const AppSectionCard({
    super.key,
    required this.hasShadow,
    required this.children,
    this.singleChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(6),
      elevation: hasShadow ? 6 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: singleChild && children.isNotEmpty
          ? children.first
          : Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
    );
  }
}