import 'dart:async';
import 'package:flutter/material.dart';
import '../core/plugin_system/plugin_interface.dart';
import '../core/plugin_system/plugin_loading_notifier.dart';
import '../core/plugin_system/plugin_manager.dart';
import '../core/plugin_system/plugin_models.dart';
import '../core/plugin_system/icon_utils.dart';
import '../core/utils/app_text_styles.dart'; // 添加导入
import 'plugin_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final PluginLoadingNotifier _loadingNotifier = PluginLoadingNotifier();
  late AnimationController _headerAnimationController;
  late Animation<double> _headerAnimation;
  Timer? _autoHideTimer;
  bool _isHeaderVisible = true;

  @override
  void initState() {
    super.initState();
    // 监听插件加载状态变化
    _loadingNotifier.addListener(_onPluginStateChanged);
    // 开始加载插件
    _loadingNotifier.loadPlugins();
    
    // 初始化动画控制器
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _headerAnimation = Tween<double>(
      begin: 0.0,  // 修改：从0开始（显示状态）
      end: 1.0,    // 修改：到1结束（隐藏状态）
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));
    
    // 设置10秒后自动隐藏头部的定时器
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      _hideHeader();
    });
  }

  @override
  void dispose() {
    _loadingNotifier.removeListener(_onPluginStateChanged);
    _headerAnimationController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _onPluginStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _hideHeader() {
    if (_isHeaderVisible) {
      setState(() {
        _isHeaderVisible = false;
      });
      _headerAnimationController.forward();  // 从0到1，隐藏头部
    }
  }

  void _showHeader() {
    if (!_isHeaderVisible) {
      setState(() {
        _isHeaderVisible = true;
      });
      _headerAnimationController.reverse();  // 从1到0，显示头部
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("JARVIS", style: AppTextStyles.appBarTitle),
        backgroundColor: Colors.cyan.shade700,
        actions: [
          IconButton(
            tooltip: '插件管理',
            icon: IconUtils.getIconWidget('extension', color: Colors.white),
            onPressed: () => _navigateToPluginManagement(),
          ),
          // 添加刷新按钮
          // 将刷新按钮换成清空缓存按钮
          IconButton(
            icon: IconUtils.getIconWidget('refresh', color: Colors.white),
            tooltip: '清空缓存',
            onPressed: _loadingNotifier.state == PluginLoadingState.loading 
                ? null 
                : () async {
                    // 显示确认对话框
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('清空缓存'),
                          content: const Text('这将清除所有插件缓存并重新从 YAML 文件加载配置。确定要继续吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('确定'),
                            ),
                          ],
                        );
                      },
                    );
                    
                    if (confirmed == true) {
                      await _loadingNotifier.clearCacheAndReload();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('缓存已清空，插件配置已重新加载'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
          ),
          // 添加显示/隐藏头部的按钮
          IconButton(
            tooltip: _isHeaderVisible ? '隐藏头部' : '显示头部',
            icon: IconUtils.getIconWidget(_isHeaderVisible ? 'keyboard_arrow_up' : 'keyboard_arrow_down', color: Colors.white),
            onPressed: _isHeaderVisible ? _hideHeader : _showHeader,
          ),
        ],
      ),
      body: Column(
        children: [
          // JARVIS 风格的头部 - 带动画
          AnimatedBuilder(
            animation: _headerAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -200 * _headerAnimation.value),
                child: Opacity(
                  opacity: 1.0 - _headerAnimation.value,
                  child: Container(
                    height: 200 * (1.0 - _headerAnimation.value),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan.shade700, Colors.cyan.shade900],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconUtils.getIconWidget("smart_toy", size: 64, color: Colors.white),
                          const SizedBox(height: 16),
                          const Text(
                            'JARVIS',
                            style: AppTextStyles.headerTitle,
                          ),
                          const Text(
                            '智能工作助手',
                            style: AppTextStyles.headerSubtitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // 插件加载状态指示器
          _buildLoadingIndicator(),
          // 插件列表
          Expanded(
            child: _buildPluginList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    switch (_loadingNotifier.state) {
      case PluginLoadingState.loading:
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.cyan.shade700),
                ),
              ),
              const SizedBox(width: 12),
              const Text('正在加载插件...', style: AppTextStyles.bodySecondary),
            ],
          ),
        );
      case PluginLoadingState.error:
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconUtils.getIconWidget("error_outline", color: Colors.red.shade600, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '插件加载失败: ${_loadingNotifier.errorMessage}',
                  style: AppTextStyles.error,
                ),
              ),
              TextButton(
                onPressed: () => _loadingNotifier.reloadPlugins(),
                child: const Text('重试', style: AppTextStyles.buttonNormal),
              ),
            ],
          ),
        );
      case PluginLoadingState.loaded:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconUtils.getIconWidget("check_circle", color: Colors.green.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                '插件加载完成 (${_loadingNotifier.pluginManager.enabledPlugins.length}个)',
                style: AppTextStyles.success,
              ),
            ],
          ),
        );
    }
  }

  Widget _buildPluginList() {
    final enabledPlugins = _loadingNotifier.pluginManager.enabledPlugins;
    
    if (_loadingNotifier.state == PluginLoadingState.loading || enabledPlugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconUtils.getIconWidget('extension_off', size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _loadingNotifier.state == PluginLoadingState.loading 
                ? '正在加载插件...' 
                : '插件列表为空，请前往添加插件',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 16),
            if (_loadingNotifier.state != PluginLoadingState.loading)
              ElevatedButton.icon(
                onPressed: () => _navigateToPluginManagement(),
                icon: IconUtils.getIconWidget('add'),
                label: const Text('添加插件', style: AppTextStyles.buttonNormal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      );
    }
  
    // 有插件时显示插件网格
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: enabledPlugins.length,
        itemBuilder: (context, index) {
          final plugin = enabledPlugins[index];
          return _buildPluginCard(plugin);
        },
      ),
    );
  }

  Widget _buildPluginCard(JarvisPlugin plugin) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _openPlugin(plugin),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconUtils.getIconWidget(plugin.config.icon, size: 48, color: Colors.cyan.shade700),
              const SizedBox(height: 12),
              Text(
                plugin.config.name,
                style: AppTextStyles.cardTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                plugin.config.description,
                style: AppTextStyles.cardSubtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlugin(JarvisPlugin plugin) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => plugin.getMainWidget(),
      ),
    );
  }

  Future<void> _navigateToPluginManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PluginManagementScreen(),
      ),
    );
    // 插件管理页面返回后刷新状态
    setState(() {});
  }
}