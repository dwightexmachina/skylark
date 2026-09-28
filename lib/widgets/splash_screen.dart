import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/theme_controller.dart';
import 'lark.dart';

/// "Dawn Chorus": full-bleed sunrise splash. A huge sun climbs from the
/// bottom with slow-turning rays, clouds drift past, and the lark flies
/// beside the wordmark trailing notes. Dismissed by the button, any tap,
/// or any key (handled by the parent); doubles as the audio-unlock gesture.
class SplashScreen extends StatefulWidget {
  final VoidCallback onDismiss;

  const SplashScreen({super.key, required this.onDismiss});

  @override
  State<SplashScreen> createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(seconds: 30))
    ..repeat();
  late final AnimationController _drift = AnimationController(
      vsync: this, duration: const Duration(seconds: 16))
    ..repeat();
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..repeat();
  late final AnimationController _notes = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  late final AnimationController _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320), value: 1);

  bool _closing = false;

  @override
  void dispose() {
    _spin.dispose();
    _drift.dispose();
    _bob.dispose();
    _notes.dispose();
    _fade.dispose();
    super.dispose();
  }

  bool get _reduce => MediaQuery.of(context).disableAnimations;

  /// Fade out, then tell the parent to remove us.
  void close() {
    if (_closing) return;
    _closing = true;
    if (_reduce) {
      widget.onDismiss();
    } else {
      _fade.reverse().whenComplete(widget.onDismiss);
    }
  }

  double _wave(AnimationController c, double phase) {
    final t = (c.value - phase) % 1.0;
    return math.sin(2 * math.pi * t);
  }

  @override
  Widget build(BuildContext context) {
    final night = ThemeController.instance.night;
    final scene = Stack(
      clipBehavior: Clip.hardEdge,
      fit: StackFit.expand,
      children: [
        // Dawn (or moonrise) sky.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: night
                  ? const [
                      Color(0xFF10173A),
                      Color(0xFF1A2450),
                      Color(0xFF273463),
                      Color(0xFF433F6F),
                      Color(0xFF564C7B),
                    ]
                  : const [
                      Color(0xFF5B8FD0),
                      Color(0xFF7FB4E6),
                      Color(0xFFA6D8F5),
                      Color(0xFFFFDFA3),
                      Color(0xFFFFD27A),
                    ],
              stops: const [0, 0.30, 0.55, 0.88, 1],
            ),
          ),
        ),
        if (night)
          const Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _StarsPainter())),
          ),
        // Rising sun (a moon after dark).
        Positioned(
          bottom: -180,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, _) => CustomPaint(
                size: const Size(360, 360),
                painter: _SunrisePainter(
                    rotation: _reduce ? 0 : _spin.value * 2 * math.pi,
                    night: night),
              ),
            ),
          ),
        ),
        // Drifting clouds.
        _cloud(left: 0.06, top: 60, w: 150, phase: 0),
        _cloud(right: 0.06, top: 128, w: 118, phase: 0.35),
        _cloud(left: 0.14, bottom: 130, w: 180, phase: 0.65),
        // Title lockup.
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: _reduce ? 1 : 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, e, child) => Opacity(
              opacity: e.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.6 + 0.4 * e,
                child: child,
              ),
            ),
            child: _titleBox(),
          ),
        ),
      ],
    );

    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: close,
        child: scene,
      ),
    );
  }

  Widget _cloud(
      {double? left,
      double? right,
      double? top,
      double? bottom,
      required double w,
      required double phase}) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final dx = _reduce ? 0.0 : 26 * _wave(_drift, phase);
        final size = MediaQuery.of(context).size;
        return Positioned(
          left: left != null ? left * size.width + dx : null,
          right: right != null ? right * size.width - dx : null,
          top: top,
          bottom: bottom,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: CustomPaint(
            size: Size(w, w * 0.34),
            painter: _PuffPainter(night: ThemeController.instance.night)),
      ),
    );
  }

  Widget _titleBox() {
    const inkShadow = [
      Shadow(color: Color(0x4D33406B), offset: Offset(0, 3)),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lark + wordmark.
        SizedBox(
          width: 420,
          height: 120,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              const Positioned(
                bottom: 0,
                child: Text('Skylark',
                    style: TextStyle(
                      fontSize: 84,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: inkShadow,
                    )),
              ),
              Positioned(
                right: -30,
                top: -34,
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Transform(
                    transform: Matrix4.translationValues(
                        0, _reduce ? 0 : -10 * (0.5 + 0.5 * _wave(_bob, 0)), 0)
                      ..rotateZ(_reduce ? 0 : 0.05 * _wave(_bob, 0.1)),
                    alignment: Alignment.center,
                    child: child,
                  ),
                  child: SizedBox(
                    width: 120,
                    height: 90,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: 0,
                          top: 12,
                          child: CustomPaint(
                              size: const Size(84, 64),
                              painter: LarkPainter()),
                        ),
                        for (final (i, glyph, x, y) in const [
                          (0, '♪', -8.0, 26.0),
                          (1, '♫', 10.0, 44.0),
                          (2, '♪', -20.0, 48.0),
                        ])
                          AnimatedBuilder(
                            animation: _notes,
                            builder: (context, _) {
                              final t = _reduce
                                  ? 0.4
                                  : (_notes.value - i * 0.33) % 1.0;
                              final o = t < 0.15
                                  ? t / 0.15
                                  : (1 - t).clamp(0.0, 1.0);
                              return Positioned(
                                left: 34 + x - 40 * t,
                                top: y - 62 * t,
                                child: Opacity(
                                  opacity: o,
                                  child: Text(glyph,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        color: Colors.white,
                                        shadows: inkShadow,
                                      )),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('Hear it. Play it back.',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: inkShadow,
            )),
        const SizedBox(height: 4),
        Text('Train your ear, one melody at a time.',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
              shadows: inkShadow,
            )),
        const SizedBox(height: 28),
        InkWell(
          onTap: close,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 38, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFC53D),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(color: Color(0xFFE0A420), offset: Offset(0, 5)),
              ],
            ),
            child: const Text("Let's fly  ▶",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A5A00),
                )),
          ),
        ),
      ],
    );
  }
}

