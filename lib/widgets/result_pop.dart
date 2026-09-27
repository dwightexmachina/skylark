import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/palette.dart';
import 'cloud_card.dart';

enum ResultTier { perfect, good, lost }

/// End-of-round pop: a bouncing, hovering cumulus whose weather is the
/// verdict — sunshine for perfect, a rainbow for good, gentle rain for lost.
class ResultPop extends StatefulWidget {
  final ResultTier tier;
  final int pitchCorrect;
  final int onTime;
  final int pitchTotal;
  final int streak;
  final VoidCallback onDismiss;
  final VoidCallback onNext;
  final VoidCallback onReplay;

  const ResultPop({
    super.key,
    required this.tier,
    required this.pitchCorrect,
    required this.onTime,
    required this.pitchTotal,
    required this.streak,
    required this.onDismiss,
    required this.onNext,
    required this.onReplay,
  });

  @override
  State<ResultPop> createState() => _ResultPopState();
}

class _ResultPopState extends State<ResultPop> with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3400))
    ..repeat();
  late final AnimationController _spin = AnimationController(
      vsync: this, duration: const Duration(seconds: 14))
    ..repeat();
  late final AnimationController _ambient = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _bob.dispose();
    _spin.dispose();
    _ambient.dispose();
    super.dispose();
  }

  bool get _reduce => MediaQuery.of(context).disableAnimations;

  double _wave(AnimationController c, double phase) {
    final t = (c.value - phase) % 1.0;
    return 0.5 - 0.5 * math.cos(2 * math.pi * t);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final lost = widget.tier == ResultTier.lost;

    final cloud = Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: CloudCardPainter(
            fill: lost ? const Color(0xFFF7FAFD) : p.surface,
            lobeFill: lost ? const Color(0xFFEDF2F8) : null,
            shadow: p.cardShadow,
          ),
          child: Container(
            width: 360,
            padding: EdgeInsets.fromLTRB(
                28, CloudCardPainter.bandVisible + 10, 28, 20),
            child: _content(p),
          ),
        ),
        if (widget.tier == ResultTier.perfect) ..._sunAndStars(p),
        if (widget.tier == ResultTier.good) _rainbow(),
        if (lost) ..._rain(p),
      ],
    );

    Widget animated = cloud;
    if (!_reduce) {
      // Gentle hover once settled.
      animated = AnimatedBuilder(
        animation: _bob,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, -6 * _wave(_bob, 0)),
          child: child,
        ),
        child: cloud,
      );
      // Bouncy entrance, managed by the framework so it always completes.
      animated = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, e, child) => Opacity(
          opacity: e.clamp(0.0, 1.0),
          child: Transform(
            transform: Matrix4.translationValues(0, 24 * (1 - e), 0)
              ..scaleByDouble(
                  0.55 + 0.45 * e, 0.55 + 0.45 * e, 1, 1),
            alignment: Alignment.center,
            child: child,
          ),
        ),
        child: animated,
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onDismiss,
          child: ColoredBox(
              color: const Color(0xFF1E325A).withValues(alpha: 0.35)),
        ),
      ),
      Center(child: animated),
    ]);
  }

  Widget _content(Palette p) {
    final t = widget.tier;
    final (title, titleColor) = switch (t) {
      ResultTier.perfect => ('Perfect round!', p.keyHeldText),
      ResultTier.good => ('Nice ear!', const Color(0xFF3E7C4F)),
      ResultTier.lost => ('Round lost', p.staffInk),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(64, 28),
          painter: _FacePainter(tier: t),
        ),
        const SizedBox(height: 4),
        Text(title,
            style: TextStyle(
                fontSize: 21, fontWeight: FontWeight.w700, color: titleColor)),
        const SizedBox(height: 2),
        Text(
            '${widget.pitchCorrect}/${widget.pitchTotal} pitches  ·  ${widget.onTime}/${widget.pitchTotal} on time',
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: p.staffInk)),
        if (t == ResultTier.perfect) ...[
          const SizedBox(height: 4),
          Text('⭐ Streak ${widget.streak} — you’re on a roll!',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: p.keyHeldText)),
        ],
        if (t == ResultTier.good) ...[
          const SizedBox(height: 4),
          Text('So close — one more listen and it’s yours.',
              style: TextStyle(fontSize: 12.5, color: p.muted)),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: switch (t) {
            ResultTier.perfect => [
                _btn(p, '▶  Next round', style: _B.primary,
                    onTap: widget.onNext),
              ],
            ResultTier.good => [
                _btn(p, '↻  Replay', style: _B.blue, onTap: widget.onReplay),
                const SizedBox(width: 10),
                _btn(p, '▶  Next round', style: _B.primary,
                    onTap: widget.onNext),
              ],
            ResultTier.lost => [
                _btn(p, '↻  Hear it again', style: _B.primary,
                    onTap: widget.onReplay),
                const SizedBox(width: 10),
                _btn(p, '▶  Next round', style: _B.plain,
                    onTap: widget.onNext),
              ],
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------- weather

  List<Widget> _sunAndStars(Palette p) {
    Widget star(double left, double top, double size, double phase) {
      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final w = _reduce ? 1.0 : _wave(_ambient, phase);
              return Opacity(
                opacity: 0.25 + 0.75 * w,
                child: Transform.scale(
                  scale: 0.7 + 0.45 * w,
                  child: CustomPaint(
                      size: Size(size, size),
                      painter: _StarPainter(color: p.accent)),
                ),
              );
            },
          ),
        ),
      );
    }

    return [
      Positioned(
        top: -62,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: AnimatedBuilder(
              animation: _spin,
              builder: (context, _) => CustomPaint(
                size: const Size(110, 110),
                painter: _SunPainter(
                    rotation: _reduce ? 0 : _spin.value * 2 * math.pi),
              ),
            ),
          ),
        ),
      ),
      star(-26, 34, 20, 0),
      star(356, 60, 15, 0.28),
      star(28, -22, 14, 0.55),
      star(316, -28, 18, 0.8),
    ];
  }

  Widget _rainbow() {
    return Positioned(
      top: -44,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: CustomPaint(
              size: const Size(190, 86), painter: _RainbowPainter()),
        ),
      ),
    );
  }

  List<Widget> _rain(Palette p) {
    Widget drop(double left, double top, double phase) {
      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final t = _reduce ? 0.4 : (_ambient.value - phase) % 1.0;
              return Opacity(
                opacity: t < 0.15 ? t / 0.15 : (1 - t).clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 46 * t),
                  child: Container(
                    width: 7,
                    height: 11,
                    decoration: BoxDecoration(
                      color: p.tonicSoft,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return [
      drop(-20, 130, 0),
      drop(-36, 118, 0.42),
      drop(374, 126, 0.2),
      drop(392, 114, 0.66),
      drop(178, 158, 0.5),
    ];
  }

  Widget _btn(Palette p, String label,
      {required _B style, required VoidCallback onTap}) {
    final (bg, fg, shadow) = switch (style) {
      _B.primary => (p.accent, p.onAccent, p.accentShadow),
      _B.blue => (p.tonicSoft, p.tonic, p.blueShadow),
      _B.plain => (p.surface, p.muted, p.btnShadow),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 3))],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
      ),
    );
  }
}

