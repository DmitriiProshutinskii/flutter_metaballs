import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MetaBallsView extends StatefulWidget {
  const MetaBallsView({super.key});

  @override
  State<MetaBallsView> createState() => _MetaBallsViewState();
}

class _MetaBallsViewState extends State<MetaBallsView> {
  double movingY = 200;
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program =
        await ui.FragmentProgram.fromAsset('shaders/metaballs.frag');
    if (mounted) setState(() => _program = program);
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    if (program == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          movingY += details.delta.dy;
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: MetaBallsPainter(program: program, movingY: movingY),
      ),
    );
  }
}

class MetaBallsPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final double movingY;

  MetaBallsPainter({required this.program, required this.movingY});

  static const _center1X = 200.0;
  static const _center1Y = 300.0;
  static const _r1 = 80.0;
  static const _r2 = 80.0;
  static const _threshold = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, _center1X); // uCenter1
    shader.setFloat(1, _center1Y);
    shader.setFloat(2, _r1); // uRadius1
    shader.setFloat(3, _center1X); // uCenter2
    shader.setFloat(4, movingY);
    shader.setFloat(5, _r2); // uRadius2
    shader.setFloat(6, _threshold); // uThreshold

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );

    shader.dispose();
  }

  @override
  bool shouldRepaint(covariant MetaBallsPainter oldDelegate) {
    return oldDelegate.movingY != movingY;
  }
}
