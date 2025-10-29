import 'package:flutter/material.dart';
import 'package:jarvis/core/logger.dart';
/// 构造用于匹配“单词集合”的正则表达式。
/// - 适用于：关键字、类型名、布尔字面量等由字母数字组成的词。
/// - `wordBoundary`：是否添加单词边界（`\b`），默认 true，避免命中子串。
/// - `caseSensitive`：大小写敏感，默认 true。
/// 例：wordSetPattern({'if','else'}) => 匹配独立出现的 if 或 else。
RegExp wordSetPattern(
  Set<String> words, {
  bool wordBoundary = true,
  bool caseSensitive = true,
}) {
  final group = words.map(RegExp.escape).join('|');
  final pattern = wordBoundary ? r'\b(?:' + group + r')\b' : '(?:$group)';
  return RegExp(pattern, caseSensitive: caseSensitive);
}

/// 构造用于匹配“操作符集合”的正则表达式。
/// - 适用于：`+`, `-`, `*`, `/`, `==`, `!=`, `->` 等符号序列。
/// - 不使用单词边界；全部转义后用分支合并，避免元字符误用。
/// - `caseSensitive`：大小写敏感，默认 true（一般对符号无影响）。
RegExp operatorSetPattern(Set<String> ops, {bool caseSensitive = true}) {
  final group = ops.map(RegExp.escape).join('|');
  return RegExp('(?:$group)', caseSensitive: caseSensitive);
}

/// 构造用于匹配“行注释起始符至行尾”的正则表达式。
/// - 适用于：`# ...`, `// ...` 等单行注释模式。
/// - 自动转义起始符并匹配到 `$`（行尾）。
/// 例如：commentLineStartPattern('#') => 匹配 # 开头的行注释。
RegExp commentLineStartPattern(String start) {
  return RegExp('${RegExp.escape(start)}.*\$');
}

/// 构造用于匹配“十进制数字（整数/小数）”的正则表达式。
/// - 例：`123`、`3.14`。
RegExp numberDecimalPattern() => RegExp(r'\b\d+(?:\.\d+)?\b');

/// 构造用于匹配“十六进制数字”的正则表达式。
/// - 例：`0xFF`、`0x1a2b`。
RegExp numberHexPattern() => RegExp(r'\b0x[0-9A-Fa-f]+\b');

/// 构造用于匹配“双引号字符串”的正则表达式。
/// - 支持转义：如 `\"`、`\\`。
RegExp stringDoublePattern() => RegExp(r'"(?:[^"\\]|\\.)*"');

/// 构造用于匹配“单引号字符串”的正则表达式。
/// - 支持转义：如 `\'`、`\\`。
RegExp stringSinglePattern() => RegExp(r"'(?:[^'\\]|\\.)*'");

/// 构造用于匹配“标识符”的正则表达式。
/// - 规则：以字母或下划线开头，后续为字母/数字/下划线（`\w`）。
/// - `reservedWords`：可选保留字集合，使用负向前瞻排除这些词。
///   例：identifierPattern(reservedWords: {'if','else'}) 不会匹配 if/else。
RegExp identifierPattern({Set<String>? reservedWords}) {
  if (reservedWords == null || reservedWords.isEmpty) {
    return RegExp(r'\b[A-Za-z_]\w*\b');
  }
  final reservedGroup = reservedWords.map(RegExp.escape).join('|');
  return RegExp(r'\b(?!' + reservedGroup + r'\b)[A-Za-z_]\w*\b');
}
Map<RegExp, TextStyle> buildPatternMapFromRegexColors(
  Map<RegExp, Color> colorMap,
  TextStyle baseStyle,
) {
  final pm = <RegExp, TextStyle>{};
  colorMap.forEach((re, color) {
    pm[re] = baseStyle.copyWith(color: color);
  });
  return pm;
}

class CodeViewer extends StatefulWidget {
  final String text;
  final TextStyle? codeStyle;
  final TextStyle? lineNumberStyle;
  final bool wrap;
  final Color? background;
  final Color? gutterBackground;
  final EdgeInsets padding;
  final EdgeInsets gutterPadding;
  final double gutterMinWidth;
  final double gutterMaxWidth;
  final Map<RegExp, Color>? highlightMap;

  const CodeViewer({
    super.key,
    required this.text,
    this.codeStyle,
    this.lineNumberStyle,
    this.highlightMap,
    this.wrap = true,
    this.background,
    this.gutterBackground,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    this.gutterPadding = const EdgeInsets.all(8),
    this.gutterMinWidth = 20.0,
    this.gutterMaxWidth = 96.0,
  });

  @override
  State<CodeViewer> createState() => _CodeViewerState();
}

