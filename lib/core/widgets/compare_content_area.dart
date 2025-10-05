import 'package:flutter/material.dart';
import '../utils/app_text_styles.dart';
import 'common_components.dart';

class CompareContentArea extends StatefulWidget {
  final String left;
  final String right;

  const CompareContentArea({
    super.key,
    required this.left,
    required this.right,
  });

  @override
  State<CompareContentArea> createState() => _CompareContentAreaState();
}

class _CompareContentAreaState extends State<CompareContentArea> {
  // 左右文本
  late List<String> _leftLines = widget.left.split('\n');
  late List<String> _rightLines = widget.right.split('\n');

  // 控制器与状态
  final ScrollController _leftCtrl = ScrollController();
  final ScrollController _rightCtrl = ScrollController();

  bool _leftUserScroll = false;
  bool _rightUserScroll = false;
  bool _isSyncing = false;        // 程序化滚动标记，避免循环
  bool _syncScheduled = false;    // 帧末调度标记

  static const double _fontSize = 12;
  static const double _lineHeightMultiplier = 1.4;

  @override
  void initState() {
    super.initState();
    _leftCtrl.addListener(_onLeftScroll);
    _rightCtrl.addListener(_onRightScroll);
  }

  @override
  void didUpdateWidget(covariant CompareContentArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.left != widget.left) {
      _leftLines = widget.left.split('\n');
    }
    if (oldWidget.right != widget.right) {
      _rightLines = widget.right.split('\n');
    }
  }

  @override
  void dispose() {
    _leftCtrl.removeListener(_onLeftScroll);
    _rightCtrl.removeListener(_onRightScroll);
    _leftCtrl.dispose();
    _rightCtrl.dispose();
    super.dispose();
  }

  void _onLeftScroll() {
    if (_isSyncing || !_leftUserScroll) return;
    _scheduleSync(() => _syncRightToLeft());
  }

  void _onRightScroll() {
    if (_isSyncing || !_rightUserScroll) return;
    _scheduleSync(() => _syncLeftToRight());
  }

  // 帧末统一执行，避免布局阶段重入
  void _scheduleSync(VoidCallback task) {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      _isSyncing = true;
      try {
        task();
      } finally {
        _isSyncing = false;
      }
    });
  }

  // 左侧滚动，右侧按比例同步
  void _syncRightToLeft() {
    if (!_leftCtrl.hasClients || !_rightCtrl.hasClients) return;
    final double leftMax = _leftCtrl.position.maxScrollExtent;
    final double rightMax = _rightCtrl.position.maxScrollExtent;
    final double t = leftMax <= 0 ? 0 : (_leftCtrl.offset / leftMax).clamp(0.0, 1.0);
    final double target = t * rightMax;
    if ((target - _rightCtrl.offset).abs() < 0.5) return;
    _rightCtrl.jumpTo(target);
  }

  // 右侧滚动，左侧按比例同步
  void _syncLeftToRight() {
    if (!_leftCtrl.hasClients || !_rightCtrl.hasClients) return;
    final double leftMax = _leftCtrl.position.maxScrollExtent;
    final double rightMax = _rightCtrl.position.maxScrollExtent;
    final double t = rightMax <= 0 ? 0 : (_rightCtrl.offset / rightMax).clamp(0.0, 1.0);
    final double target = t * leftMax;
    if ((target - _leftCtrl.offset).abs() < 0.5) return;
    _leftCtrl.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    // 新增：使用 codeBlock 渲染，并保留滚动联动
    Widget buildCode(String content, ScrollController controller, {required bool isLeft}) {
      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (_isSyncing) return false;
          if (n is ScrollStartNotification && n.dragDetails != null) {
            if (isLeft) {
              _leftUserScroll = true;
            } else {
              _rightUserScroll = true;
            }
          } else if (n is ScrollUpdateNotification && n.dragDetails != null) {
            if (isLeft) {
              _onLeftScroll();
            } else {
              _onRightScroll();
            }
          } else if (n is ScrollEndNotification) {
            if (isLeft) {
              _leftUserScroll = false;
            } else {
              _rightUserScroll = false;
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          controller: controller,
          primary: false,
          child: CommonComponents.codeBlock(
            content,
            emptyHint: '无内容',
            // 设定较大的 maxLines 以完整展示并允许滚动
            minLines: 12,
            maxLines: 100000,
          ),
        ),
      );
    }

    final double maxHeight = MediaQuery.of(context).size.height * 0.65;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: buildCode(widget.left, _leftCtrl, isLeft: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: buildCode(widget.right, _rightCtrl, isLeft: false),
          ),
        ],
      ),
    );
  }
}