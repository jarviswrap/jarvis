import 'package:flutter/material.dart';
import '../utils/app_layout_config.dart';
import '../utils/app_text_styles.dart';

class CollapsibleSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? collapsedSummaryText;
  final List<Widget> children;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;
  final Color? iconColor;
  final double? childrenSpacing;
  final List<Widget> Function(bool expanded)? trailingBuilder;

  const CollapsibleSection({
    super.key,
    required this.icon,
    required this.title,
    this.collapsedSummaryText,
    required this.children,
    this.initiallyExpanded = true,
    this.onExpansionChanged,
    this.iconColor,
    this.childrenSpacing,
    this.trailingBuilder,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
    });
    widget.onExpansionChanged?.call(_expanded);
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: AppLayoutConfig.cardMargin,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppLayoutConfig.borderRadiusLarge,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _toggle,
            borderRadius: AppLayoutConfig.borderRadiusLarge,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: widget.iconColor ?? Colors.cyan.shade700),
                  const SizedBox(width: AppLayoutConfig.spacingMedium),
                  Text(widget.title, style: AppTextStyles.sectionTitle),
                  const SizedBox(width: AppLayoutConfig.spacingMedium),
                  Expanded(
                    child: (!_expanded && (widget.collapsedSummaryText?.isNotEmpty ?? false))
                        ? Text(
                            widget.collapsedSummaryText!,
                            style: AppTextStyles.bodySecondSmall.copyWith(color: Colors.grey.shade600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (widget.trailingBuilder != null) ...[
                    const SizedBox(width: AppLayoutConfig.spacingMedium),
                    ...widget.trailingBuilder!.call(_expanded),
                  ],
                  if (widget.trailingBuilder == null)
                    IconButton(
                      onPressed: _toggle,
                      tooltip: '展开/收起',
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      padding: const EdgeInsets.all(4),
                      icon: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 22,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => SizeTransition(sizeFactor: animation, child: child),
            child: _expanded
                ? Padding(
                    key: const ValueKey('expanded'),
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...(() {
                          final spacing = widget.childrenSpacing ?? 0;
                          final List<Widget> spaced = [];
                          for (int i = 0; i < widget.children.length; i++) {
                            spaced.add(widget.children[i]);
                            if (i < widget.children.length - 1) {
                              spaced.add(SizedBox(height: spacing));
                            }
                          }
                          return spaced;
                        }()),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('collapsed-empty')),
          ),
        ],
      ),
    );
  }
}