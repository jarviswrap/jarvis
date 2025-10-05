import 'package:flutter/material.dart';

class AppTextStyles {
  // 私有构造函数，防止实例化
  AppTextStyles._();

  // ========== 颜色定义 ==========
  static const Color primaryTextColor = Color(0xFF212121);      // 主要文字颜色
  static const Color secondaryTextColor = Color(0xFF757575);    // 次要文字颜色
  static const Color hintTextColor = Color(0xFF9E9E9E);         // 提示文字颜色
  static const Color errorTextColor = Color(0xFFD32F2F);        // 错误文字颜色
  static const Color successTextColor = Color(0xFF388E3C);      // 成功文字颜色
  static const Color warningTextColor = Color(0xFFF57C00);      // 警告文字颜色
  static const Color linkTextColor = Color(0xFF1976D2);         // 链接文字颜色
  static const Color disabledTextColor = Color(0xFFBDBDBD);     // 禁用文字颜色

  static const double inputFieldHeight = 38.0;

  // ========== 字体大小定义 ==========
  static const double fontSizeXLarge = 24.0;   // 超大标题
  static const double fontSizeLarge = 18.0;    // 大标题
  static const double fontSizeMedium = 16.0;   // 中等标题
  static const double fontSizeNormal = 14.0;   // 正文
  static const double fontSizeSmall = 12.0;    // 小字
  static const double fontSizeXSmall = 10.0;   // 超小字

  // 获取输入框装饰器
  static InputDecoration getInputDecoration(
    String labelText,
    String hintText, {
    VoidCallback? onTap,
    IconData? suffixIconData,
    Color? suffixIconColor,
    IconData? prefixIconData,
    bool isMultiline = false,
    Widget? suffixIconWidget, // 新增：支持传入自定义后缀组件
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      border: OutlineInputBorder(
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: Colors.blue.shade400,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isMultiline
            ? 8
            : ((suffixIconWidget != null || suffixIconData != null || prefixIconData != null) ? 0 : 13),
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIconData != null 
        ? Icon(
            prefixIconData,
            size: 16,
            color: Colors.grey.shade600,
          )
        : null,
      suffixIcon: onTap != null 
        ? GestureDetector(
            onTap: onTap,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              child: suffixIconWidget ?? Icon(
                suffixIconData ?? Icons.clear,
                size: 16,
                color: suffixIconColor ?? Colors.grey.shade600,
              ),
            ),
          )
        : null,
    );
  }

