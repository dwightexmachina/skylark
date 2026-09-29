import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/round.dart';
import '../ui/palette.dart';

/// Treble staff for 1–4 measures of 4/4. Draws only revealed events, each in
/// its verdict color, plus a dashed playhead while the clock is running.
class StaffView extends StatelessWidget {
  final List<JudgedEvent> judged;
  final int measures;
  final double? playheadBeat;
  final double secondsPerBeat;

  /// Free play: render pending notes in ink (no verdict semantics).
  final bool neutralInk;

  /// Perfect Pitch: draw wrong answers as a dyad — the guess in red plus
  /// the correct note in amber — instead of the lone target notehead.
  final bool wrongDyad;

  const StaffView({
    super.key,
    required this.judged,
    required this.measures,
    required this.playheadBeat,
    required this.secondsPerBeat,
    this.neutralInk = false,
    this.wrongDyad = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final minW = 300.0 * measures + 90;
      final w = constraints.maxWidth.isFinite && constraints.maxWidth > minW
          ? constraints.maxWidth
          : minW;
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: w,
            height: 150,
            child: CustomPaint(
              painter: _StaffPainter(
                judged: judged,
                measures: measures,
                playheadBeat: playheadBeat,
                secondsPerBeat: secondsPerBeat,
                palette: palette,
                neutralInk: neutralInk,
                wrongDyad: wrongDyad,
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _StaffPainter extends CustomPainter {
  final List<JudgedEvent> judged;
  final int measures;
  final double? playheadBeat;
  final double secondsPerBeat;
  final Palette palette;
  final bool neutralInk;
  final bool wrongDyad;

  _StaffPainter({
    required this.judged,
    required this.measures,
    required this.playheadBeat,
    required this.secondsPerBeat,
    required this.palette,
    required this.neutralInk,
    required this.wrongDyad,
  });

  static const double g = 9; // gap between staff lines
  static const double y0 = 40; // top staff line
  static const double xLeft = 78; // after clef + time signature
  static const double pad = 18; // inset inside each measure

  late double _measureW;

  double _letterY(int letter) => y0 + 4 * g - (letter - 2) * g / 2;

  double _beatToX(double beat) {
    var m = beat ~/ 4;
    if (m >= measures) m = measures - 1;
    final frac = (beat - m * 4) / 4;
    return xLeft + m * _measureW + pad + frac * (_measureW - 2 * pad);
  }

  void _text(Canvas canvas, String s, Offset topLeft, double fontSize,
      Color color,
      {FontWeight weight = FontWeight.normal}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: fontSize, color: color, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, topLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _measureW = (size.width - xLeft - 10) / measures;
    final staffPaint = Paint()
      ..color = palette.staff
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = y0 + i * g;
      canvas.drawLine(Offset(12, y), Offset(size.width - 6, y), staffPaint);
    }
    final barPaint = Paint()
      ..color = palette.staff
      ..strokeWidth = 2.2;
    for (var m = 0; m <= measures; m++) {
      final x = m == 0 ? 12.0 : xLeft + m * _measureW;
      canvas.drawLine(Offset(x, y0), Offset(x, y0 + 4 * g), barPaint);
    }
    // Final thick barline.
    canvas.drawLine(Offset(size.width - 6, y0), Offset(size.width - 6, y0 + 4 * g),
        Paint()..color = palette.staffInk.withValues(alpha: 0.55)..strokeWidth = 4);

    // Stylized treble clef (drawn, since music glyphs aren't in web fonts).
    _drawClef(canvas);
    _text(canvas, '4', Offset(56, y0 - 4), 22, palette.staffInk,
        weight: FontWeight.w700);
    _text(canvas, '4', Offset(56, y0 + 2 * g - 4), 22, palette.staffInk,
        weight: FontWeight.w700);

    for (var i = 0; i < judged.length; i++) {
      final j = judged[i];
      if (!j.revealed) continue;
      if (j.isRest) {
        _drawRest(canvas, j.event);
      } else {
        final beamed = j.event.beamWithNext &&
            i + 1 < judged.length &&
            judged[i + 1].revealed;
        _drawNote(canvas, j, beamedWith: beamed ? judged[i + 1] : null);
      }
    }

    if (playheadBeat != null &&
        playheadBeat! >= 0 &&
        playheadBeat! <= measures * 4) {
      final x = _beatToX(playheadBeat!.clamp(0, measures * 4 - 0.001));
      final paint = Paint()
        ..color = palette.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      // Dashed vertical line.
      var y = y0 - 2.0;
      while (y < y0 + 4 * g + 10) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 5), paint);
        y += 11;
      }
      // A little sun as the playhead cap.
      final sun = Paint()..color = palette.accent;
      canvas.drawCircle(Offset(x, y0 - 14), 6.5, sun);
      final ray = Paint()
        ..color = palette.accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y0 - 26), Offset(x, y0 - 23), ray);
      canvas.drawLine(Offset(x - 11, y0 - 14), Offset(x - 8, y0 - 14), ray);
      canvas.drawLine(Offset(x + 8, y0 - 14), Offset(x + 11, y0 - 14), ray);
      canvas.drawLine(
          Offset(x - 8, y0 - 22), Offset(x - 6, y0 - 20), ray);
      canvas.drawLine(Offset(x + 6, y0 - 20), Offset(x + 8, y0 - 22), ray);
    }
  }

  Color _verdictColor(Verdict v) => switch (v) {
        Verdict.good => palette.good,
        Verdict.offTime => palette.warn,
        Verdict.wrongPitch || Verdict.missed => palette.bad,
        Verdict.pending => neutralInk ? palette.ink : palette.muted,
      };

  void _drawClef(Canvas canvas) {
    const cx = 32.0;
    final paint = Paint()
      ..color = palette.staffInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final p = Path()
      // Tall S-curve from above the staff down through it…
      ..moveTo(cx + 3, y0 - 16)
      ..cubicTo(cx + 11, y0 - 8, cx + 9, y0 + 4, cx + 1, y0 + 12)
      ..cubicTo(cx - 8, y0 + 20, cx - 9, y0 + 30, cx, y0 + 34)
      // …ending in a spiral around the G line.
      ..cubicTo(cx + 9, y0 + 38, cx + 14, y0 + 31, cx + 11, y0 + 25)
      ..cubicTo(cx + 8, y0 + 19, cx + 1, y0 + 21, cx + 1, y0 + 27);
    canvas.drawPath(p, paint);
    // Stem down to the tail dot below the staff.
    canvas.drawLine(Offset(cx + 3, y0 - 16), Offset(cx + 3, y0 + 4 * g + 6),
        Paint()..color = palette.staffInk..strokeWidth = 2.2);
    canvas.drawCircle(Offset(cx + 1, y0 + 4 * g + 7), 2.6,
        Paint()..color = palette.staffInk);
  }

  void _drawRest(Canvas canvas, NoteEvent e) {
    // Quarter rest as a drawn zigzag with a bottom hook.
    final x = _beatToX(e.startBeat);
    final paint = Paint()
      ..color = palette.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path()
      ..moveTo(x - 3, y0 + 4)
      ..lineTo(x + 4, y0 + 12)
      ..lineTo(x - 3, y0 + 19)
      ..lineTo(x + 4, y0 + 27)
      ..cubicTo(x - 4, y0 + 24, x - 4, y0 + 32, x + 2, y0 + 34);
    canvas.drawPath(p, paint);
  }

  void _drawHead(Canvas canvas, double x, double y, Color color,
      {bool hollow = false}) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.32);
    final headPaint = Paint()
      ..color = color
      ..style = hollow ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 2;
    canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 14, height: 10), headPaint);
    canvas.restore();
  }

  void _drawLedger(Canvas canvas, double x, double y) {
    canvas.drawLine(Offset(x - 11, y), Offset(x + 11, y),
        Paint()..color = palette.staff..strokeWidth = 2);
  }

  /// Wrong Perfect Pitch answer: the guess (red) and the correct note
  /// (amber) share one beat and one stem.
  void _drawWrongDyad(Canvas canvas, JudgedEvent j) {
    final played = j.played!;
    final target = j.event.pitch!;
    final x = _beatToX(j.event.startBeat);
    final yPlayed = _letterY(played.letter);
    final yTarget = _letterY(target.letter);

    // A unison or second can't stack in one column: the higher head moves
    // to the stem's right side, notation-style.
    final adjacent = (played.letter - target.letter).abs() <= 1;
    final playedIsHigher = played.semitone > target.semitone;
    double xOf(bool isPlayed) =>
        adjacent && (isPlayed == playedIsHigher) ? x + 12.4 : x;

    for (final (pitch, isPlayed) in [(target, false), (played, true)]) {
      if (pitch.letter == 0) {
        _drawLedger(canvas, xOf(isPlayed), _letterY(0));
      }
    }

    // One shared stem from the lower head up past the higher one.
    final yLow = yPlayed > yTarget ? yPlayed : yTarget;
    final yHigh = yPlayed > yTarget ? yTarget : yPlayed;
    canvas.drawLine(Offset(x + 6.2, yLow - 2), Offset(x + 6.2, yHigh - 3.4 * g),
        Paint()..color = palette.warn..strokeWidth = 1.8);

    _drawHead(canvas, xOf(false), yTarget, palette.warn);
    _drawHead(canvas, xOf(true), yPlayed, palette.bad);

    // Accidentals stack to the left of the whole dyad.
    var sharpX = x - 22.0;
    for (final (pitch, y, color) in [
      (target, yTarget, palette.warn),
      (played, yPlayed, palette.bad),
    ]) {
      if (pitch.isSharp) {
        _text(canvas, '♯', Offset(sharpX, y - 11), 17, color);
        sharpX -= 14;
      }
    }
  }

  void _drawNote(Canvas canvas, JudgedEvent j, {JudgedEvent? beamedWith}) {
    if (wrongDyad && j.verdict == Verdict.wrongPitch && j.played != null) {
      _drawWrongDyad(canvas, j);
      return;
    }

    final e = j.event;
    final pitch = e.pitch!;
    final color = _verdictColor(j.verdict);
    final x = _beatToX(e.startBeat);
    final y = _letterY(pitch.letter);
    final hollow = e.durationBeats >= 2 || j.verdict == Verdict.missed;

    // Ledger line for C4.
    if (pitch.letter == 0) {
      _drawLedger(canvas, x, y);
    }

    _drawHead(canvas, x, y, color, hollow: hollow);

    if (pitch.isSharp) {
      _text(canvas, '♯', Offset(x - 22, y - 11), 17, color);
    }

    // Stem (up) and beam.
    final stemX = x + 6.2;
    final stemTop = y - 3.4 * g;
    canvas.drawLine(Offset(stemX, y - 2), Offset(stemX, stemTop),
        Paint()..color = color..strokeWidth = 1.8);

    if (beamedWith != null) {
      final e2 = beamedWith.event;
      final x2 = _beatToX(e2.startBeat) + 6.2;
      final top2 = _letterY(e2.pitch!.letter) - 3.4 * g;
      final beam = Path()
        ..moveTo(stemX, stemTop)
        ..lineTo(x2, top2)
        ..lineTo(x2, top2 + 4)
        ..lineTo(stemX, stemTop + 4)
        ..close();
      canvas.drawPath(beam, Paint()..color = color);
      // The pair shares one beam; also draw the partner's stem now so the
      // beam meets it even if the partner is painted later.
      canvas.drawLine(
          Offset(x2, _letterY(e2.pitch!.letter) - 2), Offset(x2, top2),
          Paint()..color = _verdictColor(beamedWith.verdict)..strokeWidth = 1.8);
    }

    // Annotation under the note.
    String? note;
    switch (j.verdict) {
      case Verdict.offTime:
        final secs = (j.deltaBeats ?? 0) * secondsPerBeat;
        note = secs >= 0
            ? 'late +${secs.toStringAsFixed(2)}s'
            : 'early −${secs.abs().toStringAsFixed(2)}s';
      case Verdict.wrongPitch:
        note = 'you: ${j.played?.label ?? '?'}';
      case Verdict.missed:
        note = 'missed';
      default:
        break;
    }
    if (note != null) {
      // Stagger annotations of off-beat (eighth) events one row lower so
      // adjacent labels don't overlap.
      final offBeat = (e.startBeat * 2).round().isOdd;
      final yNote = y0 + 5.4 * g + (offBeat ? 13 : 0);
      _text(canvas, note, Offset(x - 20, yNote), 10.5, color);
    }
  }

  @override
  bool shouldRepaint(_StaffPainter old) => true;
}