enum _B { primary, blue, plain }

/// Two dot eyes and a mouth; cheeks when delighted, a tear when not.
class _FacePainter extends CustomPainter {
  final ResultTier tier;
  _FacePainter({required this.tier});

  @override
  void paint(Canvas canvas, Size size) {
    final ink = tier == ResultTier.lost
        ? const Color(0xFF5B6A92)
        : const Color(0xFF33406B);
    final eye = Paint()..color = ink;
    canvas.drawCircle(Offset(size.width / 2 - 16, 8), 3.2, eye);
    canvas.drawCircle(Offset(size.width / 2 + 16, 8), 3.2, eye);

    final mouth = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final path = Path();
    switch (tier) {
      case ResultTier.perfect:
        path.moveTo(cx - 10, 14);
        path.quadraticBezierTo(cx, 23, cx + 10, 14);
        // rosy cheeks
        final cheek = Paint()..color = const Color(0xCCFFD3DE);
        canvas.drawCircle(Offset(cx - 25, 16), 4.5, cheek);
        canvas.drawCircle(Offset(cx + 25, 16), 4.5, cheek);
      case ResultTier.good:
        path.moveTo(cx - 8, 15);
        path.quadraticBezierTo(cx, 21, cx + 8, 15);
      case ResultTier.lost:
        path.moveTo(cx - 8, 21);
        path.quadraticBezierTo(cx, 15, cx + 8, 21);
        // a single tear
        final tear = Paint()
          ..color = const Color(0xFF7FC8F5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final tp = Path()
          ..moveTo(cx + 18, 12)
          ..quadraticBezierTo(cx + 21, 17, cx + 18, 21);
        canvas.drawPath(tp, tear);
    }
    canvas.drawPath(path, mouth);
  }

  @override
  bool shouldRepaint(_FacePainter old) => old.tier != tier;
}

class _SunPainter extends CustomPainter {
  final double rotation;
  _SunPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // glow
    canvas.drawCircle(
        c,
        34,
        Paint()
          ..color = const Color(0x66FFC53D)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    // rays
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(rotation);
    final ray = Paint()..color = const Color(0xFFFFC53D);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(-2.5, 32, 5, 18), const Radius.circular(3)),
        ray,
      );
    }
    canvas.restore();
    // core
    final core = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.4),
        colors: [Color(0xFFFFE9A8), Color(0xFFFFC53D)],
      ).createShader(Rect.fromCircle(center: c, radius: 29));
    canvas.drawCircle(c, 29, core);
  }

  @override
  bool shouldRepaint(_SunPainter old) => old.rotation != rotation;
}

class _RainbowPainter extends CustomPainter {
  static const _colors = [
    Color(0xFFFF8787),
    Color(0xFFFFC53D),
    Color(0xFF58C08A),
    Color(0xFF7FC8F5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _colors.length; i++) {
      final rect = Rect.fromCircle(
          center: Offset(size.width / 2, size.height),
          radius: 80.0 - i * 11);
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = _colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RainbowPainter old) => false;
}

/// A four-point sparkle.
class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 2;
    final c = size.center(Offset.zero);
    final pinch = s * 0.18;
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx + pinch, c.dy - pinch, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx + pinch, c.dy + pinch, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx - pinch, c.dy + pinch, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx - pinch, c.dy - pinch, c.dx, c.dy - s)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}
