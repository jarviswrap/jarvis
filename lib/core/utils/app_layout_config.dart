import 'package:flutter/material.dart';

/// 应用布局配置类
/// 统一管理应用中的padding、margin、spacing等布局相关配置
class AppLayoutConfig {
  // 私有构造函数，防止实例化
  AppLayoutConfig._();

    // ========== 圆角配置 ==========
  /// 小圆角
  static const double radiusSmall = 4.0;
  
  /// 中等圆角
  static const double radiusMedium = 6.0;
  
  /// 大圆角
  static const double radiusLarge = 8.0;
  
  /// 超大圆角
  static const double radiusXLarge = 12.0;

  static const double pagePaddingValue = 10.0;

  // ========== Card相关配置 ==========
  /// Card内部padding
  static const EdgeInsets cardPadding = EdgeInsets.all(6);
  
  /// Card外部margin
  static const EdgeInsets cardMargin = EdgeInsets.all(6);
  
  /// 大Card内部padding（用于主要内容区域）
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(16);
  
  /// 中等Card内部padding（用于次要内容区域）
  static const EdgeInsets cardPaddingMedium = EdgeInsets.all(12);
  
  /// 小Card内部padding（用于紧凑内容区域）
  static const EdgeInsets cardPaddingSmall = EdgeInsets.all(8);

  // ========== 页面布局配置 ==========
  /// 页面内容padding
  static const EdgeInsets pagePadding = EdgeInsets.all(pagePaddingValue);
  
  /// 页面内容margin
  static const EdgeInsets pageMargin = EdgeInsets.all(16);

  // ========== 组件间距配置 ==========
  /// 小间距
  static const double spacingSmall = 4.0;
  
  /// 中等间距
  static const double spacingMedium = 8.0;
  
  /// 大间距
  static const double spacingLarge = 12.0;
  
  /// 超大间距
  static const double spacingXLarge = 16.0;
  
  /// 超超大间距
  static const double spacingXXLarge = 20.0;

  // ========== 容器配置 ==========
  /// 对话框内容padding
  static const EdgeInsets dialogPadding = EdgeInsets.all(20);
  
  /// 对话框按钮区域padding
  static const EdgeInsets dialogButtonPadding = EdgeInsets.all(12);
  
  /// 列表项padding
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

  // ========== 工具方法 ==========
  /// 创建SizedBox用于垂直间距
  static Widget verticalSpacing(double height) {
    return SizedBox(height: height);
  }
  
  /// 创建SizedBox用于水平间距
  static Widget horizontalSpacing(double width) {
    return SizedBox(width: width);
  }
  
  /// 创建小垂直间距
  static Widget get verticalSpacingSmall => const SizedBox(height: spacingSmall);
  
  /// 创建中等垂直间距
  static Widget get verticalSpacingMedium => const SizedBox(height: spacingMedium);
  
  /// 创建大垂直间距
  static Widget get verticalSpacingLarge => const SizedBox(height: spacingLarge);
  
  /// 创建超大垂直间距
  static Widget get verticalSpacingXLarge => const SizedBox(height: spacingXLarge);
  
  /// 创建小水平间距
  static Widget get horizontalSpacingSmall => const SizedBox(width: spacingSmall);
  
  /// 创建中等水平间距
  static Widget get horizontalSpacingMedium => const SizedBox(width: spacingMedium);
  
  /// 创建大水平间距
  static Widget get horizontalSpacingLarge => const SizedBox(width: spacingLarge);
  
  /// 创建超大水平间距
  static Widget get horizontalSpacingXLarge => const SizedBox(width: spacingXLarge);

  /// 创建圆角边框
  static BorderRadius borderRadius(double radius) {
    return BorderRadius.circular(radius);
  }
  
  /// 小圆角边框
  static BorderRadius get borderRadiusSmall => BorderRadius.circular(radiusSmall);
  
  /// 中等圆角边框
  static BorderRadius get borderRadiusMedium => BorderRadius.circular(radiusMedium);
  
  /// 大圆角边框
  static BorderRadius get borderRadiusLarge => BorderRadius.circular(radiusLarge);
  
  /// 超大圆角边框
  static BorderRadius get borderRadiusXLarge => BorderRadius.circular(radiusXLarge);
}