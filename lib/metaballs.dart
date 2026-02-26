import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MetaBallsView extends StatefulWidget {
  const MetaBallsView({super.key});

  @override
  State<MetaBallsView> createState() => _MetaBallsViewState();
}

class _MetaBallsViewState extends State<MetaBallsView> {
  double movingY = 200;
  ui.FragmentProgram? _program;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final results = await Future.wait([
      ui.FragmentProgram.fromAsset('shaders/metaballs.frag'),
      _loadImage('assets/avatar.jpg'),
    ]);

    if (!mounted) return;
    setState(() {
      _program = results[0] as ui.FragmentProgram;
      _image = results[1] as ui.Image;
    });
  }

  Future<ui.Image> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final image = _image;
    if (program == null || image == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              movingY = (movingY + details.delta.dy)
                  .clamp(0.0, constraints.maxHeight);
            });
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: MetaBallsPainter(
              program: program,
              image: image,
              movingY: movingY,
            ),
          ),
        );
      },
    );
  }
}

class MetaBallsPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image image;
  final double movingY;

  MetaBallsPainter({
    required this.program,
    required this.image,
    required this.movingY,
  });

  static const _center1X = 200.0;
  static const _center1Y = 300.0;
  static const _halfW1 = 120.0;
  static const _halfH1 = 30.0;
  static const _cornerR1 = 30.0;
  static const _r2 = 80.0;
  static const _threshold = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, _center1X); // uCenter1
    shader.setFloat(1, _center1Y);
    shader.setFloat(2, _halfW1); // uHalfSize1
    shader.setFloat(3, _halfH1);
    shader.setFloat(4, _cornerR1); // uCornerR1
    shader.setFloat(5, _center1X); // uCenter2
    shader.setFloat(6, movingY);
    shader.setFloat(7, _r2); // uRadius2
    shader.setFloat(8, _threshold); // uThreshold
    shader.setFloat(9, image.width.toDouble()); // uImageSize
    shader.setFloat(10, image.height.toDouble());

    shader.setImageSampler(0, image);

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
