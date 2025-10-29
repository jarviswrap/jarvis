import 'package:flutter/material.dart';
import '../widgets/grid_background.dart';
import '../widgets/gradient_button.dart';
import 'module_detail.dart';

class CommandPalettePage extends StatefulWidget {
  const CommandPalettePage({super.key});

  @override
  State<CommandPalettePage> createState() => _CommandPalettePageState();
}

class _CommandPalettePageState extends State<CommandPalettePage> {
  final TextEditingController _controller = TextEditingController();
  final List<_Cmd> _all = [
    _Cmd('创建新工作流', '自动化流程', Icons.auto_awesome, const Color(0xFF8B5CF6)),
    _Cmd('打开控制面板', '系统', Icons.dashboard, const Color(0xFF0EA5E9)),
    _Cmd('文本助手', '模块', Icons.edit_note, const Color(0xFF60A5FA)),
    _Cmd('日程助手', '模块', Icons.event, const Color(0xFF34D399)),
    _Cmd('文件助手', '模块', Icons.folder_open, const Color(0xFFF59E0B)),
    _Cmd('AI 搜索', '模块', Icons.travel_explore, const Color(0xFF22D3EE)),
    _Cmd('知识库', '模块', Icons.library_books, const Color(0xFFEF4444)),
    _Cmd('设备控制', '模块', Icons.devices, const Color(0xFF14B8A6)),
  ];

  String _q = '';

  List<_Cmd> get _filtered {
    if (_q.trim().isEmpty) return _all;
    final k = _q.trim().toLowerCase();
    return _all.where((c) {
      return c.title.toLowerCase().contains(k) || c.group.toLowerCase().contains(k);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final muted = const Color(0xFFA7B0C0);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const GridBackground(),
          // 半透明遮罩
          Container(color: const Color(0x990A0B12)),
          // 居中命令面板
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1FFFFFFF)),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x0FFFFFFF), Color(0x08FFFFFF)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x330EA5E9), blurRadius: 24, offset: Offset(0, 12)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题与关闭
                  Row(
                    children: [
                      const Text('快速命令面板', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GradientButton.ghost(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 搜索框
                  TextField(
                    controller: _controller,
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: '输入命令或模块名称（例如：文本助手 / 创建新工作流）',
                      hintStyle: TextStyle(color: muted),
                      filled: true,
                      fillColor: const Color(0x14000000),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0x1FFFFFFF)),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 结果列表
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView.separated(
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const Divider(color: Color(0x1FFFFFFF), height: 1),
                        itemBuilder: (context, i) {
                          final c = _filtered[i];
                          return ListTile(
                            leading: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0x0FFFFFFF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(c.icon, color: Colors.white),
                            ),
                            title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(c.group, style: TextStyle(color: muted)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0x1FFFFFFF)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('回车执行', style: TextStyle(fontSize: 12)),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ModuleDetailPage(
                                    title: c.title,
                                    hint: c.group,
                                    iconData: c.icon,
                                    accent: c.accent,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cmd {
  final String title;
  final String group;
  final IconData icon;
  final Color accent;
  const _Cmd(this.title, this.group, this.icon, this.accent);
}