import 'package:flutter/material.dart';

/// The drawn-cumulus silhouette: a rounded body that wraps the content, with
/// a band of plump lobes riding its top edge. Painted as one union, so the
/// text can never escape the cloud — the body is sized BY the content.
class CloudCardPainter extends CustomPainter {
  static const double bandVisible = 40; // lobe height above the body
  static const double _designW = 400;
  static const double _designH = 84;
  static const double _overlap = 22; // lobes reach into the body: no seams

  final Color fill;
  final Color shadow;
  final Color? lobeFill; // defaults to [fill]

  CloudCardPainter({required this.fill, required this.shadow, this.lobeFill});

  Path _lobeBand(Size size) {
    // Lobe band in its 400×84 design space, an arc chain with manually
    // tracked positions.
    final lobes = Path()..moveTo(6, 84);
    var x = 6.0, y = 84.0;
    void a(double r, double dx, double dy) {
      x += dx;
      y += dy;
      lobes.arcToPoint(Offset(x, y),
          radius: Radius.circular(r), clockwise: true);
    }

    a(20, 30, -16);
    a(30, 52, -22);
    a(40, 76, -6);
    a(44, 82, 2);
    a(34, 58, 16);
    a(30, 52, 12);
    a(22, 38, 14);
    lobes.close();

    final sx = size.width / _designW;
    final sy = (bandVisible + _overlap) / _designH;
    return lobes
        .transform((Matrix4.identity()..scaleByDouble(sx, sy, 1, 1)).storage);
  }

  Path _bodyPath(Size size) => Path()
    ..addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, bandVisible, size.width,
          (size.height - bandVisible).clamp(0, double.infinity)),
      const Radius.circular(30),
    ));

  @override
  void paint(Canvas canvas, Size size) {
    final band = _lobeBand(size);
    final body = _bodyPath(size);
    final union = Path.combine(PathOperation.union, body, band);
    canvas.drawPath(union.shift(const Offset(0, 9)), Paint()..color = shadow);
    if (lobeFill != null && lobeFill != fill) {
      canvas.drawPath(band, Paint()..color = lobeFill!);
      canvas.drawPath(body, Paint()..color = fill);
    } else {
      canvas.drawPath(union, Paint()..color = fill);
    }
  }

  @override
  bool shouldRepaint(CloudCardPainter old) =>
      old.fill != fill || old.shadow != shadow || old.lobeFill != lobeFill;
}