class _CodeViewerState extends State<CodeViewer> {
  final ScrollController _codeScrollController = ScrollController();
  final ScrollController _gutterScrollController = ScrollController();
  final baseTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 12,
      height: 1.4,
    );

  bool _syncing = false;

  // 新增：内部可编辑控制器（语法高亮）
  late final SyntaxHighlightController _controller;

  // 文本变化时触发布局更新（行号与内容保持同步）
  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // 仅使用外部传入的高亮映射；未提供或为空则不高亮
    Map<RegExp, TextStyle>? pm;
    if (widget.highlightMap != null && widget.highlightMap!.isNotEmpty) {
      pm = buildPatternMapFromRegexColors(widget.highlightMap!, baseTextStyle);
    }

    _controller = SyntaxHighlightController(text: widget.text, patternMap: pm);
    // 监听文本变化用于更新行号区域
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CodeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部传入文本变化时，同步到内部控制器
    if (widget.text != oldWidget.text && _controller.text != widget.text) {
      final len = widget.text.length;
      final prevSel = _controller.selection;
      _controller.text = widget.text;
      // 尽量保留选择位置
      _controller.selection = TextSelection(
        baseOffset: prevSel.baseOffset.clamp(0, len),
        extentOffset: prevSel.extentOffset.clamp(0, len),
      );
    }
    // 高亮规则引用变化时，基于当前样式重建 patternMap
    if (widget.highlightMap != oldWidget.highlightMap) {
      final theme = Theme.of(context);
      final textStyle = widget.codeStyle ??
          theme.textTheme.bodyMedium!.copyWith(
            fontFamily: baseTextStyle.fontFamily,
            fontSize: baseTextStyle.fontSize,
            height: baseTextStyle.height,
          );
      final pm = (widget.highlightMap != null && widget.highlightMap!.isNotEmpty)
          ? buildPatternMapFromRegexColors(widget.highlightMap!, textStyle)
          : null;
      _controller.updatePatternMap(pm);
    }
  }

  @override
  void dispose() {
    _codeScrollController.dispose();
    _gutterScrollController.dispose();
    // 移除监听，避免内存泄漏
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.codeStyle ??
        theme.textTheme.bodyMedium!.copyWith(
          fontFamily: baseTextStyle.fontFamily,
          fontSize: baseTextStyle.fontSize,
          height: baseTextStyle.height,
        );

    // 始终用当前 textStyle 生成高亮映射，保证样式一致
    if (widget.highlightMap != null && widget.highlightMap!.isNotEmpty) {
      final pm =
          buildPatternMapFromRegexColors(widget.highlightMap!, textStyle);
      _controller.updatePatternMap(pm);
    } else {
      _controller.updatePatternMap(null);
    }

    final gutterTextStyle = widget.lineNumberStyle ??
        textStyle.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );

    final bgColor = widget.background ?? theme.colorScheme.surface;
    final gutterBgColor =
        widget.gutterBackground ?? Colors.transparent;

    // 使用内部控制器的文本
    final fullText = _controller.text;
    final lines = fullText.split('\n');
    final digits = lines.length.toString().length;

    return LayoutBuilder(builder: (context, constraints) {
      // 动态测量行号栏宽度
      final measureTP = TextPainter(
        text: TextSpan(text: '9' * digits, style: gutterTextStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        strutStyle: StrutStyle(
          fontSize: textStyle.fontSize,
          height: textStyle.height,
          fontFamily: textStyle.fontFamily,
        ),
      )..layout();
      final measuredWidth =
          measureTP.size.width + widget.gutterPadding.horizontal;
      final gutterWidth = measuredWidth.clamp(
        widget.gutterMinWidth,
        widget.gutterMaxWidth,
      );

      // 可用于代码内容的宽度（与 TextField 的 padding 保持一致）
      final contentWidth =
          constraints.maxWidth - gutterWidth - widget.padding.horizontal;

      // 逐逻辑行测量高度（聚合自动换行）
      final List<double> lineHeights = List.filled(lines.length, 0);
      final List<double> firstLineHeight = List.filled(lines.length, 0);
      for (int i = 0; i < lines.length; i++) {
        final tp = TextPainter(
          text: TextSpan(text: lines[i], style: textStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          maxLines: widget.wrap ? null : 1,
          ellipsis: widget.wrap ? null : '…',
          strutStyle: StrutStyle(
            fontSize: textStyle.fontSize,
            height: textStyle.height,
            fontFamily: textStyle.fontFamily,
          ),
        )..layout(maxWidth: contentWidth > 0 ? contentWidth : 0.0);

        final metrics = tp.computeLineMetrics();
        if (metrics.isEmpty) {
          // 用首选行高兜底，保证与 TextField 光标一致
          final emptyTP = TextPainter(
            text: const TextSpan(text: '0'),
            textDirection: TextDirection.ltr,
            maxLines: 1,
            strutStyle: StrutStyle(
              fontSize: textStyle.fontSize,
              height: textStyle.height,
              fontFamily: textStyle.fontFamily,
            ),
          )..layout();
          final preferred = emptyTP.preferredLineHeight;
          lineHeights[i] = preferred;
          firstLineHeight[i] = preferred;
          appLogger.info('lineH1 $i height: $preferred, first: ${tp.preferredLineHeight}');
        } else {
          double total = 0;
          for (final m in metrics) {
            total += m.height;
          }
          lineHeights[i] = total;
          // 首行高度使用 preferredLineHeight，与 TextField 光标一致
          firstLineHeight[i] = tp.preferredLineHeight;
          appLogger.info('lineH2 $i height: $total, first: ${tp.preferredLineHeight}');
        }
      }

      final dpr = MediaQuery.of(context).devicePixelRatio;
      double _roundToPixel(double v) => (v * dpr).roundToDouble() / dpr;

      return Container(
        color: bgColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 行号区
            Container(
              width: gutterWidth,
              color: gutterBgColor,
              child: ListView.builder(
                controller: _gutterScrollController,
                physics: const NeverScrollableScrollPhysics(),
                padding: widget.gutterPadding,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final height = _roundToPixel(lineHeights[index]);
                  final firstHeight = _roundToPixel(firstLineHeight[index]);
                  return SizedBox(
                    height: height,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: SizedBox(
                        height: firstHeight,
                        child: Text(
                          '${index + 1}',
                          style: gutterTextStyle,
                          strutStyle: StrutStyle(
                            fontSize: textStyle.fontSize,
                            height: textStyle.height,
                            fontFamily: textStyle.fontFamily,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 代码区（TextField + 内部高亮控制器）
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification &&
                      notification.metrics.axis == Axis.vertical &&
                      _gutterScrollController.hasClients &&
                      !_syncing) {
                    _syncing = true;
                    final target = _roundToPixel(notification.metrics.pixels);
                    final max = _gutterScrollController.position.maxScrollExtent;
                    _gutterScrollController.jumpTo(target.clamp(0.0, max));
                    _syncing = false;
                  }
                  return false;
                },
                child: TextField(
                  controller: _controller,
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.top,
                  focusNode: FocusNode(),
                  readOnly: false,
                  maxLines: null,
                  expands: true,
                  scrollController: _codeScrollController,
                  style: textStyle,
                  strutStyle: StrutStyle(
                    fontSize: textStyle.fontSize,
                    height: textStyle.height,
                    fontFamily: textStyle.fontFamily,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: widget.padding,
                    fillColor: bgColor,
                    filled: true,
                  ),
                  cursorColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// 自定义：Regex 高亮控制器（不依赖 CodeField）
class SyntaxHighlightController extends TextEditingController {
  Map<RegExp, TextStyle>? patternMap;

  SyntaxHighlightController({
    super.text,
    this.patternMap,
  });

  /// 更新高亮规则映射
  void updatePatternMap(Map<RegExp, TextStyle>? newPatternMap) {
    patternMap = newPatternMap;
    notifyListeners(); // 触发重绘
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final s = text;
    if (s.isEmpty) return TextSpan(text: '', style: style);

    final spans = <TextSpan>[];
    final lines = s.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      spans.add(_buildLineSpan(line, style));
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: style));
      }
    }
    return TextSpan(children: spans, style: style);
  }

  TextSpan _buildLineSpan(String line, TextStyle? style) {
    if (line.isEmpty) return TextSpan(text: '', style: style);

    // 若无任何规则，直接返回普通样式
    if (patternMap == null || patternMap!.isEmpty) {
      return TextSpan(text: line, style: style);
    }

    // 收集所有匹配区间（按插入顺序保持优先级）
    final ranges = <_Range>[];
    int precedence = 0;
    patternMap!.forEach((pattern, ts) {
      for (final m in pattern.allMatches(line)) {
        ranges.add(_Range(m.start, m.end, ts, precedence));
      }
      precedence++;
    });

    ranges.sort((a, b) {
      final c = a.start.compareTo(b.start);
      if (c != 0) return c;
      // 同起点优先更长；再优先低 precedence（早插入）
      final l = (b.end - b.start).compareTo(a.end - a.start);
      if (l != 0) return l;
      return a.precedence.compareTo(b.precedence);
    });

    final children = <TextSpan>[];
    int pos = 0;
    for (final r in ranges) {
      if (r.start < pos) continue; // 重叠/覆盖跳过
      if (r.start > pos) {
        children.add(TextSpan(text: line.substring(pos, r.start), style: style));
      }
      children.add(TextSpan(text: line.substring(r.start, r.end), style: r.style ?? style));
      pos = r.end;
    }
    if (pos < line.length) {
      children.add(TextSpan(text: line.substring(pos), style: style));
    }
    return TextSpan(children: children, style: style);
  }
}

class _Range {
  final int start;
  final int end;
  final TextStyle? style;
  final int precedence;
  _Range(this.start, this.end, this.style, this.precedence);
}