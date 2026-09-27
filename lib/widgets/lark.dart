import 'package:flutter/material.dart';

/// The lark mascot: crest, sky-blue wing, golden beak, soft-navy outline.
/// Drawn in a 66×50 design space and scaled to fit.
class LarkPainter extends CustomPainter {
  static const _outline = Color(0xFF4B5B8C);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 66, size.height / 50);

    final stroke = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // Tail feathers.
    canvas.drawLine(const Offset(4, 30), const Offset(1, 26),
        stroke..strokeWidth = 2.6);
    canvas.drawLine(const Offset(4, 30), const Offset(0, 31), stroke);

    // Beak (under the body edge).
    final beak = Path()
      ..moveTo(52, 24)
      ..lineTo(63, 27)
      ..lineTo(52, 31)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFFFC53D));
    canvas.drawPath(
        beak,
        Paint()
          ..color = const Color(0xFFE0A420)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round);

    // Body + head silhouette.
    final body = Path()
      ..moveTo(4, 30)
      ..cubicTo(8, 40, 20, 46, 34, 44)
      ..cubicTo(46, 42, 52, 34, 52, 26)
      ..cubicTo(52, 14, 42, 9, 34, 13)
      ..cubicTo(26, 10, 20, 15, 19, 22)
      ..cubicTo(13, 24, 7, 26, 4, 30)
      ..close();
    canvas.drawPath(body, Paint()..color = const Color(0xFFFFFDF4));
    canvas.drawPath(body, stroke..strokeWidth = 3);

    // Crest.
    final crest = Path()
      ..moveTo(30, 12)
      ..relativeLineTo(3, -8)
      ..relativeLineTo(3, 6)
      ..relativeLineTo(4, -6)
      ..relativeLineTo(2, 8);
    canvas.drawPath(crest, Paint()..color = const Color(0xFFFFFDF4));
    canvas.drawPath(crest, stroke..strokeWidth = 2.6);

    // Wing.
    final wing = Path()
      ..moveTo(21, 27)
      ..quadraticBezierTo(32, 20, 40, 28)
      ..quadraticBezierTo(35, 39, 24, 35)
      ..quadraticBezierTo(19, 32, 21, 27)
      ..close();
    canvas.drawPath(wing, Paint()..color = const Color(0xFF7FC8F5));
    canvas.drawPath(wing, stroke..strokeWidth = 2.6);

    // Eye.
    canvas.drawCircle(
        const Offset(44, 21), 2.6, Paint()..color = const Color(0xFF33406B));

    canvas.restore();
  }

  @override
  bool shouldRepaint(LarkPainter old) => false;
}
