part of '../program_page.dart';

class ExampleItem {
  final String title;
  final String script;
  const ExampleItem({required this.title, required this.script});
}



class ExamplesPanel extends StatelessWidget {
  final List<ExampleItem> examples;
  final void Function(String script) onFill;
  final void Function(String script) onRun;
  const ExamplesPanel({required this.examples, required this.onFill, required this.onRun});

  @override
  Widget build(BuildContext context) {
    const muted = Color(0xFFA7B0C0);
    // 使用同库中的私有组件 _Panel 与 _IconBtn
    return _Panel(
      title: '使用示例',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('点击展开查看详细脚本；右侧图标可快速“填入/运行”。', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: examples.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0x1FFFFFFF), height: 1),
            itemBuilder: (_, i) {
              final ex = examples[i];
              return ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 6.0),
                title: Text(ex.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconBtn(icon: Icons.content_paste, tooltip: '填入编辑器', onTap: () => onFill(ex.script)),
                    const SizedBox(width: 6),
                    _IconBtn(icon: Icons.play_arrow, tooltip: '运行示例', onTap: () => onRun(ex.script)),
                  ],
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                      color: const Color(0x12000000),
                    ),
                    child: Text(ex.script, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}