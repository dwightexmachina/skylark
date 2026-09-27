// Renders the lark mascot to the favicon / PWA icon PNGs.
// Run with: flutter test test/gen_icons_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ear_trainer/widgets/lark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(String path, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();

  // Sky background.
  final bg = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFA6D8F5), Color(0xFFE9F7FF)],
    ).createShader(Rect.fromLTWH(0, 0, s, s));
  canvas.drawRect(Rect.fromLTWH(0, 0, s, s), bg);

  // Bird centered with a slight optical lift.
  const dw = 66.0, dh = 50.0;
  final scale = s * 0.78 / dw;
  canvas.translate((s - dw * scale) / 2, (s - dh * scale) / 2 - s * 0.015);
  canvas.scale(scale);
  LarkPainter().paint(canvas, const Size(dw, dh));

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('generate icons', () async {
    await _write('web/icons/Icon-512.png', 512);
    await _write('web/icons/Icon-maskable-512.png', 512);
    await _write('web/icons/Icon-192.png', 192);
    await _write('web/icons/Icon-maskable-192.png', 192);
    await _write('web/favicon.png', 32);
  });
}
