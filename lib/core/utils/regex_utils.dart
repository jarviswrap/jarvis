class RegexUtils {
  // 第一种方式：将源字符串按行处理，每行取首个匹配的 group(1)（或整个匹配）并用空格连接
  static String extractGroup1AcrossLines(String source, String pattern) {
    if (pattern.isEmpty) return source;
    try {
      final reg = RegExp(pattern);
      final tokens = <String>[];
      for (final line in source.split('\n')) {
        final m = reg.firstMatch(line);
        if (m != null) {
          String? token;
          if (m.groupCount >= 1) {
            token = m.group(1);
          }
          token ??= m.group(0);
          if (token != null && token.trim().isNotEmpty) {
            tokens.add(token.trim());
          }
        }
      }
      return tokens.isEmpty ? source : tokens.join(' ');
    } catch (_) {
      return source;
    }
  }

  // 第二种方式：每行收集所有 group，行内用空格连接，最后按行拼接（未在本次改动中使用）
  static String extractAllGroupsPerLine(String source, String pattern) {
    if (pattern.isEmpty) return source;
    try {
      final reg = RegExp(pattern);
      final outLines = <String>[];
      for (final line in source.split('\n')) {
        final pieces = <String>[];
        for (final m in reg.allMatches(line)) {
          if (m.groupCount > 0) {
            for (var i = 1; i <= m.groupCount; i++) {
              final g = m.group(i);
              if (g != null && g.trim().isNotEmpty) {
                pieces.add(g.trim());
              }
            }
          } else {
            final g0 = m.group(0);
            if (g0 != null && g0.trim().isNotEmpty) {
              pieces.add(g0.trim());
            }
          }
        }
        if (pieces.isNotEmpty) {
          outLines.add(pieces.join(' '));
        }
      }
      return outLines.isEmpty ? source : outLines.join('\n');
    } catch (_) {
      return source;
    }
  }
}