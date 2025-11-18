import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'workflow_page.dart';
import 'android_sdk_analysis_page.dart';
import '../widgets/gradient_text.dart';
import '../widgets/gradient_button.dart';
import '../widgets/grid_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/nav_bar.dart';  
import 'abs/jarvis_page.dart';
import 'command_palette.dart';
import 'module_detail.dart';
import 'script_page.dart';

// 顶部 import 区域（新增自动配色工具）
import '../core/color_palette.dart';

class HomePage extends JarvisPage {
  const HomePage({super.key}) : super(
          isRoot: true,
          accent: const Color(0xFF0EA5E9),
          actionsBuilder: _homeActions,
        );

  // 首页的右侧图标动作
  static List<NavAction> _homeActions(BuildContext context) => [
        NavAction(
          icon: Icons.search,
          tooltip: '快速命令面板',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommandPalettePage()),
            );
          },
        ),
        NavAction(
          icon: Icons.explore,
          tooltip: '开始探索',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => NsScriptPage()),
            );
          },
        ),
      ];

  @override
  List<Widget> background(BuildContext context) => [
        const GridBackground(),
        const _AuroraLayer(),
      ];
      
  String get platformLabel {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    // fallback
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      default:
        return 'Desktop';
    }
  }

  @override
  Widget content(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    const modules = <_Module>[
      _Module('android_sdk', 'Android SDK依赖分析', '依赖扫描·接口统计·调用来源', Icons.android),
      _Module('schedule', '日程助手', '计划·提醒·同步', Icons.event),
      _Module('files', '文件助手', '检索·预览·归档', Icons.folder_open),
      _Module('automation', '自动化流程', '触发器·动作·编排', Icons.auto_awesome),
      _Module('search', 'AI 搜索', '多源·聚合·答案', Icons.travel_explore),
      _Module('kb', '知识库', '采集·清洗·向量', Icons.library_books),
      _Module('devices', '设备控制', '系统·应用·脚本', Icons.devices),
      _Module('more', '更多功能', '插件·扩展·集成', Icons.extension),
    ];

    return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 40), // 顶部增加空隙，避免被悬浮 NavBar 视觉覆盖
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Hero 标题
                  const GradientText(
                    '智能工作助手',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFFE6EAF2), Color(0xFFA7B0C0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  // 替换为统一字号（保留渐变视觉）
                  GradientText(
                    '智能工作助手',
                    style: theme.textTheme.displayLarge!,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6EAF2), Color(0xFFA7B0C0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '聚合知识、自动化与协作，打造你的多功能工作中枢',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge!.copyWith(color: muted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      GradientButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => WorkflowPage()),
                          );
                        },
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        borderRadius: 12,
                        colors: const [Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
                        child: const Text(
                          '创建新工作流',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      GradientButton.ghost(
                        onPressed: () {},
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        borderRadius: 12,
                        child: const Text(
                          '打开控制面板',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Hero Meta
                  Wrap(
                    spacing: 18,
                    alignment: WrapAlignment.center,
                    children: [
                      _MonoMeta('跨平台 · $platformLabel'),
                      _MonoMeta('安全隔离 · Preload/IPC'),
                      _MonoMeta('流畅 UI · Flutter (M3)'),
                    ],
                  ),
                  const SizedBox(height: 36),
                  // 模块卡片网格
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width >= 1200
                          ? 4
                          : width >= 900
                              ? 3
                              : width >= 600
                                  ? 2
                                  : 1;
                      return GridView.builder(
                        itemCount: modules.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.6,
                        ),
                        itemBuilder: (context, i) {
                          final m = modules[i];
                          final accent = AccentPalette.forKey(m.key);
                          return GlassCard(
                            title: m.title,
                            hint: m.hint,
                            iconData: m.icon,
                            accent: accent,
                            status: i == 0 ? '可用' : '即将到来',
                            onTap: () {
                              if (i == 0) {
                                // 首页第一个模块跳转到 Android SDK 依赖分析页面
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AndroidSdkAnalysisPage(),
                                  ),
                                );
                              } else {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ModuleDetailPage(
                                      title: m.title,
                                      hint: m.hint,
                                      iconData: m.icon,
                                      accent: accent,
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  // 页脚
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 28),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: const Color(0x1FFFFFFF)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Jarvis · 智能工作助手', style: TextStyle(color: muted)),
                        const _MonoMeta('Beta'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

class _Module {
  final String key;
  final String title;
  final String hint;
  final IconData icon;

  const _Module(this.key, this.title, this.hint, this.icon);
}

class _MonoMeta extends StatelessWidget {
  final String text;
  const _MonoMeta(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFFA7B0C0),
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// 极光背景层：多组径向渐变 + 轻微模糊
class _AuroraLayer extends StatelessWidget {
  const _AuroraLayer();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          // 左上蓝光
          Positioned(
            left: -150,
            top: -80,
            child: _BlurBlob(
              size: Size(500, 260),
              colors: [Color(0x4060A5FA), Colors.transparent],
            ),
          ),
          // 右上紫光
          Positioned(
            right: -120,
            top: -40,
            child: _BlurBlob(
              size: Size(380, 220),
              colors: [Color(0x408B5CF6), Colors.transparent],
            ),
          ),
          // 底部青光
          Positioned(
            left: 0,
            right: 0,
            bottom: -60,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: _BlurBlob(
                size: Size(620, 320),
                colors: [Color(0x4022D3EE), Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurBlob extends StatelessWidget {
  final Size size;
  final List<Color> colors;
  const _BlurBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: colors,
              radius: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}