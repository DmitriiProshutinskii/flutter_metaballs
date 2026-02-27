// Metaballs demo: Telegram-style profile with avatar that "flows" into a Dynamic Island–shaped blob.
// All UI (background, text, shadow, shader) is driven by a single value: movingY (avatar center Y).
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen view: draggable metaballs + background + name. Reports status bar style so the app bar can switch icons.
class MetaBallsView extends StatefulWidget {
  final void Function(bool useLightBar)? onStatusBarStyleChange;
  const MetaBallsView({super.key, this.onStatusBarStyleChange});

  @override
  State<MetaBallsView> createState() => _MetaBallsViewState();
}

class _MetaBallsViewState extends State<MetaBallsView>
    with SingleTickerProviderStateMixin {
  // Snap targets: 0 = fully merged with "Dynamic Island" at top, 120 = profile expanded. Values tuned for this layout.
  static const _snapTop = 0.0;
  static const _snapBottom = 120.0;

  /// Single source of truth for the avatar position. Drives shader (uCenter2.y), background height/color, text position/size, and shadow.
  double movingY = _snapBottom;
  ui.FragmentProgram? _program;
  ui.Image? _image;
  late final AnimationController _animController;
  Animation<double>? _snapAnimation;
  bool? _lastReportedLightBar;

  @override
  void initState() {
    super.initState();
    // SingleTickerProviderStateMixin gives vsync so the controller advances with the display; required for AnimationController.
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

  /// Animates movingY to [target] with easeOutCubic. Call after drag ends to snap to top or bottom.
  void _snapTo(double target) {
    _snapAnimation = Tween(begin: movingY, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  /// Load shader and avatar in parallel so we don't block on sequential I/O. Both are needed before first paint.
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

  /// Decode asset to [ui.Image] so we can pass it to the fragment shader. Image.asset doesn't give us a sync ui.Image, hence manual codec.
  Future<ui.Image> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Decide status bar style from scroll position. t in [0,1] over the "active" range (30.._snapBottom); useLightBar when t > 0.5. Only notify when the decision changes to avoid unnecessary parent setState.
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

    return Stack(
      children: [
        // Background height and color both follow movingY; transparent when merged, blue when expanded.
        Container(
          height: movingY + 100,
          width: double.maxFinite,
          color: Color.lerp(
            const ui.Color(0x002962FF),
            const ui.Color(0xFF2962FF),
            ((movingY - 30) / (_snapBottom - 30)).clamp(0.0, 1.0),
          )!,
        ),
        // Decorative circle shadow behind the avatar; opacity and color lerp with scroll so it fades as we merge.
        Positioned(
          left: centerX - 35,
          top: movingY - 35,
          child: Opacity(
            opacity: (movingY / _snapBottom).clamp(0.0, 1.0),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color.lerp(
                      const ui.Color(0x0082B1FF),
                      const ui.Color(0xFF82B1FF).withValues(alpha: 0.6),
                      ((movingY - 30) / (_snapBottom - 30)).clamp(0.0, 1.0),
                    )!,

                    blurRadius: 30,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Pan: stop any running snap animation and clamp movingY. On release, snap to top or bottom; mid = (0+120)/3 biases toward snapping down (expanded) unless user dragged well up.
        GestureDetector(
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
          child: CustomPaint(
            size: Size.infinite,
            painter: MetaBallsPainter(
              program: program,
              image: image,
              movingY: movingY,
              centerX: centerX,
            ),
          ),
        ),
        Positioned(
          top: movingY + halfH + 30 + (1 - movingY / _snapBottom) * 15,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Dmitrii Proshutinskii 😎',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: movingY < 50 ? Colors.black : Colors.white,
                    fontSize: 17 + (movingY / _snapBottom) * 9,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paints the metaballs + avatar image by running the fragment shader over the full canvas.
/// Uniform order must match the GLSL declaration order: vec2 = 2 floats, so uCenter1 = 0,1; uHalfSize1 = 2,3; etc.
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

  // RRect (Dynamic Island) geometry; must match layout. Ball 2 nominal radius and threshold (shader uses effectiveR = r/sqrt(threshold)).
  static const _center1Y = 27.5;
  static const _halfW1 = 58.0;
  static const _halfH1 = 18.5;
  static const _cornerR1 = 18.5;
  static const _r2 = 80.0;
  static const _threshold = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // Float uniforms: indices 0..10 map to uCenter1.x, uCenter1.y, uHalfSize1.x, uHalfSize1.y, uCornerR1, uCenter2.x, uCenter2.y, uRadius2, uThreshold, uImageSize.x, uImageSize.y.
    shader.setFloat(0, centerX); // uCenter1.x
    shader.setFloat(1, _center1Y); // uCenter1.y
    shader.setFloat(2, _halfW1); // uHalfSize1.x
    shader.setFloat(3, _halfH1); // uHalfSize1.y
    shader.setFloat(4, _cornerR1); // uCornerR1
    shader.setFloat(5, centerX); // uCenter2.x
    shader.setFloat(6, movingY); // uCenter2.y
    shader.setFloat(7, _r2); // uRadius2
    shader.setFloat(8, _threshold); // uThreshold
    shader.setFloat(9, image.width.toDouble()); // uImageSize.x
    shader.setFloat(10, image.height.toDouble()); // uImageSize.y

    shader.setImageSampler(0, image);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = shader,
    );

    // Always dispose the shader instance; it holds GPU resources and is created every paint.
    shader.dispose();
  }

  /// Repaint only when position or horizontal center changes. Program/image are stable after load.
  @override
  bool shouldRepaint(covariant MetaBallsPainter oldDelegate) {
    return oldDelegate.movingY != movingY || oldDelegate.centerX != centerX;
  }
}