  // ========== 标题样式 ==========
  /// 页面主标题
  static const TextStyle pageTitle = TextStyle(
    fontSize: fontSizeXLarge,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 卡片标题
  static const TextStyle cardTitle = TextStyle(
    fontSize: fontSizeLarge,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 小节标题
  static const TextStyle sectionTitle = TextStyle(
    fontSize: fontSizeMedium,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 子标题
  static const TextStyle subtitle = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.w500,
    color: secondaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  // ========== 正文样式 ==========
  /// 正文 - 普通
  static const TextStyle bodyNormal = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 正文 - 加粗
  static const TextStyle bodyBold = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.w600,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 正文 - 次要
  static const TextStyle bodySecondary = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: secondaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 小字正文
  static const TextStyle bodySmall = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.normal,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  static const TextStyle bodySecondSmall = TextStyle(
    fontFamily: 'JetBrainsMono',
    fontSize: fontSizeSmall,
    color: Colors.grey,
  );
  
  static const TextStyle bodySecondXSmall = TextStyle(
    fontSize: fontSizeXSmall,
    fontWeight: FontWeight.normal,
    color: secondaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  // ========== 输入框相关样式 ==========
  /// 输入框文字
  static const TextStyle inputText = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 输入框标签
  static const TextStyle inputLabel = TextStyle(
    fontSize: fontSizeSmall + 1, // 13px
    fontWeight: FontWeight.normal,
    color: secondaryTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 输入框提示
  static const TextStyle inputHint = TextStyle(
    fontSize: fontSizeSmall + 1, // 13px
    fontWeight: FontWeight.normal,
    color: hintTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 输入框错误提示
  static const TextStyle inputError = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.normal,
    color: errorTextColor,
    fontFamily: 'JetBrainsMono',
  );

  // ========== 按钮样式 ==========
  /// 按钮文字 - 普通
  static const TextStyle buttonNormal = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.w500,
    fontFamily: 'JetBrainsMono',
  );

  /// 按钮文字 - 大按钮
  static const TextStyle buttonLarge = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    fontFamily: 'JetBrainsMono',
  );

  /// 按钮文字 - 小按钮
  static const TextStyle buttonSmall = TextStyle(
    fontSize: fontSizeXSmall + 1, // 11px
    fontWeight: FontWeight.w500,
    fontFamily: 'JetBrainsMono',
  );

  // ========== 特殊状态样式 ==========
  /// 错误文字
  static const TextStyle error = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: errorTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 成功文字
  static const TextStyle success = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: successTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 警告文字
  static const TextStyle warning = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: warningTextColor,
    fontFamily: 'JetBrainsMono',
  );

  /// 链接文字
  static const TextStyle link = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: linkTextColor,
    decoration: TextDecoration.underline,
    fontFamily: 'JetBrainsMono',
  );

  /// 禁用文字
  static const TextStyle disabled = TextStyle(
    fontSize: fontSizeNormal,
    fontWeight: FontWeight.normal,
    color: disabledTextColor,
    fontFamily: 'JetBrainsMono',
  );

  // ========== 代码/终端样式 ==========
  /// 代码文字
  static const TextStyle code = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.normal,
    color: primaryTextColor,
    fontFamily: 'JetBrainsMono',
    backgroundColor: Color(0xFFF5F5F5),
  );

  /// 终端输出
  static const TextStyle terminal = TextStyle(
    fontSize: fontSizeSmall,
    fontWeight: FontWeight.normal,
    color: Color(0xFF00FF00), // 绿色终端文字
    fontFamily: 'JetBrainsMono',
    backgroundColor: Color(0xFF000000),
  );

  // ========== 工具方法 ==========
  /// 创建自定义颜色的文字样式
  static TextStyle withColor(TextStyle baseStyle, Color color) {
    return baseStyle.copyWith(color: color);
  }

  /// 创建自定义大小的文字样式
  static TextStyle withSize(TextStyle baseStyle, double fontSize) {
    return baseStyle.copyWith(fontSize: fontSize);
  }

  /// 创建自定义粗细的文字样式
  static TextStyle withWeight(TextStyle baseStyle, FontWeight fontWeight) {
    return baseStyle.copyWith(fontWeight: fontWeight);
  }

  // 新增样式定义
  static const TextStyle appBarTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    fontFamily: 'JetBrainsMono',
  );

  // 新增AppBar主题配置方法
  static AppBarTheme getAppBarTheme(BuildContext context) {
    return AppBarTheme(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Colors.white,
      titleTextStyle: appBarTitle,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      elevation: 2,
      shadowColor: Colors.black26,
      centerTitle: false,
    );
  }

  // 创建统一的AppBar构建方法
  static AppBar buildAppBar({
    required String title,
    List<Widget>? actions,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    Color? backgroundColor,
  }) {
    return AppBar(
      title: Text(title, style: appBarTitle),
      backgroundColor: backgroundColor ?? Colors.cyan.shade700,
      foregroundColor: Colors.white,
      actions: actions,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      elevation: 2,
      shadowColor: Colors.black26,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    );
  }

  static const TextStyle headerTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle headerSubtitle = TextStyle(
    fontSize: 16,
    color: Colors.white70,
  );

  static const TextStyle listTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle listSubtitle = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  static const TextStyle chipText = TextStyle(
    fontSize: 10,
  );
}