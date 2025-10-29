import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark() {
    // 颜色系统：主色、辅色、背景、容器、弱化文字、边框
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: Color(0xFF1D4ED8),        // 主按钮/强调（blue）
      secondary: Color(0xFF0EA5E9),      // 辅助强调（cyan）
      background: Color(0xFF0F172A),     // 背景（slate 900）
      surface: Color(0xFF0B1220),        // 顶栏/卡片深色容器
      onBackground: Color(0xFFE6EAF2),   // 正文主文本
      onSurface: Color(0xFFE6EAF2),      // 容器中的主文本
      onSurfaceVariant: Color(0xFFA7B0C0), // 弱化文本（副文/提示）
      outline: Color(0x1FFFFFFF),        // 细边框/分隔线
    );

    // 字体系统：统一字号层级
    final baseText = GoogleFonts.spaceGroteskTextTheme(
      ThemeData.dark().textTheme,
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    final textTheme = baseText.copyWith(
      displayLarge: baseText.displayLarge?.copyWith(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      displayMedium: baseText.displayMedium?.copyWith(fontSize: 48, fontWeight: FontWeight.w700),
      headlineLarge: baseText.headlineLarge?.copyWith(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: baseText.headlineMedium?.copyWith(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: baseText.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w500),
      bodyLarge: baseText.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
      bodyMedium: baseText.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: baseText.bodySmall?.copyWith(fontSize: 12),
      labelLarge: baseText.labelLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.background,
      dividerColor: colorScheme.outline,
      // 全局按钮风格
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          hoverColor: colorScheme.onSurface.withOpacity(0.08),
        ),
      ),
      // 输入框与列表分隔符
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary),
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      dividerTheme: DividerThemeData(color: colorScheme.outline, thickness: 1),
    );
  }
}