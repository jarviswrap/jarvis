import 'package:flutter/material.dart';

class AccentPalette {
  // 基础调色板（与当前首页风格一致）
  static const List<Color> base = [
    Color(0xFF60A5FA), // blue
    Color(0xFF34D399), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFF22D3EE), // cyan
    Color(0xFFEF4444), // red
    Color(0xFF14B8A6), // teal
    Color(0xFFF97316), // orange
  ];

  // 稳定哈希（FNV-1a 32-bit）
  static int _hashFNV1a(String s) {
    var hash = 0x811C9DC5;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * 0x1000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  // 通过 key 生成风格一致且稳定的 Accent 色
  static Color forKey(String key) {
    final h = _hashFNV1a(key);
    final baseIdx = h % base.length;
    final baseColor = base[baseIdx];
    final hsl = HSLColor.fromColor(baseColor);

    final hueJitter = ((h >> 8) % 13) - 6; // -6..+6°
    final satJitter = (((h >> 13) % 7) - 3) * 0.01; // -0.03..+0.03
    final lightJitter = (((h >> 17) % 5) - 2) * 0.02; // -0.04..+0.04

    final h2 = (hsl.hue + hueJitter) % 360;
    final s2 = (hsl.saturation + satJitter).clamp(0.62, 0.88).toDouble();
    final l2 = (hsl.lightness + lightJitter).clamp(0.45, 0.62).toDouble();

    return HSLColor.fromAHSL(hsl.alpha, h2, s2, l2).toColor();
  }

  // 可选：按序号生成均匀色（黄金角法），适合无 key 的序列
  static Color forIndex(int i) {
    final hue = (i * 137.508) % 360;
    return HSLColor.fromAHSL(1, hue, 0.75, 0.55).toColor();
  }
}