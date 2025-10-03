import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/plugin_system/plugin_interface.dart';  // 引入文本样式
import '../core/plugin_system/plugin_loading_notifier.dart';
import '../core/plugin_system/icon_utils.dart';
import '../core/widgets/app_section_card.dart';
import '../core/utils/app_text_styles.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/app_layout_config.dart';
import 'plugin_management_screen.dart';
import 'log_viewer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  Timer? _autoHideTimer;
  bool _isHeaderVisible = true;
  bool _autoHideEnabled = true; // 添加自动隐藏控制标志

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _headerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // 修复：初始状态应该是显示头部，所以不要调用 forward()
    // _headerAnimationController.forward(); // 删除这行
    _startAutoHideTimer();
    
    // 使用Riverpod的方式初始化加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pluginLoadingProvider.notifier).loadPlugins();
    });
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _startAutoHideTimer() {
    _autoHideTimer?.cancel();
    // 只有在启用自动隐藏时才设置定时器
    if (_autoHideEnabled) {
      _autoHideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isHeaderVisible && _autoHideEnabled) {
          _hideHeader();
        }
      });
    }
  }

  void _hideHeader({bool isManual = false}) {
    if (_isHeaderVisible) {
      setState(() {
        _isHeaderVisible = false;
      });
      _headerAnimationController.forward(); // 向前播放动画隐藏头部
      
      // 如果是手动隐藏，禁用自动隐藏功能
      if (isManual) {
        _autoHideEnabled = false;
        _autoHideTimer?.cancel();
      }
    }
  }

  void _showHeader({bool isManual = false}) {
    if (!_isHeaderVisible) {
      setState(() {
        _isHeaderVisible = true;
      });
      _headerAnimationController.reverse(); // 反向播放动画显示头部
      
      // 如果是手动显示，禁用自动隐藏功能
      if (isManual) {
        _autoHideEnabled = false;
        _autoHideTimer?.cancel();
      }
    }
  }

  // 清理缓存方法
  void _clearCache() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清理缓存'),
          content: const Text('确定要清理应用缓存吗？这将清除所有临时数据。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performClearCache();
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  // 执行清理缓存
  Future<void> _performClearCache() async {
    try {
      // 清理日志缓存
      AppLogger.clearLogs();
      
      AppLogger.info('Cache cleared successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('缓存清理完成'),
            backgroundColor: Colors.green,
          ),
        );
        
        // 重新加载插件
        ref.read(pluginLoadingProvider.notifier).clearCacheAndReload();
      }
    } catch (e) {
      AppLogger.error('清理缓存失败', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('缓存清理失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 显示日志
  void _showLogs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const LogViewerScreen(),
      ),
    );
  }

  // 统一的getActions方法
  List<Widget> getActions() {
    return [
      PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert, 
          color: _isHeaderVisible ? Colors.white : null,
        ),
        onSelected: (String value) {
          switch (value) {
            case 'toggle_header':
              if (_isHeaderVisible) {
                _hideHeader(isManual: true);
              } else {
                _showHeader(isManual: true);
              }
              break;
            case 'clear_cache':
              _clearCache();
              break;
            case 'show_logs':
              _showLogs();
              break;
            case 'plugin_management':
              _navigateToPluginManagement();
              break;
          }
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem<String>(
            value: 'toggle_header',
            child: Text(_isHeaderVisible ? '隐藏头部' : '显示头部'),
          ),
          const PopupMenuItem<String>(
            value: 'plugin_management',
            child: Text('插件管理'),
          ),
          const PopupMenuItem<String>(
            value: 'clear_cache',
            child: Text('清理缓存'),
          ),
          const PopupMenuItem<String>(
            value: 'show_logs',
            child: Text('显示日志'),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isHeaderVisible ? null : AppTextStyles.buildAppBar(
        title: 'JARVIS',
        actions: getActions(),
      ),
      body: Column(
        children: [
          GestureDetector(
            onTap: () {
              _showHeader(isManual: true);
            },
            child: ClipRect(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _isHeaderVisible ? 200 : 0,
                child: _isHeaderVisible
                    ? _buildCustomHeader()
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          Expanded(
            child: _buildPluginGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.9),
            Theme.of(context).primaryColor.withOpacity(0.7),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 头部标题行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'JARVIS',
                      style: AppTextStyles.pageTitle.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // 使用统一的getActions方法
                  ...getActions(),
                ],
              ),
              const SizedBox(height: 8),
              // 副标题
              Text(
                '智能助手 - 让工作更高效',
                style: AppTextStyles.cardTitle.copyWith(
                  color: Colors.white70,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPluginGrid() {
    final pluginLoadingData = ref.watch(pluginLoadingProvider);
    
    if (pluginLoadingData.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("正在加载插件..."),
          ],
        ),
      );
    }

    if (pluginLoadingData.hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              "加载插件失败",
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 8),
            Text(
              pluginLoadingData.error ?? "未知错误",
              style: AppTextStyles.bodyNormal.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(pluginLoadingProvider.notifier).reloadPlugins(),
              child: const Text("重试"),
            ),
          ],
        ),
      );
    }

    // 获取启用的插件列表
    final enabledPlugins = pluginLoadingData.pluginManager.enabledPlugins;

    if (enabledPlugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.extension_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "暂无可用插件",
              style: AppTextStyles.cardTitle,
            ),
            const SizedBox(height: 8),
            Text(
              "请在插件管理中添加插件",
              style: AppTextStyles.bodyNormal.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: AppLayoutConfig.pagePadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: enabledPlugins.length,
      itemBuilder: (context, index) {
        final plugin = enabledPlugins[index];
        return _buildPluginCard(plugin);
      },
    );
  }

  Widget _buildPluginCard(JarvisPlugin plugin) {
    return AppSectionCard(
        hasShadow: true,
        singleChild: true,
        children: [
            InkWell(
              onTap: () => _openPlugin(plugin),
              borderRadius: AppLayoutConfig.borderRadiusLarge,
              child: Padding(
                padding: AppLayoutConfig.cardPaddingMedium,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      IconUtils.getIcon(plugin.config.icon),
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        plugin.config.name,
                        style: AppTextStyles.cardTitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
  }

  void _openPlugin(JarvisPlugin plugin) {
    AppLogger.info('Opening plugin: ${plugin.config.name}');
    
    // 跳转到插件的主界面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => plugin.getMainWidget(),
      ),
    );
  }

  Future<void> _navigateToPluginManagement() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PluginManagementScreen(),
      ),
    );
    
    if (result == true) {
      // 插件配置有变化，重新加载
      ref.read(pluginLoadingProvider.notifier).reloadPlugins();
    }
  }
}