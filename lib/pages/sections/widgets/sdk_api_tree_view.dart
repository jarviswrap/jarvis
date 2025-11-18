import 'package:flutter/material.dart';
import '../../../core/android_sdk_analyzer.dart';

class SdkApiTreeView extends StatelessWidget {
  final List<SdkApi> apis;
  final EdgeInsetsGeometry? padding;
  // 可选：当提供 usages 时，将在方法节点下展示调用点列表；
  // 若提供 usages，则默认仅展示存在调用点的接口方法。
  final Map<SdkApi, List<CallSite>>? usages;

  const SdkApiTreeView({
    super.key,
    required this.apis,
    this.padding,
    this.usages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final content = _buildTree(context, muted);
    if (padding != null) {
      return Padding(padding: padding!, child: content);
    }
    return content;
  }

  Widget _buildTree(BuildContext context, Color muted) {
    // 当 usages 提供时，优先展示包含调用点的接口方法
    final sourceApis = usages == null
        ? apis
        : apis.where((a) => (usages![a]?.isNotEmpty ?? false)).toList();

    if (sourceApis.isEmpty) {
      final msg = usages == null ? '尚未提取接口。' : '未发现任何调用点。';
      return Text(msg, style: TextStyle(color: muted));
    }

    // 分组：package -> class -> methods
    final byPkg = <String, Map<String, List<SdkApi>>>{};
    for (final a in sourceApis) {
      final pkg = a.package;
      final cls = a.className;
      byPkg.putIfAbsent(pkg, () => {});
      (byPkg[pkg]![cls] ??= []).add(a);
    }
    final pkgs = byPkg.keys.toList()..sort();
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pkgs.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0x12FFFFFF), height: 0.5),
      itemBuilder: (context, i) {
        final pkg = pkgs[i];
        final classes = byPkg[pkg]!.keys.toList()..sort();
        return ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          title: Text(
            pkg,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          children: [
            for (final cls in classes)
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                childrenPadding: const EdgeInsets.only(left: 4),
                title: Text(cls, style: const TextStyle(fontSize: 13)),
                children: [
                  for (final a in (byPkg[pkg]![cls]!..sort((x, y) => x.methodName.compareTo(y.methodName))))
                    _buildMethodNode(context, a, muted),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _buildMethodNode(BuildContext context, SdkApi api, Color muted) {
    final sites = usages?[api] ?? const <CallSite>[];
    if (sites.isEmpty) {
      // 仅接口浏览模式：展示方法与签名
      return ListTile(
        title: Text(api.methodName),
        subtitle: Text(api.signature, style: TextStyle(color: muted)),
      );
    }
    // 存在调用点：方法为可展开节点，展示调用点列表
    // 统计静态/实例调用数
    final staticCount = sites.where((s) => s.kind == 'static').length;
    final instanceCount = sites.length - staticCount;

    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Row(
        children: [
          Expanded(child: Text(api.methodName, style: const TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          _compactChip('${sites.length} 次'),
          const SizedBox(width: 6),
          _compactChip('实例 $instanceCount / 静态 $staticCount'),
        ],
      ),
      subtitle: Text(api.signature, style: TextStyle(color: muted, fontSize: 12)),
      children: [
        for (final s in sites)
          ListTile(
            dense: true,
            visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
            leading: Icon(
              s.kind == 'static' ? Icons.circle : Icons.radio_button_checked,
              size: 12,
              color: muted,
            ),
            title: Text(
              '${_shortPath(s.filePath)}:${s.line} · ${s.kind == 'static' ? '静态' : '实例'}',
              style: const TextStyle(fontSize: 12),
            ),
            subtitle: Text(
              s.lineText.trim(),
              style: TextStyle(color: muted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  String _shortPath(String full) {
    final parts = full.split(RegExp(r'[\\/]'));
    if (parts.length <= 3) return full;
    // 保留末尾三段：module/src/File
    return [...parts.skip(parts.length - 3)].join('/');
  }

  Widget _compactChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: const Color(0x142196F3),
    );
  }
}