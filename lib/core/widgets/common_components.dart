import 'package:flutter/material.dart';

class CommonComponents {
  static Widget codeBlock(
    String content, {
    String? emptyHint,
    Color background = Colors.black87,
    Color textColor = Colors.white,
    int minLines = 2,
    int maxLines = 5,
  }) {
    final isEmpty = content.isEmpty;
    final displayText = isEmpty ? (emptyHint ?? '') : content;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        displayText,
        style: TextStyle(
          color: isEmpty ? Colors.grey.shade400 : textColor,
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
        ),
        maxLines: maxLines,
        minLines: minLines,
      ),
    );
  }

  static ButtonStyle getButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.cyan.shade700,
      foregroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: const Size(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}