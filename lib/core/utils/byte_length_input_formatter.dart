import 'dart:convert';
import 'package:flutter/services.dart';

class ByteLimitFormatter extends TextInputFormatter {
  final int maxBytes;
  const ByteLimitFormatter(this.maxBytes);

  static String truncateUtf8(String input, int maxBytes) {
    final sb = StringBuffer();
    int count = 0;
    for (final codePoint in input.runes) {
      final len = utf8.encode(String.fromCharCode(codePoint)).length;
      if (count + len > maxBytes) break;
      sb.writeCharCode(codePoint);
      count += len;
    }
    return sb.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final bytesLen = utf8.encode(newValue.text).length;
    if (bytesLen <= maxBytes) return newValue;
    final truncated = truncateUtf8(newValue.text, maxBytes);
    final selOffset = truncated.length <= newValue.selection.baseOffset
        ? truncated.length
        : newValue.selection.baseOffset;
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: selOffset),
      composing: TextRange.empty,
    );
  }
}