import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MetaBallsView extends StatefulWidget {
  final void Function(bool useLightBar)? onStatusBarStyleChange;
  const MetaBallsView({super.key, this.onStatusBarStyleChange});

  @override
  State<MetaBallsView> createState() => _MetaBallsViewState();
}

class _MetaBallsViewState extends State<MetaBallsView>
    with SingleTickerProviderStateMixin {
  static const _snapTop = 0.0;
  static const _snapBottom = 120.0;

  double movingY = _snapBottom;
  ui.FragmentProgram? _program;
  ui.Image? _image;
  late final AnimationController _animController;
  Animation<double>? _snapAnimation;
  bool? _lastReportedLightBar;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          setState(() {
            movingY = _snapAnimation!.value;
            _notifyStatusBarStyle();
          });
        });
    _loadResources();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyStatusBarStyle();
    });
  }

  void _snapTo(double target) {
    _snapAnimation = Tween(begin: movingY, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
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

  void _notifyStatusBarStyle() {
    final t = ((movingY - 30) / (_snapBottom - 30)).clamp(0.0, 1.0);
    final useLightBar = t > 0.5;
    if (_lastReportedLightBar != useLightBar) {
      _lastReportedLightBar = useLightBar;
      widget.onStatusBarStyleChange?.call(useLightBar);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
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

    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = screenWidth / 2;
    const halfH = 18.5;
    const centerY = 29.5;
    const innerW = 110.0;
    const innerH = 29.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanUpdate: (details) {
            _animController.stop();
            setState(() {
              movingY = (movingY + details.delta.dy).clamp(
                _snapTop,
                _snapBottom,
              );
              _notifyStatusBarStyle();
            });
          },
          onPanEnd: (_) {
            final mid = (_snapTop + _snapBottom) / 3;
            _snapTo(movingY < mid ? _snapTop : _snapBottom);
          },
          child: Stack(
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: MetaBallsPainter(
                  program: program,
                  image: image,
                  movingY: movingY,
                  centerX: centerX,
                ),
              ),
              Positioned(
                left: centerX - innerW / 2,
                top: centerY + halfH - innerH,
                child: Container(
                  width: innerW,
                  height: innerH,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(innerH / 2),
                  ),
                ),
              ),
            ],
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
  final double centerX;

  MetaBallsPainter({
    required this.program,
    required this.image,
    required this.movingY,
    required this.centerX,
  });

  static const _center1Y = 29.5;
  static const _halfW1 = 63.0;
  static const _halfH1 = 18.5;
  static const _cornerR1 = 18.5;
  static const _r2 = 80.0;
  static const _threshold = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    shader.setFloat(0, centerX); // uCenter1
    shader.setFloat(1, _center1Y);
    shader.setFloat(2, _halfW1); // uHalfSize1
    shader.setFloat(3, _halfH1);
    shader.setFloat(4, _cornerR1); // uCornerR1
    shader.setFloat(5, centerX); // uCenter2
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
    return oldDelegate.movingY != movingY || oldDelegate.centerX != centerX;
  }
}
