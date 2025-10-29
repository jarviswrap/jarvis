import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';

class GridBackground extends StatelessWidget {
  const GridBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 深色径向背景
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.6, -1.0),
                radius: 1.2,
                colors: [Color(0xFF0F1630), Color(0xFF0B0D16)],
              ),
            ),
          ),
          // 网格
          CustomPaint(painter: _GridPainter()),
          // 顶部蒙版，降低网格强度
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Colors.transparent],
                ),
              ),
            ),
          ),
          // 细微噪声（轻透明） — 替换 ImageFilter.noise 为自绘噪声层
          const NoiseLayer(opacity: 0.04),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const step = 40.0;
    final paint = Paint()
      ..color = const Color(0x0DFFFFFF)
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 噪声层：一次性生成 256x256 的噪声贴图，平铺整屏
class NoiseLayer extends StatefulWidget {
  final double opacity;
  const NoiseLayer({super.key, this.opacity = 0.04});

  @override
  State<NoiseLayer> createState() => _NoiseLayerState();
}

class _NoiseLayerState extends State<NoiseLayer> {
  ui.Image? _tile;

  @override
  void initState() {
    super.initState();
    _generateNoiseTile();
  }

  Future<void> _generateNoiseTile() async {
    const size = Size(256, 256);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rand = math.Random(12345);
    final paint = Paint();

    // 背景透明
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x00000000));

    // 绘制少量随机像素，低透明白点
    for (int i = 0; i < 8000; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final a = 0.03 + rand.nextDouble() * 0.02; // 0.03~0.05
      paint.color = Color.fromRGBO(255, 255, 255, a);
      canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    if (mounted) setState(() => _tile = img);
  }

  @override
  Widget build(BuildContext context) {
    if (_tile == null) return const SizedBox.expand();
    return CustomPaint(painter: _NoisePainter(_tile!, widget.opacity));
  }
}

class _NoisePainter extends CustomPainter {
  final ui.Image tile;
  final double opacity;
  _NoisePainter(this.tile, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    // 平铺噪声贴图
    paintImage(
      canvas: canvas,
      rect: Offset.zero & size,
      image: tile,
      repeat: ImageRepeat.repeat,
      fit: BoxFit.none,
      opacity: opacity,
      filterQuality: FilterQuality.low,
    );
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) =>
      oldDelegate.tile != tile || oldDelegate.opacity != opacity;
}