class _SunrisePainter extends CustomPainter {
  final double rotation;
  final bool night;
  _SunrisePainter({required this.rotation, this.night = false});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (night) {
      // Moonrise: soft halo, cream disc, a few craters — no rays.
      canvas.drawCircle(
          c,
          190,
          Paint()
            ..color = const Color(0x40F5F0D6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46));
      final core = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.4),
          colors: [Color(0xFFFBF6DE), Color(0xFFE4DAAC)],
        ).createShader(Rect.fromCircle(center: c, radius: 172));
      canvas.drawCircle(c, 172, core);
      final crater = Paint()..color = const Color(0x2E6E6540);
      canvas.drawCircle(c.translate(-52, -84), 20, crater);
      canvas.drawCircle(c.translate(38, -58), 13, crater);
      canvas.drawCircle(c.translate(-6, -120), 9, crater);
      return;
    }
    // Halo glow.
    canvas.drawCircle(
        c,
        190,
        Paint()
          ..color = const Color(0x59FFC53D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46));
    // Soft rays.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    final ray = Paint()..color = const Color(0x66FFD97A);
    for (var i = 0; i < 12; i++) {
      canvas.rotate(math.pi / 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-7, 178, 14, 76), const Radius.circular(8)),
        ray,
      );
    }
    canvas.restore();
    // Core.
    final core = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.4),
        colors: [Color(0xFFFFE9A8), Color(0xFFFFC53D)],
      ).createShader(Rect.fromCircle(center: c, radius: 172));
    canvas.drawCircle(c, 172, core);
  }

  @override
  bool shouldRepaint(_SunrisePainter old) =>
      old.rotation != rotation || old.night != night;
}

/// Static star field for the night splash.
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  static const _stars = [
    (0.07, 0.10, 2.4, 0.9),
    (0.18, 0.22, 1.6, 0.55),
    (0.29, 0.08, 2.0, 0.8),
    (0.41, 0.16, 1.4, 0.5),
    (0.53, 0.06, 2.2, 0.85),
    (0.64, 0.20, 1.5, 0.5),
    (0.77, 0.09, 2.4, 0.9),
    (0.89, 0.17, 1.6, 0.55),
    (0.11, 0.40, 1.5, 0.45),
    (0.33, 0.33, 1.2, 0.4),
    (0.68, 0.36, 1.4, 0.45),
    (0.93, 0.40, 1.8, 0.6),
    (0.05, 0.62, 1.6, 0.5),
    (0.95, 0.60, 1.4, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final (fx, fy, r, o) in _stars) {
      final c = Offset(fx * size.width, fy * size.height);
      final p = Path()
        ..moveTo(c.dx, c.dy - r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r * 2)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r * 2, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r * 2)
        ..close();
      canvas.drawPath(p, Paint()..color = Color.fromRGBO(0xCB, 0xD6, 0xFF, o));
    }
  }

  @override
  bool shouldRepaint(_StarsPainter old) => false;
}

class _PuffPainter extends CustomPainter {
  final bool night;
  _PuffPainter({this.night = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = night ? const Color(0xFF2A3560) : Colors.white;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.33, h * 0.68), width: w * 0.6, height: h * 0.62),
        Paint()..color = base.withValues(alpha: 0.9));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(w * 0.66, h * 0.52), width: w * 0.52, height: h * 0.58),
        Paint()..color = base.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(_PuffPainter old) => old.night != night;
}
